# Kiralayabilir Miyim Flutter v2.2.24

- Real Android phone testing fix: default API base URL is now `http://192.168.9.123:8000` for the user's current local network.
- `--dart-define=API_BASE_URL=...` is still supported if the computer IP changes.
- Emulator testing can still be run with `--dart-define=API_BASE_URL=http://10.0.2.2:8000`.
- This release is only to fix the real-phone connection timeout caused by old/hardcoded `10.0.2.2:8080` usage in the user's active folder/build.
