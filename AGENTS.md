# AGENTS.md

## Overview

Cross-platform gym/workout tracker (Hevy-inspired core). Flutter single codebase
targeting iOS, macOS, and Linux desktop. Local-first: SQLite on-device, no
accounts, no network calls.

## Toolchain

- Flutter is installed via **mise**, pinned project-locally in `mise.toml`
  (currently `flutter@3.50.0-stable`). Use `mise install` to set up.
- After changing the Drift schema in `lib/data/database.dart`, regenerate code:
  `dart run build_runner build --delete-conflicting-outputs`

## Commands

- `flutter analyze` — should stay at zero errors/warnings
- `flutter test` — unit + DB tests, headless
- `flutter test integration_test` — end-to-end UI tests; requires a display
  (use `xvfb-run -a ...` on headless Linux)
- `flutter run -d linux` — run on Linux desktop

## Conventions

- **Weights are always kilograms in the DB.** Convert only at the UI boundary
  with `core/units.dart` (`formatWeight`, `parseWeight`, `weightUnitLabel`);
  the display unit flag lives in `settingsProvider` and the `isImperial` global
  (set at startup and when the setting changes).
- State management is Riverpod 3: `NotifierProvider`/`Notifier` for mutable
  state (never write `.state` from outside the notifier), `StreamProvider` for
  DB streams. Providers live in `lib/data/providers.dart`.
- All DB reads/writes go through `AppDatabase` (`lib/data/database.dart`) —
  no raw drift queries in widgets.
- Feature-first structure under `lib/features/<feature>/`; shared widgets in
  `lib/features/common/`.
- Follow the seed-exercise JSON shape when extending
  `assets/seed/exercises.json` (seeded only on first launch, DB schema v1).
- Keep changes minimal and in the existing Material 3 style; dark/light themes
  come from `core/theme.dart` (`AppTheme.light()` / `AppTheme.dark()`).

## Testing expectations

- Any change to DB queries or stats logic (volume, e1RM, records, PRs) must be
  covered in `test/data_test.dart`.
- UI flow changes should extend `integration_test/app_test.dart`.
