import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kiralayabilir_miyim/screens/b2b_login_screen.dart';
import 'package:kiralayabilir_miyim/services/b2b_api_client.dart';

const _smsRetrieverChannel = MethodChannel(
  'com.riskmetriks.kiralayabilirmiyim/sms_retriever',
);

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition,
) async {
  for (var i = 0; i < 30; i++) {
    if (condition()) {
      return;
    }

    await tester.pump(
      const Duration(milliseconds: 50),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      _smsRetrieverChannel,
      (call) async {
        // Widget testinde native Android SMS Retriever yok.
        // false donmesi uygulamanin normal fallback akisini kullanir.
        return false;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      _smsRetrieverChannel,
      null,
    );
  });

  testWidgets(
    'single-org login replaces credentials with focused OTP step',
    (tester) async {
      var startRequests = 0;

      final httpClient = MockClient((request) async {
        expect(request.url.path, '/b2b/auth/login/start');
        startRequests += 1;

        return http.Response(
          jsonEncode({
            'success': true,
            'selection_required': false,
            'challenge_id': 'challenge-single-org',
            'code_length': 6,
          }),
          200,
          headers: {
            'content-type': 'application/json',
          },
        );
      });

      final api = B2BApiClient(httpClient: httpClient);

      await tester.pumpWidget(
        MaterialApp(
          home: B2BLoginScreen(
            initialPhone: '5551112233',
            apiClient: api,
          ),
        ),
      );

      expect(find.byType(EditableText), findsNWidgets(2));
      expect(find.text('Kurumsal şifre'), findsOneWidget);

      await tester.enterText(
        find.byType(EditableText).at(1),
        'sample-password-123',
      );

      await tester.tap(find.text('Giriş Kodu Gönder'));

      await _pumpUntil(
        tester,
        () => startRequests == 1,
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('b2b-login-otp-field')),
        findsOneWidget,
      );
      expect(find.text('SMS doğrulama kodu'), findsOneWidget);
      expect(find.text('Kurumsal şifre'), findsNothing);
      expect(find.text('Yetkili cep telefonu'), findsNothing);
      expect(find.text('Telefon/şifreyi değiştir'), findsOneWidget);
      expect(find.byType(EditableText), findsOneWidget);

      final otpEditable = tester.widget<EditableText>(
        find.byType(EditableText),
      );
      expect(otpEditable.focusNode.hasFocus, isTrue);

      await tester.tap(find.text('Telefon/şifreyi değiştir'));
      await tester.pump();

      expect(find.text('Kurumsal şifre'), findsOneWidget);
      expect(find.text('Yetkili cep telefonu'), findsOneWidget);
      expect(find.text('SMS doğrulama kodu'), findsNothing);
    },
  );

  testWidgets(
    'multi-org login selects organization before OTP challenge',
    (tester) async {
      final requestBodies = <Map<String, dynamic>>[];

      final httpClient = MockClient((request) async {
        expect(
          request.url.path,
          '/b2b/auth/login/start',
        );

        final decoded = jsonDecode(request.body) as Map<String, dynamic>;

        requestBodies.add(decoded);

        if (!decoded.containsKey('organization_id')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'selection_required': true,
              'organizations': [
                {
                  'organization_id': 'org-1',
                  'organization_name': 'Firma A',
                  'role': 'admin',
                },
                {
                  'organization_id': 'org-2',
                  'organization_name': 'Firma B',
                  'role': 'operator',
                },
              ],
            }),
            200,
            headers: {
              'content-type': 'application/json',
            },
          );
        }

        expect(
          decoded['organization_id'],
          'org-2',
        );

        return http.Response(
          jsonEncode({
            'success': true,
            'selection_required': false,
            'challenge_id': 'challenge-org-2',
            'code_length': 6,
          }),
          200,
          headers: {
            'content-type': 'application/json',
          },
        );
      });

      final api = B2BApiClient(
        httpClient: httpClient,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: B2BLoginScreen(
            initialPhone: '5551112233',
            apiClient: api,
          ),
        ),
      );

      expect(
        find.byType(EditableText),
        findsNWidgets(2),
      );

      await tester.enterText(
        find.byType(EditableText).at(1),
        'sample-password-123',
      );

      await tester.tap(
        find.text(
          'Giriş Kodu Gönder',
        ),
      );

      await _pumpUntil(
        tester,
        () => requestBodies.isNotEmpty,
      );

      expect(
        requestBodies,
        hasLength(1),
      );

      expect(
        requestBodies.first.containsKey(
          'organization_id',
        ),
        isFalse,
      );

      await tester.pump();

      expect(
        find.byKey(
          const ValueKey(
            'b2b-login-org-org-1',
          ),
        ),
        findsOneWidget,
      );

      expect(
        find.byKey(
          const ValueKey(
            'b2b-login-org-org-2',
          ),
        ),
        findsOneWidget,
      );

      expect(
        find.text('Firma B'),
        findsOneWidget,
      );

      final org2Finder = find.byKey(
        const ValueKey(
          'b2b-login-org-org-2',
        ),
      );

      await tester.ensureVisible(org2Finder);
      await tester.pump();

      await tester.tap(org2Finder);

      await _pumpUntil(
        tester,
        () => requestBodies.length >= 2,
      );

      expect(
        requestBodies,
        hasLength(2),
      );

      expect(
        requestBodies[1]['organization_id'],
        'org-2',
      );

      await tester.pump();

      expect(
        find.byKey(
          const ValueKey(
            'b2b-login-org-org-2',
          ),
        ),
        findsNothing,
      );

      expect(
        find.text('SMS doğrulama kodu'),
        findsOneWidget,
      );
      expect(find.text('Kurumsal şifre'), findsNothing);
      expect(find.text('Yetkili cep telefonu'), findsNothing);
      expect(find.text('Telefon/şifreyi değiştir'), findsOneWidget);
      expect(find.byType(EditableText), findsOneWidget);
    },
  );
}
