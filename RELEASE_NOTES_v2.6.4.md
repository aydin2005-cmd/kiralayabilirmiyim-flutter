# Flutter v2.6.4 — Android v2 embedding düzeltmesi

Bu paket v2.6.3 üzerine hazırlanmıştır.

## Değişiklikler

- Android platform klasörü Flutter Android v2 embedding yapısına uygun hale getirildi.
- `MainActivity.kt`, `io.flutter.embedding.android.FlutterActivity` kullanacak şekilde eklendi.
- Android Gradle yapı dosyaları eklendi/güncellendi.
- Lokal backend testi için HTTP erişimine izin veren `usesCleartextTraffic=true` korundu.
- Ödeme dönüş deep link şeması (`kiralayabilirmiyim://payment-result`) korundu.

## Not

Bu güncelleme, yeni bir klasöre açılan Flutter paketinde `Build failed due to use of deleted Android v1 embedding` hatasının tekrar oluşmasını engellemek için hazırlanmıştır.
