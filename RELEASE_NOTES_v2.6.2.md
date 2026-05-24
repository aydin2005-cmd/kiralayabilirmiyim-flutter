# Flutter v2.6.2 — Test ödeme tutarı 9 TL uyumu

- Ödeme başlatma çağrısındaki sabit `149` tutarı kaldırıldı.
- Ödeme tutarı artık backend `pricing_info.service_fee_amount` değerinden alınır.
- Backend v2.9.5 test/pilot fiyatı `9 TL` döndürdüğünde ödeme ekranı ve ödeme isteği aynı tutarı kullanır.
- Canlı lansmanda backend `149 TL` döndürdüğünde Flutter tarafında ek değişiklik gerekmeden ödeme ekranı 149 TL gösterir.
- Findeks PDF’in en fazla 16 gün paylaşılacağına dair v2.6.1 metinleri korunmuştur.
