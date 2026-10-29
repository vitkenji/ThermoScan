# ThermoScan — Mobile App Design Specification

## 1. Product Overview and Authority

ThermoScan is a mobile application for a prototype photovoltaic inspection and localized cleaning system. The app communicates with the Go backend, not directly with PostgreSQL. Firmware integration, device telemetry, thermal processing, and notifications are later-phase features.

Platform: Flutter mobile application, written in Dart. Stitch/web/phone-frame mockups are visual references, not a requirement to ship a web application.
Language: English (EN-US) throughout the interface.
Theme: Light mode only for the current design.
Logo: Use approved horizontal and isolated-symbol PNG assets. Do not invent a replacement logo.

This document specifies presentation and navigation. It does not override the permission matrix, backend contracts, or physical safety requirements. Follow AGENT_CONTEXT.md and the latest explicit project decisions. Where a backend capability or workflow is not defined, do not invent it from a mockup.

Confirmed app stack: Riverpod, Dio, go_router, and flutter_secure_storage. Backend: Go, Chi, pgx/v5, sqlc, and PostgreSQL. Do not introduce another stack because an exported mockup uses it.

## 2. Design Tokens


### Colors

| Token | Hex | Usage |
|---|---|---|
| primary | #0B4F6C | Primary buttons, active tab, headers |
| background | #F4F8FB | App background |
| surface | #FFFFFF | Cards, sheets, modals |
| border | #D5DEE7 | Card borders, dividers |
| text-primary | #0F1B2D | Main text |
| text-secondary | #5B6B80 | Secondary text, labels |
| accent | #19B5D6 | Links, highlights, informational chips |
| secondary | #FF8A1F | Solar/energy accents, warnings (light) |
| success | #0F7D43 | Success states, resolved status |
| warning | #B45309 | Warning states, low reservoir |
| error | #C62828 | Errors, critical hotspot, unresolved |
| gradient-thermal | #1E4FD8 → #19B5D6 → #FFD43B → #FF8A1F → #E5322D | Thermal map and hotspot indicators ONLY |

### Typography

| Style | Font | Weight | Size/Line |
|---|---|---|---|
| H1 | Space Grotesk | 700 | 32/40 |
| H2 | Space Grotesk | 700 | 24/32 |
| H3 | Space Grotesk | 500 | 18/24 |
| Body | Inter | 400 | 16/24 |
| Body-medium | Inter | 500 | 16/24 |
| Data | Inter | 600 | 14/20 (tabular numbers) |
| Caption | Inter | 400 | 12/16 |

### Layout

- Grid: 8 px base (spacing: 8, 16, 24, 32, 48, 64)
- Screen margin: 24 px
- Touch target: minimum 48 px
- Corner radius: 8 px (chips), 12 px (buttons, fields), 16 px (cards)
- Shadows: NONE on cards/buttons (flat design, border-only cards)

### Iconography

- Grid: 24 px, 2 px stroke, rounded terminals/joins, 2 px corner radius, no fill
- Color: #0B4F6C on light backgrounds
- Required icons: Panel, Hotspot, Water Drop, Sun, Energy/Bolt, Alert, History, Settings, Reservoir, Location Pin, Compass, User, Company/Building, Notification Bell, Share, PDF/Document, Search, Plus, Edit, Chevron, Check, X, Filter, Download

## 3. Scope and Global UI Rules

### Implementation phases

- Phase 1: authentication, sessions, mandatory password change, own profile, company provisioning, user administration, and password resets.
- Future phase: module installation/configuration, assignments, telemetry, maps, cleaning history, operational alerts, PDF exports, and notification preferences.
- Future screens may remain in the prototype but must not silently become Phase 1 deliverables.

### Roles and context

- Each account has exactly one role: System Admin, Manager, Technician, or Client.
- Each account belongs to one company, except System Admin.
- Display the authenticated role on authenticated screens; do not show a role chip before identity is known.
- General screens show “Technician”, not “Installer” or “Shared”. Those relationships are module-specific.
- On module screens, use “Technician · Installer”, “Technician · Shared”, or “Client · Assigned” only when applicable to that module.
- All roles, memberships, account/company activity and resource permissions are enforced by the backend. UI visibility is not authorization.
- If access is revoked while a screen is open, stop displaying protected content on the next authorization failure and return to an appropriate screen.

### Visual and data rules

- Flat, border-only cards; no drop shadows on cards or buttons.
- Thermal gradient only for thermal maps and thermal indicators.
- No reservoir percentage, remaining-volume gauge, or percentage progress bar.
- Display the time of the latest water reading; historical data is not a live safety guarantee.
- The thermal threshold is fixed at baseline +10 °C and is not editable.
- Verification is scheduled no earlier than 30 minutes after the pump stops following either a complete or interrupted cleaning, subject to valid measurement conditions. Do not promise execution exactly 30 minutes later.
- Scan step and acquisition geometry are internal firmware concerns with a known documentation conflict. Do not expose editable controls or assert disputed values in the UI.
- Handle loading, empty, validation, network, authorization, and expired-session states.
- No offline write queue or silent synchronization is required in Phase 1. Report failed saves honestly; preserve input where practical and offer explicit retry.
- Do not automatically retry non-idempotent creation or password-reset requests without a defined backend strategy.
- Never present fabricated telemetry as real data. Development mocks must be clearly separate.

### Session behavior

- Access token lifetime: 15 minutes. Refresh token lifetime: 30 days.
- Multiple sessions are supported; logout ends the current session.
- Refresh tokens use secure storage; credentials and tokens must not appear in logs.
- Password changes and resets revoke previous sessions. After a successful password change, clear local credentials and navigate to Login with “Password updated. Please log in again.”
- When must_change_password is true, force the password-change flow. Only password change and logout are available as protected actions; do not open home or profile.
- Account/company deactivation blocks protected access even if a token has not expired.

## 4. Components

| Component | Description |
|---|---|
| Primary Button | Filled primary, white text, radius 12, height 48 |
| Secondary Button | Outlined primary, transparent background, radius 12, height 48 |
| Danger Button | Error fill, white text; destructive/administrative confirmation |
| Text Field | White background, border, radius 12, label and helper/error text |
| Card | White, border, radius 16, padding 16 |
| Status Chip | Color plus readable label; never color alone |
| Role Chip | Authenticated role; module relationship only in module context |
| Bottom Navigation | Future operational navigation: Modules, Alerts, Settings |
| Module Sub-tabs | Overview, Measurements, Cleanings, Configuration; Access for Manager only |
| Water Status Card | Water available / Insufficient water / Water status unavailable, latest reading time |
| Thermal Map | Backend-composed inspection map with dynamic dimensions and temperature legend |
| List Item | Leading icon, title, subtitle, contextual actions |
| Modal | Confirmation or one-time temporary-password display |
| Toast | Short supplementary feedback; not the only presentation of a temporary password |
| Empty State | Honest description and authorized optional action |
| Alert Card | Severity, title, module, event time; no unsupported percentage claims |
| FAB | Authorized primary creation action, primary color, 56 px |
| Activity Chip | Active / Inactive for administrative records |

Temporary-password modal: show only the newly returned password, with Copy Password and Done. Explain that it cannot be retrieved later. Do not persist it in local storage or include it in analytics/logs. A later reset creates a new password; reopening the user never reveals the old one.

## 5. Navigation and Access Rules

### Phase 1

- System Admin: Companies home, company provisioning, authorized Manager password reset, own profile, logout. No operational module navigation.
- Manager: Administration home with Users and Clients, own profile, logout. Module functions are future scope.
- Technician and Client: a simple role-aware home stating that monitoring features are not yet available in this phase, own profile, logout. Do not claim there are zero modules just because the endpoint is not implemented.
- Do not expose nonfunctional operational tabs as if integrated. Future mock screens remain separately identified.

### Future operational navigation

Manager, Technician and Client: Modules · Alerts · Settings. Manager also has Administration access. System Admin keeps a dedicated Companies area without operational tabs.

### User administration

- System Admin creates companies with their initial default Manager and resets Manager passwords. It does not create additional Managers.
- Manager creates additional Managers, Technicians and Clients within the company.
- Only the account owner edits personal profile fields.
- Manager may activate/deactivate Technicians and Clients, not other Managers.
- Default Manager cannot be deleted or deactivated.
- No role change, company transfer, or hard-delete user control.
- Administrative relationships (responsible Managers, authorized assignments) are distinct from editing another person's profile.
- Do not infer company deactivation permissions from the existence of an activity field. An administrative status-change action requires its own approved API/policy.

## 6. Screen Inventory

Existing screen IDs are preserved for reference. New screens are appended. “Future” means design reference, not authorization to implement now.

### SCR-01 — Splash / Session Check
Phase: Phase 1. Roles: All.
- Approved logo and loading indicator.
- Check stored session, renew when applicable, and obtain current identity/activity state.
- Route to Login, mandatory Change Password, or the appropriate phase-specific home.
- Distinguish network failure from confirmed invalid session; do not fabricate an authenticated identity.

### SCR-02 — Login
Phase: Phase 1. Roles: All.
- Email and password fields, Log In action, loading and validation/error states.
- Copy: “Welcome back”; generic credential error “Invalid email or password”.
- A password-help link may show guidance only, not an unimplemented email recovery flow.
- Help: Technicians/Clients contact their Manager; Managers contact the System Admin. System Admin recovery remains an operational process, not a public signup/reset flow.

### SCR-03 — Mandatory Password Change
Phase: Phase 1. Roles: All authenticated accounts requiring change.
- New password and confirmation fields; current password/credential inputs must follow the API contract.
- Copy: “Set a new password”; “Your temporary password must be changed before continuing.”
- Provide Logout. No home/profile navigation while change is required.
- On success revoke the previous session locally and return to Login; do not navigate directly to home using the old token.

### SCR-04 — Companies Home
Phase: Phase 1. Role: System Admin. Approved scope includes company list and details; endpoint contracts still need implementation.
- Company names and activity status; search when supported; Create Company action; Profile and Logout access.
- Do not add operational data, Manager counts, or list/detail calls unless returned by the authorized API.
- Loading, empty, error. Copy: “No companies yet.”

### SCR-05 — Create Company
Phase: Phase 1. Role: System Admin.
- Required: company name, default Manager name, default Manager email.
- Optional: company address.
- Creation sets activity and timestamps on the server; no timestamp fields.
- Transaction creates company and default Manager; success modal displays the generated temporary password once.
- Copy: “Company created. Share the default Manager's temporary password now. It will not be shown again.”
- The API, not the client, assigns is_default_manager and company membership.

### SCR-06 — Company Details / Manager Reset Selection
Phase: Phase 1. Role: System Admin. Company read access and scoped Manager lookup for password reset are approved.
- Company name, optional address, activity state and a list of Managers showing only name, email and default/additional designation for password-reset selection.
- No Create Manager button and no company user-directory browsing or operational information.
- Manager lookup/listing for reset must use an explicitly authorized, narrowly scoped API; do not reuse GET /users across companies.
- Implement the approved narrow lookup as part of Phase 1. No Technician/Client directory, profile editing, additional-Manager creation, or operational access is granted.

### SCR-07 — Create Additional Manager
Phase: Phase 1. Role: Manager, own company only.
- Name and email; role fixed to Manager for this dedicated screen.
- Show generated temporary password once; mandatory first-login password change.
- This screen is reachable from Manager administration, never System Admin company provisioning.

### SCR-08 — Reset Manager Password
Phase: Phase 1. Role: System Admin.
- Confirm target identity before reset.
- Success displays a new temporary password once; previous sessions revoked; mandatory change enabled.
- No access to the Manager's previous password.

### SCR-09 — Modules Home
Phase: Future. Roles: Manager, Technician, Client.
- List only accessible modules, by name; MAC/identifier secondary when relevant.
- Manager: company modules. Technician: effective installed/shared access. Client: assigned modules.
- Technician-only Start Installation action. Manager shortcuts may include Pending Actions and Clients.
- Separate monitoring state, anomaly state, water state and timestamp; do not flatten all into a misleading single status.
- Water status is binary/unknown, not a percentage bar.
- Empty states refer to actual successful responses, not missing integration.

### SCR-10 — Module Overview
Phase: Future. Roles: Authorized Manager, Technician, Client.
- Module name, module-specific role relationship, monitoring state and sub-tabs.
- Backend-composed map for the identified inspection; display scan time separately from map-generation time when needed.
- Latest acquisition summary: time, thermal values, voltage, current, power and anomaly indicators.
- Cleaning result/status shown distinctly from detection. Show Waiting for Safe Conditions, Verification Pending, Retry Pending, or Attempt Limit Reached from backend workflow data; these labels do not create new operation-status enums. Never show a fourth eligible pump-started attempt.
- Binary water status with last-reading timestamp.
- Installer, dimensions, location, orientation and interval.
- Export action identifies the data/inspection/acquisition being exported; do not combine mismatched records without labeling.
- Map states: no completed inspection, processing, available, generation failed.

### SCR-11 — Measurement History
Phase: Future. Roles: Users with module access.
- Group/filter acquisitions by inspection; show acquisition time, X position, hotspot state and electrical values.
- Distinguish scheduled inspection failure from a valid acquisition. Do not invent a failed Measurement row when the backend models failure on Inspection.
- Empty, loading, error; filters only for supported API fields.

### SCR-12 — Cleaning History
Phase: Future. Roles: Users with module access.
- Start/end, target X position, actual duration, estimated water use if available, operation status and verification result.
- Allowed operation states: Scheduled, In Progress, Completed, Refused, Failed.
- Insufficient water before activation: Refused, reason insufficient_water.
- Insufficient water during operation: Failed, reason insufficient_water; pump interrupted.
- Operational failure is not proof of thermal persistence. Do not label it Unresolved without a defined assessment.
- Group all attempt records by anomaly; show pump-started attempt count out of 3. Refusals before pump activation do not consume the limit.
- After interruption, show verification pending before allowing any automatic retry. After a complete cleaning, persistent anomaly ends as Unresolved without another automatic wash.
- No manual retry, pending-cleaning cancellation, verification cancellation or remote stop button in this version.

### SCR-13 — Module Configuration
Phase: Future. Roles: Users with module access, field-specific rights.

| Fields | Manager | Installer with effective access | Shared Technician | Assigned Client |
|---|---|---|---|---|
| Installation location/orientation | Edit | Edit | Read | Read |
| Panel dimensions/array | Edit | Edit | Read | Read |
| Minimum solar angle | Edit | Edit | Edit | Read |
| Inspection interval | Edit | Edit | Read | Edit |

- Sections: dimensions, panel count, spacing, coordinates, orientation and acquisition sources, solar angle, interval.
- Interval options: 1, 7, 15 or custom integer days >=1.
- Fixed thermal threshold +10 °C is not an editable setting.
- No reservoir percentage threshold setting and no MAC replacement control.
- Save action sends only authorized changes; server checks every field.
- Readable interval log for all users with module access: author, time, old/new values.
- Copy: “Configuration updated”; “The next inspection will be recalculated without starting an immediate scan.”
- Revoked installer has no access, including no read-only fallback to protected configuration.

### SCR-14 — Module Access and Responsible Managers
Phase: Future. Role: Manager, own company.
- Technician access toggles, responsible Managers selection, assigned Clients management or link to the relevant assignment view.
- At least one responsible Manager; prevent removing the last with clear server-backed error.
- Installer can lose access; explain that installation history remains while data/configuration access is revoked.
- Regranting installer access restores installer editing rights.

### SCR-15 — Export Measurement Report
Phase: Future. Roles: Users with module access.
- Preview identifies selected record and timestamps; include only authorized data.
- Generate action and mobile-appropriate save/share behavior after success.
- Loading, ready, error. Do not assume desktop download behavior.
- Combined inspection-map versus acquisition-report content must follow the approved export contract; not finalized by this mockup.

### SCR-16 — Installation Wizard: Module and Device
Phase: Future. Role: Technician only, including technicians with no existing module access.
- Required module name, MAC and at least one responsible Manager from the same company.
- MAC required on the first persisted module record. No device replacement flow.
- Validate format and duplicate/conflict responses; knowing a MAC does not authenticate a device.
- No QR scanner in current scope.
- Approved draft flow: persist the initial module after name, MAC and responsible Managers are validated; status pending_configuration. Let the installer resume and complete configuration later.
- Display Continue Configuration for the installer with effective access. Monitoring remains blocked until configuration is valid and complete.
- Make saved versus unsaved data explicit. Exact draft endpoints still need implementation; do not claim persistence before a successful response.

### SCR-17 — Installation Wizard: Location
Phase: Future. Role: Technician.
- Capture latitude/longitude/elevation; permission handling and manual entry.
- Review and edit acquired values before submission.
- Coordinates in decimal degrees, elevation in meters; distinguish failed capture from zero.

### SCR-18 — Installation Wizard: Orientation
Phase: Future. Role: Technician.
- Instruction: “Place your phone flat and aligned with the panel surface.”
- Capture azimuth and tilt, with Sensor/Manual source tags preserved per value.
- True-north azimuth in [0°,360°); tilt in [0°,90°]. Do not silently label magnetic heading as true north.
- Sensor unavailable, permission/platform constraints and manual fallback.

### SCR-19 — Installation Wizard: Array Configuration
Phase: Future. Role: Technician.
- Panel length/width in cm, positive integer panel count, nonnegative spacing in cm, solar-angle threshold.
- Length and width >0; count integer >=1; spacing may be 0.
- Angle bounds and score/angle conversion follow the approved API/solar contract; never send a cosine score as degrees.

### SCR-20 — Installation Wizard: Review and Save
Phase: Future. Role: Technician.
- Show name, MAC, responsible Managers and all installation values with acquisition sources.
- Edit links per section; Save Module; clear saving/success/error states.
- On confirmed success navigate to module overview. Do not imply the device has fetched configuration or started monitoring merely because API save succeeded.
- On failure preserve inputs and offer explicit retry; avoid duplicate module creation or endless “Retrying...” messages.

### SCR-21 — Alerts
Phase: Future. Roles: Manager, Technician, Client according to effective access.
- Alerts identify module, type, severity and event time; tap opens an authorized destination.
- Types include unresolved anomaly, failed inspection, insufficient water; additional safety notices only when supported by event contracts.
- No 20%/5% alerts. Water sensor only reports threshold state.
- Manager operational alerts concern responsible modules; technicians accessible modules; clients assigned modules, with applicable email preferences.
- Empty copy: “No alerts to display.” Do not claim all modules are healthy.
- Water alerts follow the approved state-transition policy: alert on the first valid insufficient-water reading or a valid transition into insufficient water; suppress further low readings until a valid recovery reading permits a new low episode. Invalid readings do not count as recovery.
- Refused/interrupted cleaning has its own operational notice; do not repeat that notice for a retransmission of the same event.
- Delivery-provider choice remains pending; email preferences apply only where specified.

### SCR-22 — Pending Actions
Phase: Future. Role: Manager.
- Open issues related to modules: unresolved anomalies, failed inspections, insufficient water.
- View Module action; no implicit work-order system or close/repair command.
- Empty copy: “No pending actions to display.”
- Cleaning-related items follow Flow 7; a valid resolved assessment closes the anomaly, while restoring water alone does not. General unrelated issue closure still needs its own rule.

### SCR-23 — Own Profile and Password
Phase: Phase 1. Roles: All, except restricted mandatory-change sessions.
- Own name and email; email editing follows the confirmed own-profile policy and backend validation.
- No role, company, activity or default-Manager editing controls.
- Change Password and Logout; password change returns to Login after session revocation.
- Profile/password forms handle validation, conflicts and errors.

### SCR-24 — Administration Home
Phase: Phase 1. Role: Manager.
- Users and Clients entry points; optional counts only if API supplies them.
- Module Access entry is Future and must not appear as functional in Phase 1.
- Managers cannot edit other users' personal profiles.

### SCR-25 — Create User
Phase: Phase 1. Role: Manager.
- Role selector at creation only: Manager or Technician.
- Required name/email; Technician requires >=1 responsible Manager of the same company.
- No principal Manager distinction; all selected Managers have equal responsibility.
- Generated temporary password shown once; mandatory change.
- No edit-existing-user mode. No role transfer/change UI.

### SCR-26 — Create Client
Phase: Phase 1 for account creation; module assignment is Future.
Role: Manager.
- Required name/email, temporary-password modal.
- Client may have zero assigned modules. Do not require module selection to create the account.
- No editing another person's name/email.
- Future assignment controls manage the module relationship, not profile ownership.

### SCR-27 — Reset Technician or Client Password
Phase: Phase 1. Role: Manager, own company.
- Confirm target; display new temporary password once; mark mandatory change and revoke previous sessions.
- No reset action for Managers in this flow; Manager reset belongs to System Admin.

### SCR-28 — Email Notification Preferences
Phase: Future. Role: Client, assigned modules.
- Per-module operational-email toggle.
- Copy: “Inspection interval change emails cannot be disabled.”
- This preference concerns email, not an unapproved global push-disable policy.

### SCR-29 — Cleaning Blocked / Water State Banner
Phase: Future. Roles: Users with module access.
- Inline module state, not a standalone destination.
- Valid low reading: “Insufficient water — cleaning blocked.”
- Invalid/unavailable reading: “Water status unavailable — cleaning cannot be authorized without a valid reading.”
- Temperature event: “Panel baseline temperature above 60 °C — cleaning blocked.”
- During-cleaning water failure: “Cleaning interrupted due to insufficient water.”
- Historical notices identify the operation/time; do not imply an old alert describes a live state.
- After interruption: “Cleaning interrupted. Verification will occur no earlier than 30 minutes after the stop, when measurement conditions allow.”
- After refusal: “Cleaning blocked. Waiting for safe conditions before reassessment.”
- At limit: “Cleaning attempt limit reached.” Distinguish pending verification from a confirmed persistent anomaly.
- Restored water removes the current water block but does not prove the thermal anomaly is resolved.

### SCR-30 — Company Users List
Phase: Phase 1. Role: Manager.
- Own-company Managers and Technicians, search/filter if supported, name/email/role/activity.
- Create Manager/Technician actions; Technician responsible-Manager relationships when supported.
- Technician actions: activate/deactivate, reset password.
- Manager records: no edit-profile, deactivate or reset-password action for the logged-in Manager acting on another Manager.
- Default Manager identified and protected.
- Own profile editing uses SCR-23, not an administrative edit form.

### SCR-31 — Clients List
Phase: Phase 1. Role: Manager.
- Own-company Clients, name/email/activity; create, activate/deactivate and reset actions.
- Future assigned-module controls are separately scoped.
- No hard-delete or edit-profile action.

### SCR-32 — User Activity Confirmation
Phase: Phase 1. Role: Manager, Technician/Client targets only.
- Confirm activation/deactivation with target identity.
- Deactivation preserves history and blocks protected access.
- No confirmation that promises automatic restoration of previous sessions upon reactivation.
- No Manager/default-Manager deactivation control.

### SCR-33 — Phase 1 Home for Technician and Client
Phase: Phase 1. Roles: Technician, Client.
- Role, optional own-company identity, Profile and Logout.
- Copy: “Monitoring features will be available in a later phase.”
- No fake metrics, operational alerts or misleading “No modules” claim without real integration.

## 7. User Flows

### Flow 1 — Phase 1 Login and Mandatory Password Change
SCR-01 → SCR-02 → SCR-03 when required → SCR-02 → role home.
Normal authenticated session → SCR-04 for System Admin, SCR-24 for Manager, SCR-33 for Technician/Client.

### Flow 2 — System Admin Provisions a Company
SCR-04 → SCR-05 → one-time temporary-password modal.
Manager reset uses an approved scoped target lookup/SCR-06 → SCR-08.
System Admin does not create additional Managers through SCR-07.

### Flow 3 — Manager Creates and Manages Accounts
SCR-24 → SCR-30/SCR-31 → SCR-07/SCR-25/SCR-26.
Technician/Client activity changes → SCR-32; password reset → SCR-27.
Other users' personal profiles cannot be edited here.

### Flow 4 — Own Profile and Password
Authenticated unrestricted session → SCR-23.
Profile save stays in profile; password change → Login after clearing the previous session.

### Flow 5 — Future Technician Installation
SCR-09 → SCR-16 → SCR-17 → SCR-18 → SCR-19 → SCR-20 → SCR-10 after successful persistence.
Only Technician starts this flow. Saved module can remain pending configuration; device readiness is a separate state.

### Flow 6 — Future Monitoring and Alerts
SCR-09/SCR-21 → SCR-10 → SCR-11/SCR-12/SCR-13/SCR-15 as authorized.
Manager may open SCR-22. Automatic cleaning retries follow Flow 7; no manual physical-action or cancellation buttons.

### Flow 7 — Future Anomaly, Bounded Retries and Verification
- Confirmed anomaly → validate all safety conditions before pump activation.
- Refused before activation: record reason, notify involved authorized users, retain pending anomaly. Do not consume a pump-started attempt.
- Recoverable block such as insufficient water or excessive temperature: wait for valid recovery, reassess anomaly and safety conditions, then retry if still needed and allowed. No tight or time-only retry loop.
- Pump starts: consume one of at most three pump-started attempts for this anomaly.
- Interrupted: stop safely, record reason/times, notify users and schedule thermal verification no earlier than 30 minutes after the actual stop. Do not wash again before a valid assessment.
- Valid post-interruption assessment shows no anomaly: mark Resolved and remove any pending automatic cleaning intention.
- Valid post-interruption assessment confirms persistence: retry only if the cause has recovered, safety allows it, and fewer than three pump-started attempts have occurred.
- Technical/sensor/motor faults do not automatically restart merely because a timer elapsed; require fault recovery/treatment and valid interlocks.
- Complete cleaning: verify no earlier than 30 minutes after completion. If absent, Resolved; if persistent, Unresolved and notify. A complete unsuccessful wash is not followed by another automatic wash, even if budget remains.
- Third interrupted attempt: no fourth pump activation. Keep the required verification; if persistence is confirmed, mark Unresolved and notify that the attempt limit was reached. If verification fails/is unavailable, do not assert thermal resolution or persistence; show assessment pending and budget exhausted.
- Failed verification is not evidence of persistence. No new wash is authorized until a valid assessment and all other prerequisites are satisfied.
- All verification depends on a valid measurement window. State “Verification pending” rather than promising an exact countdown.
- No user cancellation in this version. Automatic withdrawal of an unnecessary pending retry does not cancel inspection history or erase attempt records.

## 8. Mock Data

Use clearly identified development fixtures, never production credentials.

- Companies: Company A (Active), Company B (Inactive).
- Roles: one company-independent System Admin, Managers A1/A2, Technicians A1/A2, Clients A1/A2.
- Use UUIDs for API IDs. Friendly names such as “PV-001 — Roof Array” are labels, not a change to UUID identity.
- Example acquisition: 42.5 °C, 18.2 V, 4.1 A, 74.6 W; retain acquisition and inspection timestamps.
- Water examples: Water available / Insufficient water / Water status unavailable, each with the applicable reading time.
- Map fixture: composed inspection matrix with explicit dimensions and scan metadata, not a fixed 32×24 final map.
- Include technician-shared, installer-revoked, no-assignment Client, expired-session and mandatory-password-change states.
- Temporary passwords are fixture-only and must never become real bootstrap credentials.

## 9. Requirement Traceability and Pending Decisions

This is a partial UI mapping, not a claim that every system requirement needs a screen.

| Area | Screens | Existing requirement IDs |
|---|---|---|
| Authentication/session | 01–03, 23 | SFR17, SNFR10 |
| Company/default Manager | 04–06 | SFR15, SFR16 |
| Additional Managers/Technicians | 07, 24, 25, 30 | SFR18, SFR19 |
| Clients/temporary password | 26, 27, 31 | SFR44, SFR45, SFR46 |
| Installation/location/orientation | 16–20 | SFR01–SFR06, SNFR01–SNFR04, SFR20 |
| Role-based modules/data | 09–12 | SFR22, SFR23, SFR25–SFR30, SFR47 |
| Module access/responsibility | 14 | SFR24, SFR43 |
| Solar angle/interval/log | 13 | SFR21, SFR48, SFR49, SFR50 |
| Pending actions/operational alerts | 21, 22 | SFR40, SFR41, SFR42 |
| Export | 15 | SFR52 |
| Client email preferences | 28 | SFR51, SFR53 |

Later project decisions extend some original requirements, including temporary passwords for every role. Do not invent new requirement IDs for these decisions.

Water requirements SFR31–SFR34 and SNFR11 contain legacy continuous-level assumptions and need formal reconciliation with the approved binary-sensor update. The latest binary-sensor decision controls this design: one physical threshold, insufficient water blocks cleaning and raises an event, unknown readings are unsafe. No percentage UI.

Outstanding items must not be silently decided by visuals:
- Approved System Admin company/read/Manager-lookup scope is fixed; exact endpoint and response contracts still need implementation.
- Approved draft save/resume behavior is fixed; exact endpoint contracts still need implementation.
- Exact map alignment/interpolation algorithm and export record composition.
- Notification delivery providers and event/payload details. Water state-transition suppression is approved, not an open business decision.
- General pending-action closure rules for unrelated failures; the cleaning retry/verification rules below are approved. Do not infer a manual repair/close command.
- Physical scan-step/FOV documentation conflict and solar-angle versus score semantics.
- Device authentication and provisioning protocol.

## 10. Implementation and Review Checklist

- Implement one Phase 1 flow at a time with approved API requests/responses.
- Reuse design tokens and components; avoid rebuilding a different visual identity.
- Keep UI, state and API access separate without unnecessary architectural layers.
- Test authentication redirects, mandatory-change restriction, logout, expired sessions, own-profile restrictions and role-aware actions.
- Test two-company fixtures; never authorize from a hidden button alone.
- User/company activity, roles and resource access come from the server, not locally editable state.
- Verify screens against approved references and document intentional differences.
- Maintain future screens as references until their functionality is explicitly scheduled.


## 11. Approved Business Addendum — Cleaning Lifecycle

This section supersedes older single-operation-per-anomaly and unresolved-water-alert-policy statements. Follow Flow 7 consistently across firmware, API, persistence and UI.

- Maximum three pump-started attempts per anomaly; pre-start refusals do not count.
- Refusal or interruption is recorded and notified; retry is conditional, never immediate by default.
- Interruption requires thermal verification at least 30 minutes after pump stop before another wash.
- A full cleaning also requires verification at least 30 minutes after completion. Persistent anomaly after a full cleaning is Unresolved without another automatic wash.
- All conditions, measurements, remaining budget and technical-fault recovery must be rechecked locally before actuation.
- No manual cancellation or remote physical controls are introduced.
- Preserve each attempt and verification. Multiple operations may belong to one anomaly, but at most one cleaning execution for that anomaly may be active at once.
- The previous UNIQUE(anomaly_event_id) constraint on cleaning_operations is incompatible and must be revised before implementing retries. This design update does not itself alter the SQL schema.
- Retry count is a fixed internal rule, not an editable configuration field.
- Repeated telemetry must not increment attempt count, schedule duplicate actions or duplicate notices.
- Physical action must not depend on cloud availability for local interlocks. Retry scheduling and execution acknowledgement require a future device contract; do not show scheduled/executed success without backend/device confirmation appropriate to that state.
- Tests must cover recovery, low-water suppression, interrupted partial success, persistent partial result, complete unsuccessful wash, third interrupted attempt, invalid verification and offline duplicate messages.


## HTML Prototypes — Visual Reference

The Google Stitch HTML prototypes included in this repository are supplementary visual references for the Flutter application.

Before implementing a screen, locate and review the relevant prototype, when available, alongside this design specification.

### How to Use the Prototypes

- Use them to understand the intended layout, visual hierarchy, spacing, component composition, and overall appearance.
- Treat them as a starting point, not as pixel-perfect requirements.
- Reasonable adaptations are encouraged when they improve usability, accessibility, mobile behavior, or consistency with shared components.
- Preserve the project's visual identity without copying every detail mechanically.
- Implement the interface using Flutter widgets and the agreed application architecture. Do not embed the HTML in a WebView or adopt its web dependencies merely to reproduce the prototype.

### Priority and Limitations

- Current business rules, permissions, API contracts, and approved project decisions take precedence over prototype content.
- This design specification takes precedence over conflicting or outdated prototype details.
- Prototype buttons, fields, mock data, and navigation do not authorize new features or define business rules.
- Some prototypes may contain outdated behavior, such as reservoir percentages, unsupported administrative actions, or previous cleaning rules. Do not reproduce those inconsistencies.
- Do not implement future-phase features simply because they appear in a prototype.
- Add loading, empty, validation, error, and session-expiration states even when they are not illustrated.
- If no matching prototype exists, follow this specification and reuse established application components.
- If a prototype cannot be rendered, inspect its HTML/CSS as available and report that visual comparison was not performed.

Document significant intentional deviations briefly. Minor layout adjustments that preserve the design intent do not require separate approval.