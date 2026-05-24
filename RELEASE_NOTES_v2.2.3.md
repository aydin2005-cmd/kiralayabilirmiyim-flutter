# Flutter v2.2.3

## Düzeltilen hata

Flutter çalıştırılırken görülen şu uyarı/hata düzeltildi:

`Error: unable to find directory entry in pubspec.yaml: ...\\assets\\`

Sebep: `pubspec.yaml` içinde `assets/` klasörü tanımlıydı, ancak paket içinde bu klasör boş/eksik kaldığı için Flutter klasörü bulamıyordu.

Çözüm: `assets/.gitkeep` dosyası eklendi. Böylece assets klasörü paket içinde korunur ve Flutter tarafından bulunur.
