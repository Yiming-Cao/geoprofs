## GeoProf — Copilot instructions

Purpose: give an AI coding assistant the minimal, actionable context to be productive in this Flutter app.

- Project type: Flutter multi-platform app (mobile, web, desktop). Entry: `lib/main.dart`.
- Backend: Supabase is used for auth and backend calls via the `supabase_flutter` package.

Quick architecture notes
- Routes are declared in `lib/main.dart` (e.g. `/`, `/login`, `/dashboard`, `/admin`, `/register`, `/profile`, `/verlof`). Use these when adding/modifying pages.
- UI is split into two folders: `lib/pages/` (screen-level widgets) and `lib/components/` (reusable widgets like `header_bar.dart`, `navbar.dart`, `background_container.dart`, `protected_route.dart`).
- Auth is wrapped in `lib/components/auth.dart` which uses `Supabase.instance.client`. Prefer calling methods on `SupabaseAuth` for login/register/logout.
- Static assets & fonts: referenced in `pubspec.yaml` (`web/icons/geoprofs.png`, `lib/include/KaushanScript-Regular.ttf`). Keep paths consistent with `pubspec.yaml`.

Developer workflows (PowerShell examples)
- Install deps: `flutter pub get`
- Run on Windows desktop: `flutter pub get; flutter run -d windows`
- Run on Android emulator: `flutter pub get; flutter emulators --launch <id>; flutter run -d <deviceId>`
- Run for web (Chrome): `flutter pub get; flutter run -d chrome`
- Run tests: `flutter test`
- Static analysis & format: `flutter analyze; dart format .`

Project-specific conventions & patterns
- Pages are lightweight Widgets with `const` constructors where possible.
- Navigation is entirely via named routes defined in `main.dart` — prefer `Navigator.pushNamed(context, '/route')` for consistency.
- Use `lib/components/protected_route.dart` to gate access when implementing auth-protected views (follow pattern in existing pages).
- Use `SupabaseAuth` in `lib/components/auth.dart` for authentication flows; it uses `signInWithPassword` / `signUp` and returns simple bool success flags.
- Keep UI logic in `pages/` and side-effecting or API logic in `components/` or a new `services/` folder (if adding new service files, follow current simple service style: small wrappers around Supabase/client calls).

Integration points & external deps to be aware of
- `supabase_flutter` — Supabase is initialized in `lib/main.dart` with URL and anonKey. The keys are currently hard-coded in `main.dart`.
  - File to edit for keys: `lib/main.dart` (replace or refactor to environment-managed secrets if required).
- Other notable packages: `table_calendar`, `flutter_svg`, `image_picker`, `http` — look at pages for usage examples.
- Platform folders (android/, ios/, linux/, macos/, windows/, web/) contain platform-specific wiring. Prefer cross-platform Flutter APIs unless modifying native behavior.

Tests & linting
- Tests: there is `test/widget_test.dart`. Use `flutter test` to run.
- Lints: `flutter_lints` is enabled (see `analysis_options.yaml`). Keep code style consistent and prefer `const` where possible.

When editing files
- Preserve existing public APIs and widget shapes. Follow existing naming: page files are named like `home.dart`, `login.dart`, etc.
- Keep changes small and isolated; add tests for new logic where feasible (unit tests or widget tests in `test/`).

Where to look for examples
- Auth example: `lib/components/auth.dart`
- Route + app startup: `lib/main.dart`
- Page wiring: `lib/pages/` (e.g. `login.dart`, `register.dart`, `dashboard.dart`, `verlof.dart`)
- Assets & fonts: `pubspec.yaml`

If anything is unclear or you need environment-specific secrets (Supabase keys), ask the repo owner — keys are currently present in `lib/main.dart` and should be rotated if used elsewhere.

If you want me to expand this with: CI commands, PR rules, or add examples for adding new pages/components, say which area to expand.
