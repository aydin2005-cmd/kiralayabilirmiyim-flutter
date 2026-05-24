# Flutter MVP v2.2.23

- API base URL can now be configured at runtime with `--dart-define=API_BASE_URL=...`.
- Default remains `http://10.0.2.2:8000` for Android emulator.
- Real Android phone testing can use the computer local network IP, for example:
  `flutter run --dart-define=API_BASE_URL=http://192.168.1.34:8000`
