# Kiralayabilir Miyim Flutter v2.6.5 — Android build zinciri sağlamlaştırma

Bu paket v2.6.4 üzerine hazırlanmıştır. Uygulama işlevleri korunmuştur:

- Adınız / Varsa 2. adınız / Soyadınız alanları
- +90 sabit prefiksli cep telefonu girişi
- Android v2 embedding yapısı
- Local HTTP testleri için `usesCleartextTraffic=true`

Android build tarafında güncellenenler:

- Android Gradle Plugin: 8.13.0
- Gradle Wrapper dağıtımı: 8.13
- Kotlin Gradle Plugin: 2.1.20
- compileSdk: 36
- targetSdk: 35
- minSdk: 23
- Java/Kotlin JVM target: 17

Not: AGP 8.13.0, Android API 36.1 seviyesine kadar destek verir. Gradle 8.13, bu AGP hattıyla uyumludur. Kotlin 2.1.20 seçimi, AGP 8.12/8.13 hattında Kotlin 2.2.0 ile raporlanan uyumsuzluklardan kaçınmak için bilinçli olarak yapılmıştır.
