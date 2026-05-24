# Flutter v1.1 Entegrasyon Notları

Bu sürüm Backend MVP v1.1 ile uyumludur.

## Değişenler

- `ApiClient` artık token'ı `flutter_secure_storage` içinde saklar.
- Sessiz mock fallback'ler kaldırıldı.
- Backend `detail` hata mesajları kullanıcıya gösterilir.
- OTP doğrulama sonrası `access_token` zorunlu beklenir.
- Başvuru oluşturma sonrası `id` zorunlu beklenir.
- PDF upload sonrası `validation_status == valid` beklenir.
- Ödeme sonrası `status == paid` beklenir.
- Analiz sonrası gerçek `analysis_id` beklenir.
- Sonuç ekranı backend `summary_text`, `recommendation_text`, `shareable` alanlarını kullanır.

## Test

1. Backend v1.1 çalıştır:
   ```bash
   uvicorn app.main:app --reload
   ```

2. Flutter’da backend URL ayarla:
   ```dart
   static const String baseUrl = 'http://10.0.2.2:8000';
   ```

3. Uygulamayı çalıştır:
   ```bash
   flutter pub get
   flutter run
   ```

4. Demo OTP:
   ```text
   123456
   ```

## Not

Gerçek Findeks PDF yerine testte Findeks ibareleri içeren metin katmanlı bir PDF gerekir.
Backend, metin katmanı olmayan taranmış PDF’leri reddeder.
