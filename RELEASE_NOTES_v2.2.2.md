# Flutter v2.2.2

- Consent ekranından sonra PaymentScreen yerine AnalysisScreen açılır.
- Ödeme butonu backend `/payments/initiate` endpointini çağırır; başarılı ödeme sonrası tam rapor backend'den yeniden yüklenir.
- Tam sonuç raporunda ikinci ücretlendirme bilgilendirmesi kaldırıldı.
- Paylaşım linki oluşturulduktan sonra PDF sonuç raporu linki de gösterilir.
