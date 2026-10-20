# Picture Match — Flutter

A modular Flutter prototype for a drag-and-drop picture-to-word matching game.

## Features

- Animal and country-flag categories
- Level selection and unlock progression
- Drag-and-drop matching
- Score, hint button, progress indicator, and star results
- Modular screens, widgets, models, data, and theme

## Requirements

- Flutter SDK (Dart SDK 3.3 or later)
- Android Studio, Xcode, or another configured Flutter target

## Run

```bash
flutter pub get
flutter run
```

## Project structure

```text
lib/
  main.dart
  data/
    game_levels.dart
  models/
    game_level.dart
    match_item.dart
  screens/
    home_screen.dart
    level_selection_screen.dart
    match_game_screen.dart
  theme/
    app_theme.dart
  widgets/
    category_card.dart
    word_chip.dart
```

## Notes

- Emoji are placeholders for image assets.
- Progress and scores are stored in memory and reset after app restart.
- This is a starter prototype; test on your target devices and run `flutter analyze`.
