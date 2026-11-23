# HelpDesk Pro mobile app (Flutter)

The mobile side of HelpDesk Pro, owned by **Flutter 1**. It covers every SRS module for all
three roles (Customer, Agent, Admin) and talks only to the backend REST API. It never
connects to the database, and every permission is enforced by the backend.

Android first. Flutter 3.41 / Dart 3.11. Font: Poppins (bundled, SIL Open Font License).

**For the backend team:** `../HelpDesk Pro - Mobile UI and API Handover.pdf` shows every
screen and the exact calls, request bodies and response fields each one needs.

## What is built

| SRS module | On mobile | Main files |
|---|---|---|
| 3.1 Authentication | Sign in, register, forgot password, set new password with the emailed code, secure token storage, automatic token refresh, log out | `screens/login_screen.dart`, `register_screen.dart`, `forgot_password_screen.dart`, `services/api_client.dart` |
| 3.2 Users and categories | Own profile (all); users and roles, categories with default agent, priorities with SLA hours (Admin) | `screens/profile_screen.dart`, `screens/admin/` |
| 3.3 Tickets | Create with photo, list with search, status chips and filters, details, status change, reopen, rating, history timeline, attachments | `screens/ticket_list_screen.dart`, `ticket_detail_screen.dart`, `create_ticket_screen.dart` |
| 3.4 Assignment | Agent queue and "Take ticket", reassign, Admin assign | `ticket_list_screen.dart`, `ticket_detail_screen.dart` |
| 3.5 Replies and notes | Conversation, internal notes (staff), Waiting-for-Customer banner, reply templates | `ticket_detail_screen.dart`, `widgets/reply_composer.dart` |
| 3.6 SLA and priority | Due time, overdue flags, SLA targets editor (Admin) | `widgets/ui.dart`, `screens/admin/priorities_screen.dart` |
| 3.7 Notifications | Bell with unread badge, list, mark read, mark all read | `screens/notifications_screen.dart` |
| 3.8 Knowledge base | Help Center search and reading (all), suggestions while typing a ticket title, write and publish (staff), unpublish (Admin) | `screens/knowledge_base_screen.dart`, `article_screen.dart` |
| 3.9 Dashboard and reports | Role-based dashboard with chart and agent workload, reports with filters, Excel/PDF export via the share sheet | `screens/dashboard_screen.dart`, `reports_screen.dart` |

Not built: push notifications (extra E8, needs a Firebase project). The notification badge
refreshes every 60 seconds and when the app comes back to the foreground.

## Run it

```sh
cd mobile
flutter pub get

# With fictional data, no backend needed
flutter run --dart-define=USE_MOCK=true

# Against the real backend (Android emulator: 10.0.2.2 is your PC)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000

# Real phone on the same Wi-Fi: use your PC's LAN IP
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:5000
```

Replace `5000` with the backend's `PORT`.

Mock mode applies the same rules as the backend (customers see only their own tickets,
agents their assigned tickets and the queue, internal notes are hidden from customers, and
so on). Nothing on screen says "mock". Demo accounts, password `Demo@1234` for all:

| Role | Email |
|---|---|
| Customer | `customer1@demo.test` (also `customer2`, `customer3`) |
| Agent | `agent1@demo.test` (also `agent2`) |
| Admin | `admin@demo.test` |

In mock mode the password-reset code is `123456`.

## Build the release APK

```sh
flutter build apk --release --split-per-abi --dart-define=API_BASE_URL=http://<backend-address>:<port>
```

Use `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` for most phones. **Do not
hand out a build made with `USE_MOCK=true`**: it shows fictional data.

Signing: without `android/key.properties` the APK is signed with the debug key, which is
fine for the demo. Keystores and `key.properties` are git-ignored and must never be committed.

**OneDrive warning:** this folder is inside OneDrive, which locks files in `build/` while it
syncs and makes Gradle fail with `AccessDeniedException`. Move the repository outside
OneDrive (for example `C:\dev\HelpDesk`) before building.

## Tests and checks

```sh
flutter test       # 42 tests: SRS rules on the mock API, models, validators, widget flows
dart analyze       # use this if `flutter analyze` crashes on this machine
```

`test/mock_api_test.dart` is grouped by SRS module and lists the rules the backend must also
follow. Use it as a checklist when testing the real API on Day 8.

To regenerate the UI screenshots (used for the handover PDF):

```sh
flutter test tool/ui_screenshots_test.dart --dart-define=SHOT_DIR=<output folder>
```

## Project structure

```
lib/
  main.dart, app.dart   providers, session handling, MaterialApp
  config.dart           API_BASE_URL and USE_MOCK (--dart-define), limits
  theme.dart            colours, brand gradient, status/priority/category styles, Poppins
  models/               Ticket, TicketReply, Attachment, AppUser, lookups, insights
                        (dashboard, reports, articles, templates), notifications
  services/             ApiClient (tokens, refresh, errors), ApiEndpoints, HelpdeskApi interface,
                        RemoteHelpdeskApi (real), MockHelpdeskApi (fictional), AuthService,
                        NotificationsController, TicketEvents, TokenStorage
  screens/              one file per screen; admin/ for Admin-only screens
  widgets/              design system (ui.dart), charts, ticket card, chat bubble, reply box...
  utils/                validators and date formatting
tool/ui_screenshots_test.dart   renders every screen to PNG
```

Every backend path is in `lib/services/api_endpoints.dart` and all JSON parsing is in
`lib/models/`. If the API contract changes, those are the files to edit. The expected request
and response shapes are listed in the handover PDF.
