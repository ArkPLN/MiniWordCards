# Mini Word Cards

Chinese documentation: [README_zh.md](./README_zh.md)

Mini Word Cards is a lightweight Flutter app for vocabulary learning. It supports CSV dictionary import, fast lookup, and poker-style flashcard animation for review sessions.

## Features

- Flashcard learning UI
- 3D card flip animation (front/back)
- Independent black-mask toggles for word/meaning (button + tap on text)
- Swipe left/right to switch cards
- Two study modes:
  - Free review
  - N cards per session
- Automatic lazy loading for large datasets (>300 words)
- Local dictionary management:
  - Import CSV
  - Enable/disable dictionaries
  - Export dictionaries
  - Delete dictionaries
- Settings:
  - Theme mode
  - Lazy-load optimization toggle (enabled by default, persisted)
  - GitHub entry (Settings -> About)

## Project Structure

```text
lib/
  data/            bundled dictionary data
  dto/             data transfer objects
  pages/           screens and widgets
  repositories/    repository layer
  services/        database/settings/file services
test/              tests
```

## Environment

- Flutter: 3.x (match your local project SDK)
- Dart: ^3.10.4
- Android build chain: AGP 8.9.1

## Quick Start

```bash
flutter pub get
flutter run
```

## Common Commands

```bash
flutter analyze
flutter test
flutter run -d windows
flutter run -d chrome
flutter build apk --release --target-platform android-arm64
```

## Recommended CSV Fields

- `word`
- `meaning`
- `abbreviation` (optional)

## Troubleshooting

- `Could not acquire the lock to .dart_tool/.../.lock`
  - Kill stale `dart/flutter` processes, remove the lock file, then retry.
- Android AAR metadata / AGP compatibility errors
  - Keep the Android toolchain in this repo (AGP 8.9.1).
