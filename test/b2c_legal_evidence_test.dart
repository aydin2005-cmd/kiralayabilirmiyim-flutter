import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiralayabilir_miyim/services/api_client.dart';
import 'package:kiralayabilir_miyim/services/app_state.dart';
import 'package:kiralayabilir_miyim/services/payment_flow.dart';

void main() {
  setUp(() {
    AppState.instance.resetApplicationFlow();
    AppState.instance.applicationId = 'app-1';
    AppState.instance.serviceFeeAmount = 10;
    AppState.instance.serviceFeeCurrency = 'TL';
  });

  testWidgets('payment flow sends refund evidence only when accepted',
      (tester) async {
    final api = _FakePaymentApiClient(
      startResponse: {
        'status': 'paid',
        'payment_id': 'payment-1',
      },
    );

    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final paid = await PaymentFlow.startAndWait(
      context: capturedContext,
      api: api,
      onStatus: (_) {},
      refundPolicyAccepted: true,
      refundPolicyVersion: PaymentFlow.refundPolicyVersion,
    );

    expect(paid, isTrue);
    expect(api.postPaths, ['/payments/start']);
    expect(api.postBodies.single['application_id'], 'app-1');
    expect(api.postBodies.single['refund_policy_accepted'], isTrue);
    expect(
      api.postBodies.single['refund_policy_version'],
      'b2c-refund-policy-v1-2026-08-18',
    );
  });

  testWidgets('payment flow preserves old-client compatible omitted evidence',
      (tester) async {
    final api = _FakePaymentApiClient(
      startResponse: {
        'status': 'paid',
        'payment_id': 'payment-1',
      },
    );

    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final paid = await PaymentFlow.startAndWait(
      context: capturedContext,
      api: api,
      onStatus: (_) {},
    );

    expect(paid, isTrue);
    expect(
        api.postBodies.single.containsKey('refund_policy_accepted'), isFalse);
    expect(api.postBodies.single.containsKey('refund_policy_version'), isFalse);
  });

  test('result screen passes refund acceptance after existing checkbox gate',
      () {
    final source = File('lib/screens/result_screen.dart').readAsStringSync();

    expect(source, contains('refundPolicyAccepted'));
    expect(source,
        contains('Lütfen İptal / İade Politikası’nı okuyup onaylayın.'));
    expect(source, contains('refundPolicyAccepted: true'));
    expect(source,
        contains('refundPolicyVersion: PaymentFlow.refundPolicyVersion'));
  });

  test('login KVKK wording and version remain explicit', () {
    final source = File('lib/screens/login_screen.dart').readAsStringSync();

    expect(
      source,
      contains('KVKK Aydınlatma Metni’ni okudum, onaylıyorum.'),
    );
    expect(source, contains("'kvkk_notice_accepted': kvkkNoticeAccepted"));
    expect(source, contains("'kvkk_notice_version':"));
    expect(
      source,
      contains('b2c-privacy-notice-acknowledgement-v1-2026-08-18'),
    );
  });

  test('consent UI keeps existing Findeks processing action', () {
    final source = File('lib/screens/consent_screen.dart').readAsStringSync();

    expect(
      source,
      contains(
          'Findeks Risk Raporunuzdaki finansal göstergeler, kimlik eşleştirme bilgileri ve başvuru tutarı değerlendirme amacıyla analiz edilir.'),
    );
    expect(source, contains("'processing_consent': processingConsent"));
    expect(source, isNot(contains('findeks_pdf')));
  });
}

class _FakePaymentApiClient extends ApiClient {
  _FakePaymentApiClient({
    required this.startResponse,
  });

  final Map<String, dynamic> startResponse;
  final List<String> postPaths = [];
  final List<Map<String, dynamic>> postBodies = [];

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    postPaths.add(path);
    postBodies.add(Map<String, dynamic>.from(body));
    return startResponse;
  }
}
