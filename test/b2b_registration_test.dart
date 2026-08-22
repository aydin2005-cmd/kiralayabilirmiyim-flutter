import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kiralayabilir_miyim/screens/b2b_activation_screen.dart';
import 'package:kiralayabilir_miyim/screens/b2b_entry_screen.dart';
import 'package:kiralayabilir_miyim/screens/b2b_registration_screen.dart';
import 'package:kiralayabilir_miyim/services/b2b_api_client.dart';
import 'package:kiralayabilir_miyim/services/b2b_helpers.dart';
import 'package:kiralayabilir_miyim/widgets/primary_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('entry screen shows registration CTA and opens form',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: B2BEntryScreen(apiClient: _NoSessionApiClient()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kurumsal Hesap Oluştur'), findsOneWidget);

    await tester.tap(find.text('Kurumsal Hesap Oluştur'));
    await tester.pumpAndSettle();

    expect(find.byType(B2BRegistrationScreen), findsOneWidget);
    expect(find.text('Şirket / Ticari Unvan'), findsOneWidget);
    expect(find.text('Vergi Numarası'), findsOneWidget);
    expect(find.text('Vergi Dairesi'), findsOneWidget);
    expect(find.text('Fatura Adresi'), findsOneWidget);
    expect(find.text('E-posta'), findsOneWidget);
    expect(find.text('Yetkili Cep Telefonu'), findsOneWidget);
    expect(
      find.text('KVKK Aydınlatma Metni’ni okudum ve kabul ediyorum.'),
      findsOneWidget,
    );
    expect(
      find.text('Kullanım Şartları’nı okudum ve kabul ediyorum.'),
      findsOneWidget,
    );
  });

  testWidgets('empty required fields block registration request',
      (tester) async {
    final api = _FakeRegistrationApiClient();

    await tester.pumpWidget(_registrationApp(api));
    await tester.tap(_registrationButton());
    await tester.pump();

    expect(api.calls, 0);
    expect(find.text('Şirket / Ticari unvan giriniz.'), findsOneWidget);
  });

  testWidgets('invalid tax length blocks registration request', (tester) async {
    final api = _FakeRegistrationApiClient();

    await tester.pumpWidget(_registrationApp(api));
    await _enterRegistrationForm(
      tester,
      taxNumber: '12345',
    );
    await tester.tap(_registrationButton());
    await tester.pump();

    expect(api.calls, 0);
    expect(
      find.text('Vergi numarası 10 veya 11 haneli olmalıdır.'),
      findsOneWidget,
    );
  });

  testWidgets('invalid email blocks registration request', (tester) async {
    final api = _FakeRegistrationApiClient();

    await tester.pumpWidget(_registrationApp(api));
    await _enterRegistrationForm(
      tester,
      contactEmail: 'hatali-adres',
    );
    await tester.tap(_registrationButton());
    await tester.pump();

    expect(api.calls, 0);
    expect(
      find.text('Geçerli bir e-posta adresi giriniz.'),
      findsOneWidget,
    );
  });

  testWidgets('invalid mobile blocks registration request', (tester) async {
    final api = _FakeRegistrationApiClient();

    await tester.pumpWidget(_registrationApp(api));
    await _enterRegistrationForm(
      tester,
      ownerPhone: '2121234567',
    );
    await tester.tap(_registrationButton());
    await tester.pump();

    expect(api.calls, 0);
    expect(
      find.text('Geçerli bir Türkiye cep telefonu numarası giriniz.'),
      findsOneWidget,
    );
  });

  testWidgets('registration sends normalized phone and only business keys',
      (tester) async {
    final api = _FakeRegistrationApiClient();

    await tester.pumpWidget(_registrationApp(api));
    await _enterRegistrationForm(tester);
    await tester.tap(_registrationButton());
    await tester.pumpAndSettle();

    expect(api.calls, 1);
    expect(api.legalNames, ['RiskMetriks AŞ']);
    expect(api.taxNumbers, ['1234567890']);
    expect(api.taxOffices, ['Beykoz']);
    expect(api.billingAddresses, ['Test Mahallesi No: 1']);
    expect(api.contactEmails, ['muhasebe@example.com']);
    expect(api.ownerPhones, ['+905551112233']);
    expect(api.sentPayloadKeys.single, [
      'legal_name',
      'tax_number',
      'tax_office',
      'billing_address',
      'contact_email',
      'owner_phone',
      'privacy_notice_acknowledged',
      'privacy_notice_version',
      'terms_accepted',
      'terms_version',
    ]);
    expect(api.privacyNoticeAcknowledged, [true]);
    expect(api.privacyNoticeVersions, [
      B2BApiClient.b2bPrivacyNoticeVersion,
    ]);
    expect(api.termsAccepted, [true]);
    expect(api.termsVersions, [
      B2BApiClient.b2bTermsVersion,
    ]);
    expect(api.sentPayloadKeys.single, isNot(contains('created_by')));
    expect(api.sentPayloadKeys.single, isNot(contains('organization_id')));
    expect(api.sentPayloadKeys.single, isNot(contains('actor_type')));
  });

  test('supported pasted Turkish phone forms are reduced to field digits', () {
    for (final raw in [
      '05551112233',
      '905551112233',
      '+905551112233',
      '5551112233',
    ]) {
      final fieldDigits = turkeyMobileFieldDigits(raw);
      expect(fieldDigits, '5551112233');
      expect(normalizeTurkeyMobile(fieldDigits), '+905551112233');
    }
  });

  test('self-service registration request is public and omits bearer token',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'b2b_access_token': 'stale-b2b-token',
    });
    final requests = <http.Request>[];
    final api = B2BApiClient(
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'success': true,
            'activation_required': true,
            'owner_phone_e164': '+905551112233',
            'owner_status': 'invited',
            'activation_start_endpoint': '/b2b/auth/activate/start',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await api.registerSelfService(
      legalName: 'RiskMetriks AŞ',
      taxNumber: '1234567890',
      taxOffice: 'Beykoz',
      billingAddress: 'Test Mahallesi No: 1',
      contactEmail: 'muhasebe@example.com',
      ownerPhone: '+905551112233',
      privacyNoticeAcknowledged: true,
      privacyNoticeVersion: B2BApiClient.b2bPrivacyNoticeVersion,
      termsAccepted: true,
      termsVersion: B2BApiClient.b2bTermsVersion,
    );

    expect(requests, hasLength(1));
    expect(requests.single.url.path, '/b2b/onboarding/register');
    expect(requests.single.headers.containsKey('Authorization'), isFalse);
    expect(jsonDecode(requests.single.body), {
      'legal_name': 'RiskMetriks AŞ',
      'tax_number': '1234567890',
      'tax_office': 'Beykoz',
      'billing_address': 'Test Mahallesi No: 1',
      'contact_email': 'muhasebe@example.com',
      'owner_phone': '+905551112233',
      'privacy_notice_acknowledged': true,
      'privacy_notice_version': B2BApiClient.b2bPrivacyNoticeVersion,
      'terms_accepted': true,
      'terms_version': B2BApiClient.b2bTermsVersion,
    });
  });

  testWidgets('registration is blocked until privacy and terms are accepted',
      (tester) async {
    final api = _FakeRegistrationApiClient();

    await tester.pumpWidget(_registrationApp(api));
    await _enterRegistrationForm(tester, acceptLegal: false);
    await tester.tap(_registrationButton());
    await tester.pump();

    expect(api.calls, 0);
    expect(
      find.text('KVKK Aydınlatma Metni’ni okuyup kabul etmeniz gerekir.'),
      findsOneWidget,
    );

    await _tapLegalCheckbox(
      tester,
      'KVKK Aydınlatma Metni’ni okudum ve kabul ediyorum.',
    );
    await tester.pump();
    await tester.tap(_registrationButton());
    await tester.pump();

    expect(api.calls, 0);

    await _tapLegalCheckbox(
      tester,
      'Kullanım Şartları’nı okudum ve kabul ediyorum.',
    );
    await tester.pump();
    await tester.tap(_registrationButton());
    await tester.pumpAndSettle();

    expect(api.calls, 1);
    expect(find.byType(B2BActivationScreen), findsOneWidget);
  });

  testWidgets('duplicate submit triggers only one registration request',
      (tester) async {
    final completer = Completer<Map<String, dynamic>>();
    final api = _FakeRegistrationApiClient(completer: completer);

    await tester.pumpWidget(_registrationApp(api));
    await _enterRegistrationForm(tester);

    await tester.tap(_registrationButton());
    await tester.tap(_registrationButton());
    await tester.pump();

    expect(api.calls, 1);

    completer.complete(_successResponse());
    await tester.pumpAndSettle();
  });

  testWidgets('generalized duplicate conflict keeps form and blocks activation',
      (tester) async {
    final api = _FakeRegistrationApiClient(
      error: const B2BApiException(
        'Bu bilgilerle mevcut bir kurumsal hesap olabilir. Giriş yapmayı deneyin veya destek ile iletişime geçin.',
        statusCode: 409,
      ),
    );

    await tester.pumpWidget(_registrationApp(api));
    await _enterRegistrationForm(tester);
    await tester.tap(_registrationButton());
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Bu bilgilerle mevcut bir kurumsal hesap olabilir. Giriş yapmayı deneyin veya destek ile iletişime geçin.',
      ),
      findsOneWidget,
    );
    expect(find.byType(B2BActivationScreen), findsNothing);
    expect(find.text('RiskMetriks AŞ'), findsOneWidget);
    expect(find.text('1234567890'), findsOneWidget);
    expect(find.text('Beykoz'), findsOneWidget);
    expect(find.text('Test Mahallesi No: 1'), findsOneWidget);
    expect(find.text('muhasebe@example.com'), findsOneWidget);
    expect(find.text('5551112233'), findsOneWidget);
    expect(find.textContaining('vergi numarası ile kayıtlı'), findsNothing);
    expect(find.textContaining('telefon numarası başka'), findsNothing);
  });

  testWidgets('unexpected error shows safe fallback message', (tester) async {
    final api = _FakeRegistrationApiClient(
      error: const B2BApiException('sql_unique_constraint_internal'),
    );

    await tester.pumpWidget(_registrationApp(api));
    await _enterRegistrationForm(tester);
    await tester.tap(_registrationButton());
    await tester.pumpAndSettle();

    expect(
      find.text('Kurumsal hesap oluşturulamadı. Lütfen tekrar deneyin.'),
      findsOneWidget,
    );
    expect(find.textContaining('sql_unique_constraint_internal'), findsNothing);
  });

  testWidgets('429 keeps form values and shows retry hint', (tester) async {
    final api = _FakeRegistrationApiClient(
      error: const B2BApiException(
        'Çok fazla deneme yapıldı. Lütfen daha sonra tekrar deneyin.',
        statusCode: 429,
        retryAfterSeconds: 120,
      ),
    );

    await tester.pumpWidget(_registrationApp(api));
    await _enterRegistrationForm(tester);
    await tester.tap(_registrationButton());
    await tester.pumpAndSettle();

    expect(api.calls, 1);
    expect(find.byType(B2BActivationScreen), findsNothing);
    expect(
      find.textContaining(
        'Çok fazla deneme yapıldı. Lütfen daha sonra tekrar deneyin.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Yaklaşık 2 dakika sonra tekrar deneyebilirsiniz.',
      ),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextField, 'Şirket / Ticari Unvan'),
      findsOneWidget,
    );
    expect(find.text('RiskMetriks AŞ'), findsOneWidget);
    expect(find.text('1234567890'), findsOneWidget);
    expect(find.text('Beykoz'), findsOneWidget);
    expect(find.text('Test Mahallesi No: 1'), findsOneWidget);
    expect(find.text('muhasebe@example.com'), findsOneWidget);
    expect(find.text('5551112233'), findsOneWidget);
  });

  testWidgets('malformed success phone does not navigate to activation',
      (tester) async {
    final api = _FakeRegistrationApiClient(
      response: {
        'success': true,
        'activation_required': true,
        'owner_phone_e164': 'abc',
        'owner_status': 'invited',
        'activation_start_endpoint': '/b2b/auth/activate/start',
      },
    );

    await tester.pumpWidget(_registrationApp(api));
    await _enterRegistrationForm(tester);
    await tester.tap(_registrationButton());
    await tester.pumpAndSettle();

    expect(api.calls, 1);
    expect(find.byType(B2BActivationScreen), findsNothing);
    expect(
      find.text('Kurumsal hesap oluşturulamadı. Lütfen tekrar deneyin.'),
      findsOneWidget,
    );
    expect(find.textContaining('abc'), findsNothing);
  });

  testWidgets('successful registration navigates to editable activation phone',
      (tester) async {
    await tester.pumpWidget(_registrationApp(_FakeRegistrationApiClient()));
    await _enterRegistrationForm(tester);
    await tester.tap(_registrationButton());
    await tester.pumpAndSettle();

    expect(find.byType(B2BActivationScreen), findsOneWidget);
    expect(find.text('Kurumsal Aktivasyon'), findsOneWidget);

    final phoneField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Yetkili cep telefonu'),
    );
    expect(phoneField.controller?.text, '5551112233');
    expect(phoneField.enabled, isNot(false));
  });
}

Widget _registrationApp(_FakeRegistrationApiClient api) {
  return MaterialApp(
    home: B2BRegistrationScreen(apiClient: api),
  );
}

Finder _registrationButton() {
  return find.widgetWithText(PrimaryButton, 'Kurumsal Hesap Oluştur');
}

Future<void> _enterRegistrationForm(
  WidgetTester tester, {
  String legalName = 'RiskMetriks AŞ',
  String taxNumber = '1234567890',
  String taxOffice = 'Beykoz',
  String billingAddress = 'Test Mahallesi No: 1',
  String contactEmail = 'muhasebe@example.com',
  String ownerPhone = '5551112233',
  bool acceptLegal = true,
}) async {
  await tester.enterText(
    find.widgetWithText(TextField, 'Şirket / Ticari Unvan'),
    legalName,
  );
  await tester.enterText(
    find.widgetWithText(TextField, 'Vergi Numarası'),
    taxNumber,
  );
  await tester.enterText(
    find.widgetWithText(TextField, 'Vergi Dairesi'),
    taxOffice,
  );
  await tester.enterText(
    find.widgetWithText(TextField, 'Fatura Adresi'),
    billingAddress,
  );
  await tester.enterText(
    find.widgetWithText(TextField, 'E-posta'),
    contactEmail,
  );
  await tester.enterText(
    find.widgetWithText(TextField, 'Yetkili Cep Telefonu'),
    ownerPhone,
  );

  if (acceptLegal) {
    await _tapLegalCheckbox(
      tester,
      'KVKK Aydınlatma Metni’ni okudum ve kabul ediyorum.',
    );
    await _tapLegalCheckbox(
      tester,
      'Kullanım Şartları’nı okudum ve kabul ediyorum.',
    );
  }
}

Future<void> _tapLegalCheckbox(
  WidgetTester tester,
  String text,
) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

Map<String, dynamic> _successResponse() {
  return {
    'success': true,
    'activation_required': true,
    'owner_phone_e164': '+905551112233',
    'owner_status': 'invited',
    'activation_start_endpoint': '/b2b/auth/activate/start',
  };
}

class _NoSessionApiClient extends B2BApiClient {
  @override
  Future<String?> getToken() async => null;
}

class _FakeRegistrationApiClient extends B2BApiClient {
  final Completer<Map<String, dynamic>>? completer;
  final Object? error;
  final Map<String, dynamic>? response;

  int calls = 0;
  final legalNames = <String>[];
  final taxNumbers = <String>[];
  final taxOffices = <String>[];
  final billingAddresses = <String>[];
  final contactEmails = <String>[];
  final ownerPhones = <String>[];
  final privacyNoticeAcknowledged = <bool>[];
  final privacyNoticeVersions = <String>[];
  final termsAccepted = <bool>[];
  final termsVersions = <String>[];
  final sentPayloadKeys = <List<String>>[];

  _FakeRegistrationApiClient({
    this.completer,
    this.error,
    this.response,
  });

  @override
  Future<Map<String, dynamic>> registerSelfService({
    required String legalName,
    required String taxNumber,
    required String taxOffice,
    required String billingAddress,
    required String contactEmail,
    required String ownerPhone,
    required bool privacyNoticeAcknowledged,
    required String privacyNoticeVersion,
    required bool termsAccepted,
    required String termsVersion,
  }) async {
    calls += 1;
    legalNames.add(legalName);
    taxNumbers.add(taxNumber);
    taxOffices.add(taxOffice);
    billingAddresses.add(billingAddress);
    contactEmails.add(contactEmail);
    ownerPhones.add(ownerPhone);
    this.privacyNoticeAcknowledged.add(
          privacyNoticeAcknowledged,
        );
    privacyNoticeVersions.add(privacyNoticeVersion);
    this.termsAccepted.add(termsAccepted);
    termsVersions.add(termsVersion);
    sentPayloadKeys.add([
      'legal_name',
      'tax_number',
      'tax_office',
      'billing_address',
      'contact_email',
      'owner_phone',
      'privacy_notice_acknowledged',
      'privacy_notice_version',
      'terms_accepted',
      'terms_version',
    ]);

    if (error != null) {
      throw error!;
    }

    if (completer != null) {
      return completer!.future;
    }

    return response ?? _successResponse();
  }
}
