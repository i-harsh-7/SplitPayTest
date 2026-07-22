# Security & Reliability Fixes — Change Log

This document summarizes all changes made during the security/reliability review of the SplitPay
backend, in the order they were addressed. Each section lists the problem reported and what was
changed to fix it.

---

## 1. Broken access control (IDOR) on bills/expenses and invites

**Problem:** Several `BillService` endpoints performed no group-membership check, letting any
authenticated user read or mutate another group's financial data by guessing/enumerating a Mongo
id. `InviteService.sendInvite` let anyone invite users into any group.

**Fixes:**
- `BillService.getBillDetails` — now requires the requester to be a member of the expense's group.
- `BillService.splitExpense` — same membership check added.
- `BillService.assignMoney` / `assignEqually` — now verify the *requester* is a group member (not
  just the `from`/`to`/payer ids referenced in the request body).
- `BillService.getAllBills` / `settlements` (backing `getAssignments`) — now verify membership of
  the `group` query param.
- `InviteService.sendInvite` — now verifies the sender is a member of the group they're inviting
  into.
- Added a shared `requireGroupMember(groupId, requesterId)` helper in `BillService`.

Files: `BillService.java`, `InviteService.java`, `BillController.java`.

---

## 2. Leaked secrets and API key transport

**Problem:** `.env` contained a live-looking MongoDB Atlas URI (weak `0000` password) and a Gemini
API key. `BillParserService` sent the Gemini key as a URL query parameter (`?key=...`), risking
exposure in access logs, proxies, and error messages.

**Fixes:**
- Confirmed `.env` was never committed to git (`git log --all -- .env` is empty) and is gitignored;
  advised rotating both credentials since the file had been read this session.
- `BillParserService.parseBillImage` / `parseBillText` — Gemini API key now sent via the
  `x-goog-api-key` header instead of the `?key=` query string.

Files: `BillParserService.java`.

---

## 3. JWT session handling (no revocation, no logout)

**Problem:** JWTs were pure 10h bearer tokens with no revocation — a stolen token, or a token
issued before a password change, stayed valid for its full lifetime. No logout endpoint existed.

**Fixes:**
- `User.tokenVersion` (int, default 0) added.
- `JwtService.generateToken(userId, tokenVersion)` now embeds a `tv` claim; `parseToken` returns
  both `userId` and `tokenVersion` as a `TokenClaims` record. Tokens minted before this change (no
  `tv` claim) default to version 0, so no forced logout on deploy.
- `JwtAuthFilter` now looks up the user on every authenticated request and rejects the token if its
  `tv` doesn't match the user's current stored value.
- `AuthService.changePassword` bumps `tokenVersion`, instantly invalidating any stolen bearer token.
- New `AuthService.logout(userId)` also bumps `tokenVersion` — since there's no per-token session
  store, this signs out *all* devices, not just the caller's (documented tradeoff).
- New endpoint: `POST /api/v1/logout`.

Files: `User.java`, `JwtService.java`, `JwtAuthFilter.java`, `SecurityConfig.java`,
`AuthService.java`, `AuthController.java`.

---

## 4. Rate limiting gaps

**Problem:** `RateLimitFilter` trusted `X-Forwarded-For` unconditionally (trivially spoofable —
rotating the header bypasses rate limiting entirely). Its in-memory buckets were never pruned
(slow unbounded memory growth). No per-account lockout on repeated failed logins — only the shared
10/min IP bucket for login+signup combined.

**Fixes:**
- Added `splitpay.security.trust-proxy` (env `TRUST_PROXY`, default `false`). `X-Forwarded-For` is
  now ignored unless explicitly enabled for a trusted, header-overwriting proxy; falls back to
  `request.getRemoteAddr()`.
- `RateLimitFilter` now runs a daemon `ScheduledExecutorService` that sweeps stale bucket entries
  every window (60s), bounding memory to *active* IPs instead of all-time IPs.
- `User.failedLoginAttempts` / `lockedUntil` added. `AuthService.login` locks the account for 15
  minutes after 5 consecutive failed attempts (`429`), independent of the shared IP bucket; resets
  on success.

Files: `RateLimitFilter.java`, `SplitPayProperties.java`, `application.yml`, `User.java`,
`AuthService.java`, `ApiException.java` (added `tooManyRequests` factory).

---

## 5. No declarative input validation

**Problem:** `spring-boot-starter-validation` was a declared dependency but never used —
validation was ad-hoc `if (isBlank(...))` checks scattered per-service, and some DTOs (e.g.
`GroupDtos.CreateGroupRequest`) had none at all. No password strength policy (1-character
passwords accepted). No email format validation anywhere.

**Fixes:**
- Added Jakarta Bean Validation annotations (`@NotBlank`, `@NotNull`, `@NotEmpty`, `@Email`,
  `@Positive`, `@PositiveOrZero`, `@Pattern`) across `AuthDtos`, `BillDtos`, `GroupDtos`,
  `InviteDtos`. Nested lists (`items`, `payments`, `assignments`) use `@Valid` to cascade
  validation into each element.
- `@Valid` added to every `@RequestBody` parameter across `AuthController`, `GroupController`,
  `BillController`, `InviteController`.
- Password strength: `SignUpRequest.password` and `ChangePasswordRequest.newPassword` require at
  least 8 characters with one letter and one digit (`^(?=.*[A-Za-z])(?=.*\d).{8,}$`).
- Email format: `@Email` added to `SignUpRequest.email`, `LoginRequest.email`,
  `InviteDtos.SendInviteRequest.friendMail`.
- `CreateGroupRequest.name` is now `@NotBlank` — fixes the "empty-name group" gap directly.
- Removed now-redundant ad-hoc presence checks in `AuthService` and `BillService` that duplicated
  what the DTO annotations now guarantee (kept every check that does more than presence-checking:
  membership, cross-field, business-rule checks).

Files: `AuthDtos.java`, `BillDtos.java`, `GroupDtos.java`, `InviteDtos.java`, all controllers,
`AuthService.java`, `BillService.java`.

---

## 6. Money stored as `double`

**Problem:** `Expense`/`User` monetary fields were `double`/`Double` throughout.
`BillService.assignEqually` had a hand-rolled `round2()` residual-correction hack to patch
floating-point drift in equal splits — a symptom of the wrong data type for money.

**Fixes:**
- `Expense.totalAmount`, `Item.price`, `Payment.amount`, `Assignment.amount`,
  `SplitSummary.amountOwed`, and `User.youOwe` / `youAreOwed` all converted to `BigDecimal`.
- Corresponding `BillDtos` fields switched from `Double` to `BigDecimal`.
- `BillParserService` parses Gemini's numeric fields into exact 2-decimal-place `BigDecimal`s.
- `BillService` arithmetic rewritten with `BigDecimal`/`RoundingMode.HALF_UP`, `.compareTo()`,
  `.max()`. The `round2()` hack is gone — division to scale 2 with `HALF_UP` is exact by
  construction. The residual-cent distribution onto the last debtor in `assignEqually` is kept
  (splitting money can't avoid a leftover penny when it doesn't divide evenly) but is now a
  deliberate, exact calculation rather than a correction for representation error.
- New `JacksonConfig` enables `WRITE_BIGDECIMAL_AS_PLAIN` so responses never emit scientific
  notation. MongoDB stores `BigDecimal` as `Decimal128` natively — no custom codec needed.

Files: `Expense.java`, `User.java`, `BillDtos.java`, `BillParserService.java`, `BillService.java`,
`BillController.java`, new `JacksonConfig.java`.

---

## 7. Inconsistent group membership model

**Problem:** `GroupService.createGroup` never added the creator to `members`.
`GroupService.getGroup` treated "creator OR member" as authorized, but `BillService` /
`InviteService` only checked `members.contains(userId)` — so a creator who didn't explicitly add
themselves could be locked out of creating expenses or invites in their own group.

**Fix:**
- `GroupService.createGroup` now always adds the creator to `members` (deduped via
  `LinkedHashSet`, preserving caller-supplied ordering). "Members list is the single source of
  truth" is now consistently true for every group created going forward.
- **Caveat:** groups created *before* this fix, where the creator never added themselves, still
  have the old inconsistent state in the database — this is a code fix, not a data migration.

Files: `GroupService.java`.

---

## 8. No audit trail for financial mutations

**Problem:** No record of who changed an assignment, recorded a payment, or deleted a bill — no
way to resolve a "who did this" dispute.

**Fixes:**
- New append-only `AuditLog` model / `AuditLogRepository` / `AuditLogService` (best-effort logging
  — a failure never blocks the financial operation it's recording, same pattern as
  `NotificationService`).
- `BillService` now records every financial mutation: `UPLOAD_BILL`, `CREATE_MANUAL_EXPENSE`,
  `DELETE_BILL`, `ASSIGN_MONEY`, `ASSIGN_EQUALLY`, `SETTLE_ASSIGNMENTS`, `RECORD_PAYMENT`,
  `MARK_ASSIGNMENT_PAID`.
- New endpoint `GET /api/v1/bills/{expenseId}/audit` (group-membership gated) to actually read the
  trail.

Files: new `AuditLog.java`, `AuditLogRepository.java`, `AuditLogService.java`; `BillService.java`,
`BillController.java`.

---

## 9. Unreachable receipt images

**Problem:** `FileStorageService` stored uploaded receipt images and returned a `billImageUrl` like
`uploads/169....jpg`, but there was no static resource mapping or download endpoint serving that
path — clients could never actually load the image back.

**Fix:**
- `FileStorageService` gained `loadAsResource()` (re-resolves the stored filename against
  `uploadDir` with the same path-traversal guard used on write) and `contentTypeFor()`.
- New `GET /api/v1/bills/{expenseId}/image`, gated by the same group-membership check as
  `getBillDetails`. Deliberately **not** a public static resource mapping — that would let any
  client fetch any receipt by guessing a filename.

Files: `FileStorageService.java`, `BillController.java`.

---

## 10. Unmetered Gemini cost on `/bills/upload`

**Problem:** No per-user/per-endpoint cost throttling beyond the generic 120/min IP limit — each
call hits paid Gemini Vision, an open cost-abuse vector.

**Fix:**
- New `UploadRateLimiter` (per-user, not per-IP — an attacker can rotate IPs but not accounts
  without defeating auth), capping uploads to `splitpay.uploads.rate-limit-per-hour` (env
  `UPLOAD_RATE_LIMIT_PER_HOUR`, default 20/hour). Checked in `BillService.uploadBill` before the
  file is stored or Gemini is called, so a throttled request costs nothing.

Files: new `UploadRateLimiter.java`; `BillService.java`, `SplitPayProperties.java`,
`application.yml`.

---

## 11. Misc correctness/cleanup

- `GroupService.getAllGroups` no longer throws a 400 when a user belongs to zero groups — an empty
  list is a valid state, not an error.
- Removed dead `email` fields from `AuthDtos.UpdateProfileRequest` and
  `AuthDtos.ChangePasswordRequest` — `AuthService` never read them (both operate on
  `CurrentUser.id()`, not client-supplied email).

Files: `GroupService.java`, `AuthDtos.java`.

---

## 12. Zero automated tests

**Problem:** No `*Test.java` files existed in the repo — for code with this many authz edge cases,
that's how the IDOR bugs above went unnoticed.

**Fix:** Added 24 unit tests across 6 files (Mockito-based, no DB/Spring context, run in ~1.5s),
specifically pinning down the fixes made in this review:

- `BillServiceAuthorizationTest` (9 tests) — every membership-check IDOR fix in `BillService`
  (`getBillDetails`, `splitExpense`, `getAllBills`, `settlements`, `assignMoney`, `assignEqually`,
  `deleteBill`).
- `InviteServiceTest` (2 tests) — `sendInvite` sender-membership check.
- `GroupServiceTest` (3 tests) — `createGroup` always includes the creator; `getAllGroups` returns
  an empty list instead of throwing.
- `AuthServiceTest` (5 tests) — account lockout after 5 failed logins, lockout blocks even a
  correct password, failed-attempt counter resets on success, `changePassword`/`logout` bump
  `tokenVersion`.
- `JwtServiceTest` (2 tests) — token round-trips `userId`/`tokenVersion`; tampered signature is
  rejected.
- `JwtAuthFilterTest` (3 tests) — stale `tokenVersion` is rejected, current `tokenVersion` is
  accepted, a token for a deleted user is rejected.

Files: new `src/test/java/com/splitpay/service/*Test.java`,
`src/test/java/com/splitpay/security/*Test.java`.

---

## 13. Dockerfile hardening

**Problem:** Single-stage build on the full `eclipse-temurin:21-jdk` image, `COPY . .` (pulls in
`.git`, `target/`, `.env`, everything), no multi-stage build, no `USER` directive — container ran
as root with the whole Maven toolchain baked in.

**Fixes:**
- Multi-stage build: `eclipse-temurin:21-jdk` build stage (Maven toolchain never ships in the
  final image) → `eclipse-temurin:21-jre` runtime stage (slim; Debian-based, not Alpine, so
  tess4j's native/leptonica libs still link against the glibc they expect).
- Explicit `COPY` list in the build stage (`mvnw`, `pom.xml`, `.mvn`, `src`) instead of `COPY . .`.
- Non-root: dedicated `splitpay` system user/group; ownership fixed via `chown -R` before
  `USER splitpay`.
- `HEALTHCHECK` added, hitting `/actuator/health` (curl installed alongside `tesseract-ocr` in the
  runtime image).
- `.dockerignore` tightened: excludes `.env`/`.env.*`, `uploads/`, logs, `.DS_Store`, `README.md`,
  `.github` — defense in depth even though the new Dockerfile no longer does a blanket copy.

Files: `Dockerfile`, `.dockerignore`.

---

## 14. Structured health/readiness endpoint

**Problem:** No `/actuator/health` or structured readiness/liveness endpoint — just
`HomeController` returning `"hello jii"`.

**Fixes:**
- Added `spring-boot-starter-actuator`, exposing only `/actuator/health` over HTTP (env/beans/etc.
  stay unmapped). Enabled `/actuator/health/liveness` and `/actuator/health/readiness` probe
  groups for container orchestrators.
- `JwtAuthFilter` gained a `PUBLIC_PATH_PATTERNS` set (Ant-style), covering
  `/actuator/health/**`, reused by `SecurityConfig` as the single source of truth so the filter
  and the security-chain rule can't drift apart.
- `HomeController`'s `/` left as-is (harmless PaaS default ping) — `/actuator/health` is the new
  structured signal.

Files: `pom.xml`, `application.yml`, `JwtAuthFilter.java`, `SecurityConfig.java`.

---

## 15. No OpenAPI/Swagger spec

**Problem:** No OpenAPI/Swagger spec for API consumers/versioning discipline.

**Fixes:**
- Added `springdoc-openapi-starter-webmvc-ui`, serving the spec at `/v3/api-docs` and Swagger UI at
  `/swagger-ui.html`.
- New `OpenApiConfig` registers a `bearerAuth` JWT security scheme so "Authorize" in Swagger UI
  works against protected endpoints.
- Both paths added to the same public-path allowlist as actuator health.

Files: `pom.xml`, new `OpenApiConfig.java`.

---

## Known follow-ups (not done / needs a decision)

- **Rotate the credentials in `.env`** (MongoDB Atlas password, Gemini API key) — not something
  I can do from here; requires your Atlas/Google Cloud consoles.
- **Backfill existing groups** whose creator isn't in `members` (pre-dates fix #7) — a data
  migration, not attempted without explicit sign-off.
- **Live Docker/boot smoke test** wasn't possible in this environment (no Docker daemon, no
  reachable MongoDB from here) — recommend a real `docker build && docker run` against a reachable
  Mongo before deploying.
