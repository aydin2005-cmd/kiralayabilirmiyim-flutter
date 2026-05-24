# Flutter MVP v2.2.25

Backend v2.2.29 ile uyumludur.

## Değişiklikler

- Sonuç ekranındaki küçük bilgi kartlarında görülen `BOTTOM OVERFLOWED BY ... PIXELS` hatalarını azaltmak için kart oranları ve minimum yükseklikleri düzenlendi.
- Kart içindeki uzun değerler kontrollü küçültülerek taşma riski azaltıldı.
- Ana olumlu sonuç başlığı iki satırlı ve kesilmez hale getirildi:
  - `EVET,`
  - `KİRALAYABİLİRSİNİZ`
- `Kusursuz` etiketi kaldırıldı; ödeme düzeni için `Mükemmel` kullanılacak.
- Pozitif neden metinlerinde `mükemmel seviyede` ifadesi kullanılacak.
- Finansal Kapasite sıralaması düzeltildi:
  1. Mükemmel
  2. Çok İyi
  3. İyi
  4. Kabul Edilebilir
- Sonuç raporu tarihi backend tarafından dönen analiz/sonuç raporu oluşturma tarihiyle gösterilecek; Findeks rapor tarihiyle karıştırılmayacak.

## Test notu

Gerçek Android telefon testinde backend adresi bilgisayarın yerel ağ IP adresi olmalıdır. Örnek:

```text
http://192.168.9.123:8000
```
