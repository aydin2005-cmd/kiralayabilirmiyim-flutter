# Local build/test commands for Flutter v2.6.7

```powershell
cd C:\km-test7\flutter
flutter clean
flutter pub get
flutter run -d dd4b67ce --dart-define=API_BASE_URL=https://api.kiralayabilirmiyim.com
```

Release APK:

```powershell
cd C:\km-test7\flutter
flutter clean
flutter pub get
flutter build apk --release --dart-define=API_BASE_URL=https://api.kiralayabilirmiyim.com
```

APK output:

```text
C:\km-test7\flutter\build\app\outputs\flutter-apk\app-release.apk
```
