# Flutter v2.6.3 — Kimlik ekranı ve telefon format güncellemesi

Bu paket v2.6.2 üzerine hazırlanmıştır.

## Değişiklikler

- Kimlik bilgileri ekranı güncellendi:
  - `Adınız`
  - `Varsa 2. adınız`
  - `Soyadınız`
  - `TCKN`
- Kimlik ekranına kullanıcı notu eklendi:
  - “Lütfen adınızı ve soyadınızı kimlik kartınızdaki ile aynı şekilde giriniz.”
- `Varsa 2. adınız` alanı opsiyonel bırakıldı.
- Profil kaydında backend'e `middle_name` alanı gönderilir.
- Result ekranındaki yerel maskeli isim üretimi ikinci adı da destekler.
- Giriş ekranındaki telefon alanı güncellendi:
  - `+90` otomatik prefix olarak gösterilir.
  - Kullanıcı yalnızca kalan cep telefonu kısmını girer.
  - Örnek: `532 123 45 67`
  - Backend'e normalize edilmiş `+905XXXXXXXXX` formatı gönderilir.
- Telefon doğrulama mesajı Türkiye cep telefonu formatına göre netleştirildi.
