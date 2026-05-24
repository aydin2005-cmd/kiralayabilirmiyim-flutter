# Flutter v2.6.7 — Payment return and loading UX improvements

Based on v2.6.6 icon-restored package.

## Changes

1. Payment return UX
   - Suppresses transient technical `ClientException`/connection messages during payment callback/status polling.
   - Keeps checking payment status briefly instead of showing raw technical errors to the user.
   - Shows user-friendly guidance if payment status cannot be checked.

2. Findeks PDF upload loading UX
   - Replaces the subtle bottom loading indicator with a clearer full-screen overlay.
   - Message: “Findeks raporunuz yükleniyor” and “Rapor doğrulanıyor ve değerlendirme hazırlanıyor. Lütfen bekleyiniz.”

3. Share link UX
   - After share links are created, the screen automatically scrolls to the links section.
   - Adds an “Aç” button next to each generated link.
   - Shows “Linkiniz açılıyor, lütfen bekleyiniz...” before opening external browser links.

## Backend

No backend changes required. Compatible with backend v2.10.4.
