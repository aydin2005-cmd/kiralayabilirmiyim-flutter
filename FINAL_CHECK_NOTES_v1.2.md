# Flutter v1.2 Son Kontrol Notları

Bu sürümde iki düzeltme yapıldı:

1. README içine `flutter create .` adımı eklendi.
   - ZIP içinde Android/iOS platform klasörleri yoksa `flutter run` öncesi gereklidir.

2. `CardTheme` kullanımı kaldırıldı.
   - Bazı Flutter sürümlerinde `CardTheme` / `CardThemeData` tipi uyumsuzluğu compile hatası üretebiliyordu.
   - Tema sadeleştirildi; uygulama varsayılan Card görünümüyle çalışır.

Backend uyumu:
- Backend MVP v1.2 ile uyumludur.
- Base URL varsayılan olarak Android emulator için `http://10.0.2.2:8000` ayarlıdır.
