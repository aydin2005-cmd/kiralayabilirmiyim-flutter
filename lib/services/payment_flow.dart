import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_client.dart';
import 'app_state.dart';

class PaymentFlow {
  static const refundPolicyVersion = 'b2c-refund-policy-v1-2026-08-18';

  static Future<bool> checkCurrentStatus({
    required ApiClient api,
  }) async {
    final appId = AppState.instance.applicationId;
    if (appId == null) {
      throw ApiException('Başvuru bulunamadı. Lütfen tekrar deneyin.');
    }
    final statusResponse = await api.get('/payments/status/$appId');
    if (statusResponse['payment_completed'] == true) {
      AppState.instance.markCurrentApplicationPaymentCompleted();
      return true;
    }
    final paymentStatus = statusResponse['status']?.toString().toLowerCase();
    if (paymentStatus == 'failed' || paymentStatus == 'cancelled') {
      throw ApiException(
          'Ödeme tamamlanamadı. Kartınızdan tahsilat yapılmadıysa tekrar deneyebilirsiniz.');
    }
    return false;
  }

  static Future<bool> startAndWait({
    required BuildContext context,
    required ApiClient api,
    required void Function(String message) onStatus,
    bool refundPolicyAccepted = false,
    String? refundPolicyVersion,
  }) async {
    final appId = AppState.instance.applicationId;
    if (appId == null) {
      throw ApiException('Başvuru bulunamadı. Lütfen tekrar deneyin.');
    }

    AppState.instance.resetPaymentSuccessHandling();

    onStatus('Ödeme başlatılıyor...');
    final request = <String, dynamic>{
      'application_id': appId,
      'amount': AppState.instance.serviceFeeAmount,
      'currency': 'TRY',
    };

    if (refundPolicyAccepted) {
      request['refund_policy_accepted'] = true;
      request['refund_policy_version'] =
          refundPolicyVersion ?? PaymentFlow.refundPolicyVersion;
    }

    final response = await api.post('/payments/start', request);

    final status = response['status']?.toString().toLowerCase();
    if (status == 'paid') {
      AppState.instance.markCurrentApplicationPaymentCompleted();
      return true;
    }

    final checkoutUrl = response['checkout_url']?.toString();
    if (checkoutUrl == null || checkoutUrl.isEmpty) {
      throw ApiException(
          response['message']?.toString() ?? 'Ödeme sayfası oluşturulamadı.');
    }

    onStatus('Güvenli ödeme sayfası açılıyor...');
    final uri = Uri.parse(checkoutUrl);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      throw ApiException('Ödeme sayfası açılamadı. Lütfen tekrar deneyin.');
    }

    onStatus('Ödeme sonrası uygulamaya dönün. Durum kontrol ediliyor...');

    // Poll status while the user is on the payment page and after returning to the app.
    // Temporary network/deep-link timing errors are intentionally not shown to the
    // user as technical ClientException messages; the app keeps checking briefly.
    Object? lastTransientError;
    for (var i = 0; i < 75; i++) {
      await Future.delayed(const Duration(seconds: 2));
      try {
        final statusResponse = await api.get('/payments/status/$appId');
        if (statusResponse['payment_completed'] == true) {
          AppState.instance.markCurrentApplicationPaymentCompleted();
          return true;
        }
        final paymentStatus =
            statusResponse['status']?.toString().toLowerCase();
        if (paymentStatus == 'failed' || paymentStatus == 'cancelled') {
          throw ApiException(
              'Ödeme tamamlanamadı. Kartınızdan tahsilat yapılmadıysa tekrar deneyebilirsiniz.');
        }
        lastTransientError = null;
      } on ApiException {
        rethrow;
      } catch (e) {
        lastTransientError = e;
        if (i == 0 || i % 5 == 0) {
          onStatus('Ödeme sonucu kontrol ediliyor, lütfen bekleyiniz...');
        }
        continue;
      }
    }

    if (lastTransientError != null) {
      throw ApiException(
          'Ödeme sonucunuz henüz bankadan veya ödeme kuruluşundan doğrulanmadı. Ödeme yaptıysanız lütfen kısa bir süre bekleyip “Ödeme Durumunu Kontrol Et” düğmesine basınız. Sorun devam ederse destek için bilgi@riskmetriks.com adresine yazınız.');
    }
    throw ApiException(
        'Ödeme sonucunuz henüz bankadan veya ödeme kuruluşundan doğrulanmadı. Ödeme yaptıysanız lütfen kısa bir süre bekleyip “Ödeme Durumunu Kontrol Et” düğmesine basınız. Sorun devam ederse destek için bilgi@riskmetriks.com adresine yazınız.');
  }
}
