# Flutter v2.6.2 — Test ödeme tutarı uyumu

- Ödeme başlatma çağrısındaki sabit tutar kaldırıldı.
- Ödeme tutarı artık backend `pricing_info.service_fee_amount` değerinden alınır.
- Backend test/pilot fiyatı döndürdüğünde ödeme ekranı ve ödeme isteği aynı tutarı kullanır.
- Canlı lansmanda backend tarafından döndürülen tutar Flutter tarafında ek değişiklik gerekmeden gösterilir.
- Findeks PDF’in en fazla 16 gün paylaşılacağına dair v2.6.1 metinleri korunmuştur.
