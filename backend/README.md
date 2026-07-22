# SplitPay Backend

Spring Boot API for SplitPay — a group bill-splitting app. Users form groups, upload receipt
photos (parsed into line items by Gemini Vision), split the total by amount or equally, and track
who owes/paid whom. This is the backend for the existing Flutter client.

## Tech stack

| Concern         | Library                                              |
|------------------|------------------------------------------------------|
| Runtime          | Java 21 / Spring Boot 3.3.5                          |
| DB               | MongoDB via Spring Data MongoDB                      |
| Auth             | JJWT (HS256) + a custom `OncePerRequestFilter`, Spring Security for `BCryptPasswordEncoder` |
| Validation       | Jakarta Bean Validation (`spring-boot-starter-validation`) |
| File upload      | `MultipartFile` + `FileStorageService`               |
| Bill parsing     | Gemini 2.5 Flash (`RestClient` → Google Generative Language API) |
| Config           | `spring-dotenv` (reads `.env`)                        |
| Docs             | springdoc-openapi + Swagger UI                        |
| Ops              | Spring Boot Actuator (`/actuator/health`)             |
| Money            | `BigDecimal` throughout (no floating point)           |

## Project structure

```
backend/
├── pom.xml
├── mvnw, mvnw.cmd, .mvn/         # Maven wrapper (no local Maven install needed)
├── .env.example                 # copy to .env and fill in
├── Dockerfile                   # multi-stage build, non-root runtime user
└── src/main/
    ├── java/com/splitpay/
    │   ├── SplitPayApplication.java
    │   ├── config/                      # typed @ConfigurationProperties, JacksonConfig, OpenApiConfig
    │   ├── controller/                  # REST controllers
    │   ├── dto/                         # request/response DTOs with bean-validation annotations
    │   ├── exception/                   # ApiException + GlobalExceptionHandler
    │   ├── model/                       # @Document models
    │   ├── repository/                  # Spring Data repositories
    │   ├── security/                    # JwtService, JwtAuthFilter, RateLimitFilter, SecurityConfig
    │   ├── service/                     # business logic
    │   └── web/                         # ApiResponse envelope helper
    └── resources/
        └── application.yml
```

## Running

1. Copy `.env.example` to `.env` and fill in:
   - `DATABASE_URL` — MongoDB connection string
   - `JWT_SECRET` — at least 32 characters
   - `GEMINI_API_KEY` — Google Gemini API key
   - `PORT` — optional, defaults to `4000`
   - `ALLOWED_ORIGINS` — optional, comma-separated CORS origins (defaults to `*`)
   - `TRUST_PROXY` — optional, only set `true` behind a proxy you control that overwrites `X-Forwarded-For`
   - `UPLOAD_RATE_LIMIT_PER_HOUR` — optional, per-user cap on `/bills/upload` (default 20)

2. Start it:

   ```bash
   ./mvnw spring-boot:run        # Linux/macOS/Git Bash
   mvnw.cmd spring-boot:run      # Windows cmd/PowerShell
   ```

   Or build and run a jar:

   ```bash
   ./mvnw clean package
   java -jar target/splitpay-backend-1.0.0.jar
   ```

   Or via Docker:

   ```bash
   docker build -t splitpay-backend .
   docker run --env-file .env -p 4000:4000 splitpay-backend
   ```

3. Run tests:

   ```bash
   ./mvnw test
   ```

The server listens on `PORT` (default **4000**). Base path: `/api/v1`.

- Swagger UI: `/swagger-ui.html`
- OpenAPI spec: `/v3/api-docs`
- Health check: `/actuator/health` (with `/actuator/health/liveness` and `/actuator/health/readiness` probe groups)

## API

Auth header: `Authorization: Bearer <jwt>`. Unmarked endpoints require it.

### Auth (`/api/v1`)

| Method | Path                      | Notes  |
|--------|---------------------------|--------|
| POST   | `/signUp`                 | public |
| POST   | `/login`                  | public; locks the account for 15 min after 5 failed attempts |
| POST   | `/logout`                 | invalidates all outstanding JWTs for the user (bumps `tokenVersion`) |
| PATCH  | `/updateProfile`          |        |
| PATCH  | `/changePassword`         | also bumps `tokenVersion`, invalidating stolen tokens |
| GET    | `/getUserDetails`         |        |

### Groups (`/api/v1/group`)

| Method | Path             | Notes |
|--------|------------------|-------|
| POST   | `/create`        | creator is always added to `members` |
| GET    | `/get/{id}`      | |
| GET    | `/getAll`        | |
| DELETE | `/delete/{id}`   | |
| POST   | `/invite`        | requester must be a group member |
| POST   | `/invite/accept` | |
| POST   | `/invite/reject` | |
| GET    | `/invite/pending`| |

### Bills / expenses (`/api/v1/bills`)

| Method | Path                          | Notes                                             |
|--------|-------------------------------|----------------------------------------------------|
| POST   | `/upload`                     | multipart, file field `bill`; parsed via Gemini Vision, rate-limited per user |
| POST   | `/manual`                     | create an expense without a receipt image           |
| GET    | `/getBillDetails/{expenseId}` | group-membership gated                              |
| GET    | `/getAllBills`                | `?group=<id>`                                       |
| GET    | `/getAssignments`             | `?group=<id>`; returns both `allAssignments` and `allAssigments` (misspelled key kept for the existing Flutter client) |
| PATCH  | `/assign-money`                | requester must be a group member                   |
| PATCH  | `/assign-Equally`              | residual cent goes to the last debtor               |
| POST   | `/settleAssignment`            |                                                     |
| POST   | `/payment`                     | records a payment against an expense                |
| POST   | `/markAsPaid`                  |                                                     |
| GET    | `/split/{expenseId}`           |                                                     |
| DELETE | `/deleteBill`                  | expects id in body/query                            |
| DELETE | `/delete/{expenseId}`          |                                                     |
| GET    | `/{expenseId}/image`           | serves the stored receipt image, group-gated (not a public static path) |
| GET    | `/{expenseId}/audit`           | append-only audit trail of mutations on the expense  |

### Notifications (`/api/v1/notifications`)

| Method | Path            | Notes |
|--------|-----------------|-------|
| GET    | `/`             | |
| PUT    | `/{id}/read`    | |
| PUT    | `/read-all`     | |
| DELETE | `/{id}`         | |

## Security notes

- All group/bill endpoints verify the *requester* is a member of the relevant group before
  reading or mutating data (fixes prior IDOR gaps).
- JWTs carry a `tv` (tokenVersion) claim; `changePassword` and `logout` bump the user's stored
  version, instantly invalidating existing tokens. `logout` signs out all devices — there's no
  per-token session store.
- Gemini API key is sent via the `x-goog-api-key` header, not a URL query string.
- `RateLimitFilter` ignores `X-Forwarded-For` unless `TRUST_PROXY=true`, and prunes stale buckets
  on a schedule. Login additionally locks an account for 15 minutes after 5 consecutive failures.
- `/bills/upload` is throttled per user (`UPLOAD_RATE_LIMIT_PER_HOUR`, default 20/hr) since each
  call is a paid Gemini Vision request.
- Money fields are `BigDecimal` end-to-end (never `double`).
- Request DTOs use Jakarta Bean Validation (`@NotBlank`, `@Email`, password strength pattern,
  cascading `@Valid` on nested lists).
