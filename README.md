# Flutter To-Do Mobile (Minimal skeleton)

This archive contains a minimal Flutter project **skeleton** for a mobile-only to-do app.
It includes:
- `pubspec.yaml` with dependencies (shared_preferences, uuid)
- `lib/main.dart` — full app code (draggable To Do & Done lists, edit, persistence)
- `README.md` — this file

### Important
This archive intentionally contains only the Dart code and `pubspec.yaml`.
To generate the full Android/iOS build folders, run `flutter create .` in the project directory (requires Flutter SDK on a PC or on your device if set up):
```bash
flutter pub get
flutter create .
flutter run
```

If you prefer, you can copy `lib/main.dart` into an existing Flutter project's `lib/` folder and add the dependencies to that project's `pubspec.yaml`.