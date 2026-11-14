# Gym Tracker

A cross-platform workout tracker (Hevy-inspired core feature set), built with Flutter.
Targets **iOS**, **macOS**, and **Linux** desktop from a single codebase.

## Features

- **Exercise library** — 200+ bundled exercises with muscle groups & equipment,
  searchable and filterable; create custom exercises
- **Routines** — reusable workout templates with per-exercise sets and rest timers
- **Live workout tracking** — start empty or from a routine; log sets
  (weight × reps, set types: normal / warmup / drop / failure); previous-set hints;
  rest timer with +30s and skip; workout notes & body weight on finish
- **History** — all completed workouts with per-exercise set breakdown
- **Progress** — per-exercise charts (volume, estimated 1RM, max weight),
  personal records, body weight log
- **Settings** — kg/lb units, default rest timer, light/dark themes
- **Local-first** — everything stored on-device in SQLite (no account needed)

## Tech stack

- Flutter (stable) + Material 3
- Riverpod 3 (state management)
- Drift (SQLite, type-safe, migrations) via `drift_flutter`
- fl_chart (progress charts)
- flutter_local_notifications (rest-timer notifications on iOS/macOS/Linux)

## Project structure

```
lib/
  main.dart                  App entry, ProviderContainer setup
  app_shell.dart             Bottom nav / NavigationRail shell
  core/
    theme.dart               Material 3 light/dark themes
    units.dart               kg ⇄ lb conversion (kg is the storage unit)
    format.dart              Duration formatting
  data/
    database.dart            Drift schema, queries, seeding, stats logic
    providers.dart           Riverpod providers (streams, settings)
    seed/exercises.json      Bundled exercise database
  features/
    home/                    Routines list, start workout
    exercises/               Exercise picker (browse + select), create sheet
    routines/                Routine editor
    workout/                 Active workout tracker screen
    history/                 Workout history list + detail
    progress/                Charts, PRs, body weight
    settings/                App settings
    rest_timer.dart          Rest timer + notifications
    common/set_log_row.dart  Shared set-logging row widget
```

## Getting started

Flutter is managed via [mise](https://mise.jdx.dev) (`mise install` uses the
toolchain pinned in `mise.toml` / `~/.config/mise/config.toml`).

```bash
mise install            # install pinned Flutter
flutter pub get         # fetch dependencies
dart run build_runner build --delete-conflicting-outputs  # regenerate drift code
```

Run on a desktop (Linux/macOS):

```bash
flutter run -d linux
flutter run -d macos
```

Run on iOS: open `ios/Runner.xcworkspace` in Xcode on a Mac, select a device,
then `flutter run -d ios`.

## Tests

```bash
flutter test                          # unit + database tests (headless)
flutter test integration_test         # end-to-end UI tests (needs a display)
xvfb-run -a flutter test integration_test   # on headless Linux
```

## Notes

- All weights are stored in **kilograms** in the database; pounds are a display
  conversion only (toggle in Settings).
- On Linux, the SQLite file is created in the home directory by `drift_flutter`
  (`~/gym_tracker.sqlite`); on iOS/macOS it uses the standard app-support directory.
- Estimated 1RM uses the Brzycki formula: `weight × 36 / (37 − reps)`.
