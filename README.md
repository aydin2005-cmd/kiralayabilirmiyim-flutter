# Kiralayabilir Miyim – Flutter MVP v1.1

Bu paket, **Backend MVP v1.1** sözleşmesiyle uyumlu Flutter mobil uygulama iskeletidir.

## v1.1 Güncellemeleri

- Mock fallback geçişleri kaldırıldı.
- Token `flutter_secure_storage` ile saklanacak hale getirildi.
- Backend hata mesajları kullanıcıya gösterilecek şekilde düzenlendi.
- Backend v1.1 endpoint response formatlarıyla uyum sağlandı.
- Analiz sonucu gerçek `GET /analysis/{id}/result` cevabına göre gösteriliyor.
- Paylaşım linki gerçek `POST /shares` cevabından alınıyor.
- Geçmiş raporlarım ekranı `GET /applications/my` endpointine bağlandı.

## Kurulum

Bu paket bir Flutter iskeletidir. ZIP içinde Android/iOS platform klasörleri yoksa önce proje platform dosyalarını oluşturun:

```bash
flutter create .
flutter pub get
flutter run
```

Platform klasörleri zaten oluşturulmuşsa sadece şu komutlar yeterlidir:

```bash
flutter pub get
flutter run
```

## Backend URL

`lib/services/api_client.dart` içinde:

```dart
static const String baseUrl = 'http://10.0.2.2:8000';
```

Kullanım:

```text
Android Emulator: http://10.0.2.2:8000
iOS Simulator: http://localhost:8000
Gerçek cihaz: Bilgisayarın yerel IP adresi
```

## Test Kullanımı

Backend v1.1 demo OTP kodu:

```text
123456
```

veya:

```text
000000
```

## Beklenen Backend

Bu Flutter paketi şu backend paketiyle uyumludur:

```text
Kiralayabilir Miyim Backend MVP v1.1
```

## Akış

```text
Açılış
↓
Telefon girişi
↓
SMS doğrulama
↓
Ev / araç seçimi
↓
Bilgi formu
↓
Orijinal Findeks PDF yükleme
↓
Onaylar
↓
Test/pilot sürecinde 9 TL ödeme; canlı lansmanda 149 TL ödeme
↓
Analiz
↓
Sonuç
↓
İsteğe bağlı paylaşım
```

## Production Öncesi Eksikler

```text
- Gerçek ödeme sağlayıcı WebView / checkout akışı
- Uygulama ikonları
- App Store / Google Play metadata
- Crash reporting
- Analytics
- Daha gelişmiş form validasyonları
- KVKK / kullanım koşulları tam metin ekranları
```


## v1.3 Güncellemeleri

- Ev kiralama formunda şehir ve ilçe alanları dropdown yapıldı.
- Araç kiralama formunda şehir alanı dropdown yapıldı.
- Türkçe karakter içeren İstanbul / Kadıköy / Çankaya gibi değerler kontrollü şekilde gönderilir.
- JSON isteklerinde `charset=utf-8` başlığı eklendi.
- Hata mesajlarının ekranda kalma süresi artırıldı.


## v1.4 Güncellemeleri

- Sonuç modeli iki seçenekli hale getirildi.
- “Şartlı Olumlu” kaldırıldı.
- Paylaşılabilir sonuç etiketi “Kiralama İçin Uygun” oldu.
- Paylaşılamayan sonuç mesajı “Paylaşıma uygun olumlu sonuç oluşturulamadı.” oldu.
- Paylaşım butonu yalnızca `positive` sonucu için gösterilir.


## v1.5 Güncellemeleri

- Araç kiralama ekranında araç sınıfı serbest yazı olmaktan çıkarıldı.
- Araç segmenti A/B/C/D/E dropdown yapıldı.
- Backend’e `vehicle_class` alanında yalnızca `A`, `B`, `C`, `D`, `E` değerlerinden biri gönderilir.
- Segment açıklamaları:
  - A Segment — Düşük segment / ekonomik
  - B Segment — Ekonomik-kompakt
  - C Segment — Orta segment
  - D Segment — Üst segment
  - E Segment — Premium / lüks


## v1.6 Güncellemeleri

Araç segmenti açıklamaları güncellendi:

- A Segment — Küçük ekonomik
- B Segment — Kompakt

Diğer segmentler aynı kaldı:

- C Segment — Orta segment
- D Segment — Üst segment
- E Segment — Premium / lüks


## v1.7 Güncellemeleri

- SMS doğrulamasından sonra Kimlik Bilgileri ekranı eklendi.
- Kullanıcıdan ad, soyad ve TCKN alınır.
- TCKN için 11 hane ve algoritmik doğrulama kontrolü yapılır.
- Profil bilgileri backend'deki `/users/profile` endpointine gönderilir.
- PDF yükleme sırasında backend, rapordaki maskeli kimlik bilgileriyle bu profil bilgilerini eşleştirir.


## v1.8 Güncellemesi

- Sonuç ekranı backend v2.2.3 çıktılarıyla uyumlu hale getirildi.
- `explanation_items`, `display_metrics` ve `financial_summary` alanları gösterilir.
- “Son 18 Ay” dış rapor dili temizlendi; “Kanuni Takip Kaydı” ifadesi kullanılır.
- Finansal özet, kira/ortalama limit karşılaştırması ve geçilen kontroller bölümleri eklendi.


## Rapor Öncesi Bilgilendirme Onayı

Kullanıcı değerlendirme akışına devam etmeden önce raporun garanti, kefalet veya ödeme taahhüdü içermediğini belirten bilgilendirmeyi okuyup kabul etmelidir.


## v2.1 Fiyatlandırma Politikası

Ön değerlendirme ücretsizdir. Test/pilot sürecinde hizmet bedeli 9 TL olarak uygulanabilir; canlı lansmanda standart bedel 149 TL’dir. Hizmet bedeli olumlu kararın bedeli değildir; paylaşılabilir sonuç raporu oluşturma ve paylaşım hizmet bedelidir. Kriterler sağlanmazsa paylaşılabilir rapor oluşturulmaz ve ödeme alınmaz. Ödeme değerlendirme sonucunu değiştirmez.
