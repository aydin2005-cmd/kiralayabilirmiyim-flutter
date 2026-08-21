import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kiralayabilir_miyim/screens/b2b_login_screen.dart';
import 'package:kiralayabilir_miyim/screens/b2b_password_reset_screen.dart';
import 'package:kiralayabilir_miyim/screens/b2b_referrals_screen.dart';
import 'package:kiralayabilir_miyim/services/b2b_api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await B2BApiClient().clearToken();
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('legacy persisted B2B token is ignored after process restart policy',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'b2b_access_token': 'legacy-persisted-token',
    });

    final api = B2BApiClient();
    expect(await api.getToken(), isNull);
  });

  test('B2B token is runtime-only and legacy secure-storage token is removed',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'b2b_access_token': 'legacy-persisted-token',
    });

    final api = B2BApiClient();
    await api.saveToken('runtime-token');

    expect(await api.getToken(), 'runtime-token');

    const storage = FlutterSecureStorage();
    expect(
      await storage.read(key: 'b2b_access_token'),
      isNull,
    );

    await api.clearToken();
    expect(await api.getToken(), isNull);
  });

  test('first package checkout does not request replacement without pending id',
      () async {
    final requests = <http.Request>[];
    final api = _checkoutApi(requests);

    await api.post(
      '/b2b/packages/checkout',
      {'product_id': 'product-25'},
    );

    expect(requests, hasLength(1));
    expect(
      jsonDecode(requests.single.body),
      {'product_id': 'product-25'},
    );
  });

  test('package checkout replaces only the persisted pending payment id',
      () async {
    final requests = <http.Request>[];
    final api = _checkoutApi(requests);
    await api.savePendingPaymentId('payment-old');

    await api.post(
      '/b2b/packages/checkout',
      {'product_id': 'product-25'},
    );

    expect(requests, hasLength(1));
    expect(
      jsonDecode(requests.single.body),
      {
        'product_id': 'product-25',
        'replace_pending': true,
        'replace_pending_payment_id': 'payment-old',
      },
    );
  });

  testWidgets('login exposes forgot-password flow with fixed Turkey phone field',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: B2BLoginScreen(
          initialPhone: '+905551112233',
          apiClient: _NoNetworkApiClient(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final forgotPassword = find.text('Şifremi Unuttum');
    expect(forgotPassword, findsOneWidget);

    final phoneField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Yetkili cep telefonu'),
    );
    expect(phoneField.controller?.text, '5551112233');
    expect(phoneField.maxLength, 10);
    expect(phoneField.decoration?.prefixText, '+90 ');

    await tester.ensureVisible(forgotPassword);
    await tester.pumpAndSettle();
    await tester.tap(forgotPassword);
    await tester.pumpAndSettle();

    expect(find.byType(B2BPasswordResetScreen), findsOneWidget);
    expect(find.text('Kurumsal şifrenizi yenileyin'), findsOneWidget);
  });

  testWidgets('applicant referral screen states that organization sends link',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: B2BReferralsScreen(
          apiClient: _ReferralApiClient(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Bu davet linki sistem tarafından gönderilmez.'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Lütfen bağlantıyı ilgili kişiye WhatsApp, SMS veya başka bir iletişim aracıyla siz gönderiniz.',
      ),
      findsOneWidget,
    );
    expect(find.text('Davet Linkini Kopyala'), findsOneWidget);
    expect(find.text('Uygulama Linkini Kopyala'), findsNothing);
    expect(find.text('Web Linkini Kopyala'), findsNothing);

    final phoneField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Aday cep telefonu'),
    );
    expect(phoneField.maxLength, 10);
    expect(phoneField.decoration?.prefixText, '+90 ');
  });

  test('password reset endpoints are public and carry expected payloads',
      () async {
    final requests = <http.Request>[];
    final api = B2BApiClient(
      httpClient: MockClient((request) async {
        requests.add(request);

        if (request.url.path.endsWith('/start')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'challenge_id': 'reset-challenge',
              'expires_in_seconds': 180,
              'resend_available_in_seconds': 60,
              'code_length': 6,
              'provider': 'test',
            }),
            200,
          );
        }

        return http.Response(
          jsonEncode({'success': true}),
          200,
        );
      }),
    );

    await api.postPublic(
      '/b2b/auth/password-reset/start',
      {'phone_number': '+905551112233'},
    );
    await api.postPublic(
      '/b2b/auth/password-reset/verify',
      {
        'challenge_id': 'reset-challenge',
        'code': '123456',
        'new_password': 'NewPassword!2',
      },
    );

    expect(requests, hasLength(2));
    expect(
      requests.every(
        (request) => !request.headers.containsKey('Authorization'),
      ),
      isTrue,
    );
    expect(
      jsonDecode(requests.first.body),
      {'phone_number': '+905551112233'},
    );
    expect(
      jsonDecode(requests.last.body),
      {
        'challenge_id': 'reset-challenge',
        'code': '123456',
        'new_password': 'NewPassword!2',
      },
    );
  });
}

B2BApiClient _checkoutApi(List<http.Request> requests) {
  return B2BApiClient(
    httpClient: MockClient((request) async {
      requests.add(request);
      return http.Response(
        jsonEncode({
          'payment_id': 'payment-new',
          'purchase_id': 'purchase-new',
        }),
        200,
        headers: {
          'content-type': 'application/json; charset=utf-8',
        },
      );
    }),
  );
}

class _NoNetworkApiClient extends B2BApiClient {}

class _ReferralApiClient extends B2BApiClient {
  @override
  Future<List<Map<String, dynamic>>> getList(String path) async {
    expect(path, '/b2b/portal/referral-links');
    return [
      {
        'link_id': 'referral-1',
        'token': 'token-1',
        'label': 'deneme',
        'invited_phone_e164': '+905052582525',
        'status': 'active',
        'created_at': '2026-08-21T17:02:00Z',
        'expires_at': '2026-08-24T17:02:00Z',
      },
    ];
  }
}
