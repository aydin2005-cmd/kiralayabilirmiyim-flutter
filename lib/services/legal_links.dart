import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LegalLinks {
  static const siteBase = 'https://kiralayabilirmiyim.com';

  static const home = siteBase;
  static const kvkk = '$siteBase/kvkk-aydinlatma-metni.html';
  static const acikRiza = '$siteBase/acik-riza-metni.html';
  static const gizlilik = '$siteBase/gizlilik-politikasi.html';
  static const kullanimSartlari = '$siteBase/kullanim-sartlari.html';
  static const onBilgilendirme = '$siteBase/on-bilgilendirme.html';
  static const caymaHakki = '$siteBase/cayma-hakki.html';
  static const iletisim = '$siteBase/iletisim.html';

  static const infoEmail = 'info@kiralayabilirmiyim.com';
  static const destekEmail = 'destek@kiralayabilirmiyim.com';

  static Future<void> open(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bağlantı açılamadı. Lütfen daha sonra tekrar deneyin.')),
      );
    }
  }
}
