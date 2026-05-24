# Flutter v2.2.1

## Düzeltilen hata

`result_screen.dart` içinde ücretlendirme bilgilendirmesi metodu yanlışlıkla `_Band` widget kapsamına taşmıştı. Bu nedenle Flutter build sırasında:

`The getter 'pricingInfo' isn't defined for the type '_Band'`

hatası oluşuyordu.

Metot tekrar `_ResultScreenState` içine alındı.
