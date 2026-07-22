# SplitPay Backend (Spring Boot)

Java / Spring Boot port of the original Node.js + Express backend. The core behaviour is unchanged:
the same MongoDB data model, the same JWT auth scheme, the same OCR → Gemini bill-parsing pipeline,
and — importantly — the **same JSON request/response contract**, so the existing Flutter client works
without any changes.

## Tech stack

| Concern        | Old (Node)            | New (Spring Boot)                          |
|----------------|-----------------------|--------------------------------------------|
| Runtime        | Node.js / Express 5   | Java 21 / Spring Boot 3.3                   |
| DB access      | Mongoose              | Spring Data MongoDB                         |
| Auth           | jsonwebtoken          | jjwt + a `OncePerRequestFilter`            |
| Password hash  | bcryptjs (cost 10)    | Spring Security `BCryptPasswordEncoder(10)` |
| File upload    | multer                | Spring `MultipartFile` + `FileStorageService` |
| OCR            | tesseract.js          | Tess4J                                      |
| LLM parsing    | axios → Gemini        | Spring `RestClient` → Gemini               |
| Config         | dotenv                | spring-dotenv (reads the same `.env`)       |

## Project structure

Standard Maven / Spring Boot layout:

```
backend/
├── pom.xml
├── mvnw, mvnw.cmd, .mvn/         # Maven wrapper (no local Maven install needed)
├── eng.traineddata              # Tesseract English model (used by the OCR service)
├── .env.example                 # copy to .env and fill in
└── src/main/
    ├── java/com/splitpay/
    │   ├── SplitPayApplication.java     # entry point
    │   ├── config/                      # typed config properties
    │   ├── controller/                  # REST controllers (= Express routes/controllers)
    │   ├── dto/                         # request bodies
    │   ├── exception/                   # ApiException + global handler
    │   ├── model/                       # @Document models (= Mongoose schemas)
    │   ├── repository/                  # Spring Data repositories
    │   ├── security/                    # JWT filter, service, security config
    │   ├── service/                     # business logic (= Express controllers' bodies)
    │   └── web/                         # ApiResponse envelope helper
    └── resources/
        └── application.yml
```

## Running

1. Copy `.env.example` to `.env` and fill in `DATABASE_URL`, `JWT_SECRET`, `GEMINI_API_KEY`.
2. Start it:

   ```bash
   ./mvnw spring-boot:run        # Linux/macOS/Git Bash
   mvnw.cmd spring-boot:run      # Windows cmd/PowerShell
   ```

   Or build a runnable jar:

   ```bash
   ./mvnw clean package
   java -jar target/splitpay-backend-1.0.0.jar
   ```

The server listens on `PORT` (default **4000**), same as the Node app. Base path: `/api/v1`.

## API

All endpoints and JSON shapes are identical to the original Node service:

| Method | Path                                  | Notes                                |
|--------|---------------------------------------|--------------------------------------|
| POST   | `/api/v1/signUp`                      | public                               |
| POST   | `/api/v1/login`                       | public                               |
| PATCH  | `/api/v1/updateProfile`               |                                      |
| PATCH  | `/api/v1/changePassword`              |                                      |
| GET    | `/api/v1/getUserDetails`              |                                      |
| POST   | `/api/v1/group/create`                |                                      |
| GET    | `/api/v1/group/get/{id}`              |                                      |
| GET    | `/api/v1/group/getAll`                |                                      |
| DELETE | `/api/v1/group/delete/{id}`           |                                      |
| POST   | `/api/v1/group/invite`                |                                      |
| POST   | `/api/v1/group/invite/accept`         |                                      |
| POST   | `/api/v1/group/invite/reject`         |                                      |
| GET    | `/api/v1/group/invite/pending`        |                                      |
| POST   | `/api/v1/bills/upload`                | multipart, file field name `bill`    |
| GET    | `/api/v1/bills/getBillDetails/{id}`   |                                      |
| GET    | `/api/v1/bills/getAllBills`           | `?group=<id>` (or `{group}` in body) |
| PATCH  | `/api/v1/bills/assign-money`          |                                      |
| PATCH  | `/api/v1/bills/assign-Equally`        |                                      |
| POST   | `/api/v1/bills/settleAssignment`      |                                      |
| POST   | `/api/v1/bills/payment`               |                                      |
| POST   | `/api/v1/bills/markAsPaid`            |                                      |
| GET    | `/api/v1/bills/split/{expenseId}`     |                                      |
| GET    | `/api/v1/bills/getAssignments`        | `?group=<id>` (or `{group}` in body) |

Auth header (unchanged): `Authorization: Bearer <jwt>`.

## Behavioural notes (intentional)

- **Response key compatibility.** Models are serialized with MongoDB-style `_id` keys and reference
  fields are populated into `{ _id, name, email }` subdocuments, reproducing Mongoose `.populate(...)`.
  The settlements endpoint returns both `allAssignments` and the misspelled `allAssigments` key,
  because the current Flutter client reads the misspelled one.
- **Payment route bug fixed.** The original `recordPayment` referenced an undefined `UpdatedinUser`
  variable and always crashed. The port implements the intended behaviour: validate membership,
  append the payment, save, return the expense.
- **`getAllBills` / `getAssignments`** accept the group id as a `?group=` query param (what the
  client sends) as well as in the request body (what the old GET-with-body routes expected).
