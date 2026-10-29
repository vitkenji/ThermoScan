# ThermoScan Mobile App

Mobile application for ThermoScan, a photovoltaic module monitoring and localized cleaning system.

The application provides access to company administration, user management, module configuration, measurements, cleaning history, and alerts according to the authenticated user's permissions.

## Technology Stack

- Language: Dart.
- Framework: Flutter.
- State management: Riverpod.
- HTTP client: Dio.
- Navigation: go_router.
- Secure credential storage: flutter_secure_storage.
- Backend communication: REST API with JSON.

## Architecture

The application will use a feature-based structure.

Each feature will group its screens, state management, and data-access code. Shared functionality, such as API configuration, authentication, navigation, and visual styling, will be placed in a common core layer.

The architecture should remain simple and suitable for a school project. Additional abstractions should only be introduced when they solve an actual implementation need.

The application communicates with the ThermoScan backend and does not connect directly to PostgreSQL.

## Authentication and Authorization

Authentication is handled by the backend using JWT access tokens and refresh tokens.

The application will:

- Provide login and logout flows.
- Store the refresh token using secure storage.
- Manage authenticated requests and token renewal.
- Require a password change when indicated by the backend.
- Display the authenticated user's role.
- Adapt navigation and available actions to the user's permissions.

The backend remains the authority for access control. Client-side visibility rules are only a user-interface convenience.

## User Roles

- System Admin: creates companies and their initial Manager accounts.
- Manager: manages users and resources within their own company.
- Technician: installs modules and accesses modules permitted by the backend.
- Client: accesses modules assigned to them.

Administrative features will be part of the same application and will be displayed only to authorized users.


## Environment Configuration

The backend base URL must be configurable for local development and deployment.

Backend secrets, database credentials, and token-signing keys must never be included in the application.

The application will not require a separate mobile backend service for the initial authentication and CRUD features.

## Development Approach

Features will be implemented incrementally, starting with authentication and user administration.

When device data is not yet available, development may use clearly identified mock data. Mock responses must remain separate from the real API integration.

