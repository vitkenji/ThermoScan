# ThermoScan Backend

REST API for ThermoScan, a photovoltaic module monitoring and localized cleaning system.

The backend manages authentication, session tokens, multi-tenant company isolation, role-based access control, and user administration.

## Technology Stack

- **Language:** Go (`1.25+`)
- **HTTP Router:** Chi (`v5`)
- **Database:** PostgreSQL (`16`)
- **Database Driver:** `pgx/v5`
- **Database Access:** `sqlc` (typed Go code generated from SQL queries)
- **Authentication:** JWT access tokens (`HS256`, 15 min TTL) + opaque rotating refresh tokens (30 days TTL, stored hashed with SHA-256)
- **Password Storage:** `bcrypt` (`cost 12`)
- **Deployment:** Docker and Docker Compose

## Project Structure

```text
software/backend/
├── cmd/api/                  # Application entrypoint and HTTP server bootstrap
├── db/
│   ├── migrations/           # SQL schema migrations
│   └── queries/              # sqlc SQL query definitions
├── internal/
│   ├── auth/                 # Authentication, JWT/refresh tokens, password management, and middleware
│   ├── bootstrap/            # Initial System Admin account seeding
│   ├── company/              # System Admin company & initial Manager administration
│   ├── config/               # Environment variable configuration loader
│   ├── db/                   # sqlc-generated database access layer
│   ├── httpapi/              # Chi router assembly, CORS, and integration tests
│   ├── httpjson/             # Standardized JSON response and error helpers
│   └── user/                 # Manager company user & client administration
└── sqlc.yaml                 # sqlc code generation configuration
```

## Companies and Access Control

ThermoScan enforces strict company-based data isolation and role-based access control across four roles:

- **System Admin (`system_admin`):** Operates outside company scope (`company_id = NULL`). Creates and views companies, provisions each company's initial default Manager, and resets Manager passwords into temporary passwords.
- **Manager (`manager`):** Operates strictly within their own `company_id`. Creates and lists company users (`manager`, `technician`, `client`), links Technicians to responsible Managers, activates/deactivates Technicians and Clients, and resets Technician and Client passwords.
- **Technician (`technician`):** Operates within their own `company_id` and is associated with one or more responsible Managers (`manager_technicians`).
- **Client (`client`):** Operates within their own `company_id`.

### Key Security Rules Enforced by the Backend

1. **Mandatory Password Change (`PASSWORD_CHANGE_REQUIRED`):** Users provisioned with a temporary password or whose password was reset have `must_change_password = true`. Until they complete `POST /api/v1/auth/change-password`, the authentication middleware blocks all protected endpoints except `GET /api/v1/auth/me`, `POST /api/v1/auth/change-password`, and `POST /api/v1/auth/logout`.
2. **Inactive Account Rejection (`ACCOUNT_INACTIVE`):** Attempting to sign in with valid credentials for a deactivated user account (or an inactive company) returns `403 Forbidden` with code `ACCOUNT_INACTIVE`. Active sessions for deactivated accounts are also immediately rejected by the authentication middleware.
3. **Session Revocation:** Changing a password, resetting a user's password, or deactivating a user immediately revokes all active refresh tokens for that user.
4. **Manager Protection Rules:** A Manager cannot deactivate or reset the password of another Manager (`is_default_manager` and peer Manager accounts are protected from Manager-level status/password mutations).

## Implemented API Endpoints

All endpoints are prefixed with `/api/v1` (except `/health`).

### Health

| Method | Path | Auth | Description |
| :--- | :--- | :--- | :--- |
| `GET` | `/health` (or `/api/v1/health`) | Public | Liveness and database connectivity check |

### Authentication & Profile

| Method | Path | Auth | Description |
| :--- | :--- | :--- | :--- |
| `POST` | `/api/v1/auth/login` | Public | Authenticate with email and password; returns `access_token`, `refresh_token`, and `user` |
| `POST` | `/api/v1/auth/refresh` | Public | Rotate refresh token and issue a new token pair |
| `POST` | `/api/v1/auth/logout` | Public | Revoke the provided refresh token session |
| `POST` | `/api/v1/auth/change-password` | Bearer JWT | Change own password, clear `must_change_password`, and rotate session |
| `GET` | `/api/v1/auth/me` | Bearer JWT | Retrieve authenticated user profile (includes `responsible_managers` for Technicians) |
| `PATCH` | `/api/v1/auth/me` | Bearer JWT | Update authenticated user's own `name` and `email` |

### System Admin — Companies & Managers

| Method | Path | Role | Description |
| :--- | :--- | :--- | :--- |
| `POST` | `/api/v1/companies` | `system_admin` | Create a company and its initial default Manager with a generated one-time temporary password |
| `GET` | `/api/v1/companies` | `system_admin` | List registered companies with pagination (`limit`, `offset`) |
| `GET` | `/api/v1/companies/{companyID}` | `system_admin` | Retrieve company details and its Manager accounts |
| `POST` | `/api/v1/companies/{companyID}/managers/{userID}/reset-password` | `system_admin` | Reset a company Manager's password to a new temporary password |

### Manager — Company Users & Clients

| Method | Path | Role | Description |
| :--- | :--- | :--- | :--- |
| `POST` | `/api/v1/users` | `manager` | Create a `manager`, `technician`, or `client` in the caller's company with a generated temporary password |
| `GET` | `/api/v1/users` | `manager` | List users in the caller's company (`limit`, `offset`, optional `role` filter) |
| `GET` | `/api/v1/users/{userID}` | `manager` | Retrieve user details within the caller's company (includes `manager_ids` for Technicians) |
| `PATCH` | `/api/v1/users/{userID}/status` | `manager` | Activate or deactivate a `technician` or `client` in the caller's company |
| `POST` | `/api/v1/users/{userID}/reset-password` | `manager` | Reset a `technician` or `client` password to a new temporary password |

### Standardized Error Format

All errors return a consistent JSON structure:

```json
{
  "error": {
    "code": "ACCOUNT_INACTIVE",
    "message": "this account is inactive. Contact your company Manager"
  }
}
```

Common error codes:
- `VALIDATION_ERROR` (`400`)
- `INVALID_CREDENTIALS` (`401`)
- `UNAUTHORIZED` (`401`)
- `ACCOUNT_INACTIVE` (`403`)
- `FORBIDDEN` (`403`)
- `PASSWORD_CHANGE_REQUIRED` (`403`)
- `NOT_FOUND` (`404`)
- `EMAIL_ALREADY_EXISTS` / `COMPANY_ALREADY_EXISTS` (`409`)
- `INTERNAL_ERROR` (`500`)

## Environment Variables

| Variable | Description | Default (Dev) |
| :--- | :--- | :--- |
| `PORT` | HTTP server port | `8080` |
| `DATABASE_URL` | PostgreSQL connection string | Required |
| `JWT_SECRET` | Secret key used to sign JWT access tokens | Required |
| `SYSTEM_ADMIN_EMAIL` | Initial System Admin email seeded on startup | Optional |
| `SYSTEM_ADMIN_PASSWORD` | Initial System Admin password seeded on startup | Optional |
| `SYSTEM_ADMIN_NAME` | Initial System Admin display name | `System Admin` |

## Running and Testing

### With Docker Compose (from `software/`)

```bash
cd software
sudo docker compose up -d --build
```

### Running Tests Locally

```bash
cd software/backend
go test -count=1 ./...
```
