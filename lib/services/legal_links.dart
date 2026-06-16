import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LegalLinks {
  static const String base = 'https://kiralayabilirmiyim.com';

  static const String home = '$base/';
  static const String contact = '$base/iletisim.html';
  static const String iletisim = contact;

  static const String legalTexts = '$base/hukuki-metinler.html';
  static const String hukukiMetinler = legalTexts;

  static const String kvkkNotice = '$base/hukuki/kvkk-aydinlatma-metni.html';
  static const String kvkk = kvkkNotice;
  static const String kvkkAydinlatmaMetni = kvkkNotice;

  static const String explicitConsent =
      '$base/hukuki/findeks-acik-riza-metni.html';
  static const String acikRiza = explicitConsent;
  static const String findeksAcikRiza = explicitConsent;
  static const String findeksConsent = explicitConsent;

  static const String findeksUploadConsent =
      '$base/hukuki/findeks-raporu-yukleme-ve-isleme-onayi.html';
  static const String findeksRaporuYuklemeOnayi = findeksUploadConsent;

  static const String resultShareConsent =
      '$base/hukuki/sonuc-raporu-paylasim-onayi.html';
  static const String sonucRaporuPaylasimOnayi = resultShareConsent;

  static const String findeksPdfShareConsent =
      '$base/hukuki/findeks-pdf-raporu-paylasim-onayi.html';
  static const String findeksPdfPaylasimOnayi = findeksPdfShareConsent;

  static const String terms = '$base/hukuki/kullanim-sartlari.html';
  static const String termsOfUse = terms;
  static const String usageTerms = terms;
  static const String kullanimSartlari = terms;

  static const String privacyPolicy = '$base/hukuki/gizlilik-politikasi.html';
  static const String privacy = privacyPolicy;
  static const String gizlilik = privacyPolicy;
  static const String gizlilikPolitikasi = privacyPolicy;

  static const String preliminaryInfo =
      '$base/hukuki/mesafeli-hizmet-on-bilgilendirme-metni.html';
  static const String preInfo = preliminaryInfo;
  static const String preInformation = preliminaryInfo;
  static const String preliminaryInformation = preliminaryInfo;
  static const String onBilgilendirme = preliminaryInfo;

  static const String deliveryTerms =
      '$base/teslimat-ve-dijital-hizmet-sunum-kosullari.html';
  static const String delivery = deliveryTerms;
  static const String teslimat = deliveryTerms;

  static const String refundPolicy = '$base/iptal-iade-politikasi.html';
  static const String refund = refundPolicy;
  static const String iade = refundPolicy;
  static const String caymaHakki = refundPolicy;

  static Future<void> open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final uri = Uri.parse(url);

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!opened) {
        messenger?.showSnackBar(
          const SnackBar(
            content:
                Text('Bağlantı açılamadı. Lütfen daha sonra tekrar deneyin.'),
          ),
        );
      }
    } catch (_) {
      messenger?.showSnackBar(
        const SnackBar(
          content:
              Text('Bağlantı açılamadı. Lütfen daha sonra tekrar deneyin.'),
        ),
      );
    }
  }
}
