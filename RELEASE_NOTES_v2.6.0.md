# Kiralayabilir Miyim Flutter v2.6.0

## Web / hukuki link güncellemesi

- Canlı web sitesi alan adı `https://kiralayabilirmiyim.com` uygulama içine merkezi sabit olarak eklendi.
- `lib/services/legal_links.dart` eklendi.
- KVKK Aydınlatma Metni, Açık Rıza Metni, Gizlilik Politikası, Kullanım Şartları, Ön Bilgilendirme, Cayma Hakkı ve İletişim sayfaları için dış bağlantı açma desteği eklendi.
- Onaylar ekranında zorunlu onay metinlerinin yanında ilgili hukuki sayfa bağlantıları gösterildi.
- Ödeme ekranında Ön Bilgilendirme, Kullanım Şartları ve Cayma Hakkı bağlantıları gösterildi.
- Destek e-postası `destek@kiralayabilirmiyim.com` olarak eklendi.
- Açılış ekranına RiskMetriks sahipliği ve web sitesine yönlendirme kartı eklendi.

## Not

Bu sürüm backend API adresini değiştirmez. Lokal/cihaz testi için mevcut `API_BASE_URL` davranışı korunmuştur. Canlı backend'e geçerken uygulama şu parametreyle derlenmelidir:

```powershell
flutter run --dart-define=API_BASE_URL=https://api.kiralayabilirmiyim.com
```
