# Flutter v2.6.8 — Payment Return Duplicate Dialog Fix

Bu sürüm v2.6.7 üzerine küçük ama kritik ödeme dönüşü iyileştirmesi içerir.

## Değişiklikler

- Ödeme başarı dönüşünde aynı başarının iki farklı akıştan işlenmesi engellendi.
- Deep link ile ödeme sonucu geldiğinde artık ikinci bir modal ödeme başarılı kutusu açılmaz.
- Ödeme başarılı bildirimi yalnızca bir kez işlenir.
- Ödeme başarılı kutusunun ekranda kalma süresi kısaltıldı.
- Backend değişikliği gerektirmez; backend v2.10.4 ile uyumludur.
