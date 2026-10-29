# ThermoScan Mobile App

Flutter mobile application for ThermoScan, a photovoltaic module monitoring and localized cleaning system.

The application provides role-based access to authentication, mandatory temporary password change, profile management, System Admin company administration, and Manager user and client administration.

## Technology Stack

- **Language:** Dart (`3.11+`)
- **Framework:** Flutter (`Material 3`)
- **State Management:** Riverpod (`flutter_riverpod`)
- **HTTP Client:** Dio (`dio`) with automatic Bearer token injection and 401 refresh token rotation
- **Navigation & Route Guards:** `go_router`
- **Secure Credential Storage:** `flutter_secure_storage`
- **Typography:** `google_fonts` (`Chakra Petch`, `IBM Plex Sans`, `IBM Plex Mono`)

## Project Structure

The Flutter project is located in `software/app/thermoscan/` and follows a feature-first architecture:

```text
software/app/thermoscan/lib/
├── core/
│   ├── config/               # Environment & API base URL configuration
│   ├── network/              # Dio client, auth interceptor, and API error mapping
│   ├── router/               # GoRouter configuration and role/session redirect guards
│   ├── storage/              # Secure storage for tokens and cached session user
│   ├── theme/                # Design system colors, typography, and Material theme
│   └── widgets/              # Reusable UI components (logo, buttons, inputs, chips, top bar, modals)
├── features/
│   ├── auth/                 # Splash, login, mandatory password change, profile, and role landing
│   ├── companies/            # System Admin company list, creation, details, and Manager password reset
│   └── users/                # Manager hub, user & client lists, user/client creation, status toggle, and password reset
└── main.dart                 # Application entrypoint
```

## Implemented Features & Screens

### Authentication & Account Lifecycle
- **Splash & Session Bootstrap:** Restores saved credentials on startup, validates the session via `GET /api/v1/auth/me`, and refreshes expired access tokens automatically.
- **Sign In:** Email and password authentication with clear error banners (including specific feedback when attempting to sign in with a deactivated account via `ACCOUNT_INACTIVE`).
- **Mandatory Password Change:** Enforced whenever `must_change_password = true` (after initial account creation or an administrative password reset). Blocks navigation to any other route until completed.
- **User Profile:** Allows any authenticated user to view their role and company metadata, update their own `name` and `email`, change their password, and sign out. For `technician` users, displays a read-only **Responsible Managers** card listing the Managers assigned to them.

### System Admin (`system_admin`)
- **Companies Home:** Searchable and refreshable list of registered companies with active status indicators and creation date.
- **Create Company:** Single-step creation of a new company and its initial default Manager account, displaying the generated one-time temporary password in a copyable modal.
- **Company Details:** Displays company overview metadata and its registered Manager accounts, allowing the System Admin to reset any Manager's password into a new one-time temporary password.

### Manager (`manager`)
- **Company Administration Hub:** Quick-access dashboard for managing Company Users and Clients.
- **Company Users Management:** Searchable list of company users with role filter chips (`All`, `Managers`, `Technicians`, `Clients`), visual highlight (`You` badge) for the currently signed-in Manager, user creation (`manager`, `technician` with multi-select responsible Managers, or `client`), account activation/deactivation for Technicians and Clients, and temporary password resets.
- **Dedicated Clients Management:** Focused list and creation workflow for `client` accounts with search, status filter (`All`, `Active Only`, `Inactive`), status toggle, and temporary password reset.

### Technician (`technician`) & Client (`client`)
- **Role Workspace & Profile Access:** Authenticated landing screen displaying account status, company membership, and direct access to profile settings and assigned responsible Managers.

## Environment Configuration

By default, the app automatically selects the local backend URL according to the runtime platform:
- **Android Emulator:** `http://10.0.2.2:8080/api/v1`
- **Desktop / iOS Simulator / Web:** `http://localhost:8080/api/v1`

You can override the backend URL at build or run time using `--dart-define`:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8080/api/v1
```

## Running and Testing

```bash
cd software/app/thermoscan

# Install dependencies
flutter pub get

# Static analysis
flutter analyze

# Run widget & flow tests
flutter test

# Launch on connected device or emulator
flutter run
```
