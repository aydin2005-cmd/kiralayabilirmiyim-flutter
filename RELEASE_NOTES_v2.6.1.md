# Kiralayabilir Miyim Flutter v2.6.1

## Findeks PDF paylaşım ve saklama metni güncellemesi

- Sonucu Paylaş ekranındaki Findeks PDF paylaşım metinleri 16 günlük saklama/paylaşım politikasına göre güncellendi.
- Kullanıcıya, orijinal Findeks PDF’in yalnızca ayrıca açık onay verilirse paylaşılacağı açıkça belirtildi.
- Açık rıza metnine, Findeks PDF erişiminin rapor tarihinden itibaren en fazla 16 gün süreceği eklendi.
- Bilgilendirme kartında sonuç raporu/PDF sonuç raporu ile orijinal Findeks PDF paylaşımı ayrıştırıldı.
- Yerel test notu, yeni Findeks PDF paylaşım davranışına uygun hale getirildi.

## Backend uyumu

Bu sürüm backend v2.9.3 ile uyumludur. API alanları değişmemiştir:

```json
{
  "include_findeks_pdf": true,
  "findeks_pdf_consent_given": true
}
```

Flutter tarafında zorunlu API değişikliği yoktur; güncelleme kullanıcı metinleri ve açık rıza bilgilendirmesi içindir.
