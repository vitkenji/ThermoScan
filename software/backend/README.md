# ThermoScan Backend

Backend API for ThermoScan, a photovoltaic module monitoring and localized cleaning system.

The backend connects the mobile application to the database and, in a later development phase, to the embedded devices. It manages authentication, company isolation, user permissions, module configurations, and operational records.

## Technology Stack

- Language: Go.
- HTTP router: Chi.
- Database: PostgreSQL.
- Database driver: pgx.
- Database access: sqlc, using handwritten SQL queries to generate typed Go code.
- API style: REST with JSON.
- Authentication: JWT access tokens and refresh tokens.
- Password storage: bcrypt hashes.
- Deployment: Docker and Docker Compose.

## Architecture

The backend will be implemented as a single application with a shared PostgreSQL database.

The code will be organized by responsibility and feature, keeping HTTP handling, business rules, and database access separate without introducing microservices or unnecessary architectural layers.

The mobile application and embedded devices will communicate with the backend through API endpoints. They will not access PostgreSQL directly.

## Companies and Access Control

ThermoScan uses company-based data isolation and role-based access control.

The system has four roles:

- System Admin: operates outside a company and creates companies and their initial Manager accounts.
- Manager: manages users and authorized resources within their own company.
- Technician: installs modules and accesses modules according to installation ownership and explicit permissions.
- Client: accesses modules explicitly assigned to them.

Module-level authorization complements role-based permissions.

All authorization rules must be enforced by the backend. Hiding an action in the mobile application is not sufficient to protect an endpoint.

Company membership, account status, and resource access must be validated before allowing an operation.

## Local Development and Deployment

Docker Compose will define the backend and PostgreSQL services.

Each service runs in its own container. PostgreSQL data will be stored in a persistent volume, separate from the application container.

For faster development, the Go application may also run directly on the developer's machine while PostgreSQL runs in Docker.

Application settings and secrets will be provided through environment variables. Real credentials must not be committed to the repository.

The Compose configuration is expected to live in the parent `software/` directory.
