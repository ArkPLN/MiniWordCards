# Mini Word Cards

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.10+-0175C2?style=flat&logo=dart&logoColor=white)](https://dart.dev)
[![License](https://img.shields.io/badge/License-Private-lightgrey?style=flat)](#)
[![Platforms](https://img.shields.io/badge/Platforms-Android%20%7C%20Windows-blue?style=flat)](#)

Chinese documentation: [README_zh.md](./README_zh.md)

Mini Word Cards is a lightweight Flutter app for vocabulary learning. It supports CSV dictionary import, fast lookup, and flashcard-based review sessions. It was designed for niche vocabularies that are hard to find or import in mainstream vocabulary apps, while keeping the product compact and focused.

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

- `index`
- `word`
- `meaning`
- `abbreviation` (optional)

## Troubleshooting

- `Could not acquire the lock to .dart_tool/.../.lock`
  - Kill stale `dart/flutter` processes, remove the lock file, then retry.
- Android AAR metadata / AGP compatibility errors
  - Keep the Android toolchain in this repo (AGP 8.9.1).

## Roadmap

We will keep improving software quality and ship practical features while preserving the "small but polished" product direction. PRs and suggestions are welcome.

- [x] v1.0.0 Core features: CSV import, flashcards, dictionary management
- [ ] v1.1.0 Format expansion: JSON dictionary import
- [ ] v1.2.0 Online search: FreeDictionary API integration
- [ ] v2.0.0 UI refinement: initial custom themes and UI improvements
