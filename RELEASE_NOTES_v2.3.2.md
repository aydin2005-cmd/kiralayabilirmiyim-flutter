# Flutter MVP v2.3.2

## Keyboard / Form UX Fix

- Form ekranlarında klavye açıldığında alt CTA butonunun içerik alanını kapatması engellendi.
- Klavye açıkken alt buton geçici olarak gizlenir; kullanıcı alanlar arasında daha rahat gezebilir.
- Liste kaydırma alanına ek alt boşluk eklendi.
- TextField scrollPadding değeri artırıldı; aktif alan klavye altında kalmayacak şekilde daha iyi konumlanır.
- Kaydırma sırasında klavyenin kapanması için keyboardDismissBehavior eklendi.

Etkilenen merkezi dosya:
- lib/widgets/flow_widgets.dart
