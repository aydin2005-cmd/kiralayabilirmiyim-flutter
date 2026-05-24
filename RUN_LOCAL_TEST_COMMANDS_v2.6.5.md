# Lokal test komutları

Flutter klasörü `C:\km-test5\flutter` altında ise:

```powershell
cd C:\km-test5\flutter
flutter clean
flutter pub get
flutter run -d dd4b67ce --dart-define=API_BASE_URL=http://192.168.9.123:8000
```

Backend ayrı PowerShell penceresinde açık kalmalıdır:

```powershell
cd C:\km-test3\backend
.\.venv\Scripts\Activate.ps1
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```
