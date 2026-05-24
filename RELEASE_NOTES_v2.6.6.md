# Kiralayabilir Miyim Flutter v2.6.6

Base: v2.6.5 modern Android build.

Changes:
- Restored Android launcher icon resources.
- Added `android:icon` and `android:roundIcon` references in AndroidManifest.xml.
- Kept AGP 8.13.0 / Gradle 8.13 / Kotlin 2.1.20 configuration.
- Kept middle-name identity screen and +90 phone input changes.

Build command:

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://api.kiralayabilirmiyim.com
```
