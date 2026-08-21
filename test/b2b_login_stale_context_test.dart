import 'dart:async';
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
  for (var i = 0; i < 50; i++) {
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
      (call) async => false,
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
    'credential changes clear organization choices and OTP challenge',
    (tester) async {
      final requestBodies = <Map<String, dynamic>>[];

      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;

        requestBodies.add(body);

        if (requestBodies.length == 1) {
          return http.Response(
            jsonEncode({
              'success': true,
              'selection_required': true,
              'organizations': [
                {
                  'organization_id': 'org-a',
                  'organization_name': 'Firma A',
                  'role': 'admin',
                },
                {
                  'organization_id': 'org-b',
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

        return http.Response(
          jsonEncode({
            'success': true,
            'selection_required': false,
            'challenge_id': 'challenge-new',
            'code_length': 6,
          }),
          200,
          headers: {
            'content-type': 'application/json',
          },
        );
      });

      final api = B2BApiClient(
        httpClient: client,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: B2BLoginScreen(
            initialPhone: '5551112233',
            apiClient: api,
          ),
        ),
      );

      await tester.enterText(
        find.byType(EditableText).at(1),
        'sample-password-123',
      );

      await tester.tap(
        find.text(
          'Giri\u015f Kodu G\u00f6nder',
        ),
      );

      await _pumpUntil(
        tester,
        () => find
            .byKey(
              const ValueKey(
                'b2b-login-org-org-b',
              ),
            )
            .evaluate()
            .isNotEmpty,
      );

      expect(
        find.byKey(
          const ValueKey(
            'b2b-login-org-org-b',
          ),
        ),
        findsOneWidget,
      );

      await tester.enterText(
        find.byType(EditableText).at(1),
        'changed-password-456',
      );
      await tester.pump();

      expect(
        find.byKey(
          const ValueKey(
            'b2b-login-org-org-a',
          ),
        ),
        findsNothing,
      );

      expect(
        find.byKey(
          const ValueKey(
            'b2b-login-org-org-b',
          ),
        ),
        findsNothing,
      );

      await tester.tap(
        find.text(
          'Giri\u015f Kodu G\u00f6nder',
        ),
      );

      await _pumpUntil(
        tester,
        () => find
            .text(
              'SMS do\u011frulama kodu',
            )
            .evaluate()
            .isNotEmpty,
      );

      expect(
        requestBodies,
        hasLength(2),
      );

      expect(
        requestBodies[1]['password'],
        'changed-password-456',
      );

      expect(
        requestBodies[1].containsKey(
          'organization_id',
        ),
        isFalse,
      );

      expect(
        find.text(
          'SMS do\u011frulama kodu',
        ),
        findsOneWidget,
      );

      await tester.enterText(
        find.byType(EditableText).first,
        '5551112244',
      );
      await tester.pump();

      expect(
        find.text(
          'SMS do\u011frulama kodu',
        ),
        findsNothing,
      );

      expect(
        find.text(
          'Giri\u015f Kodu G\u00f6nder',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'in-flight login response is ignored after credential change',
    (tester) async {
      final responseCompleter = Completer<http.Response>();
      var requestCount = 0;

      final client = MockClient((request) async {
        requestCount += 1;
        return responseCompleter.future;
      });

      final api = B2BApiClient(
        httpClient: client,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: B2BLoginScreen(
            initialPhone: '5551112233',
            apiClient: api,
          ),
        ),
      );

      await tester.enterText(
        find.byType(EditableText).at(1),
        'sample-password-123',
      );

      await tester.tap(
        find.text(
          'Giri\u015f Kodu G\u00f6nder',
        ),
      );

      await _pumpUntil(
        tester,
        () => requestCount == 1,
      );

      expect(
        requestCount,
        1,
      );

      // Credentials change while the old request is still in flight.
      await tester.enterText(
        find.byType(EditableText).at(1),
        'new-password-456',
      );

      responseCompleter.complete(
        http.Response(
          jsonEncode({
            'success': true,
            'selection_required': true,
            'organizations': [
              {
                'organization_id': 'stale-org',
                'organization_name': 'Stale Firma',
                'role': 'admin',
              },
            ],
          }),
          200,
          headers: {
            'content-type': 'application/json',
          },
        ),
      );

      await tester.pump(
        const Duration(milliseconds: 100),
      );
      await tester.pump(
        const Duration(milliseconds: 100),
      );

      expect(
        find.byKey(
          const ValueKey(
            'b2b-login-org-stale-org',
          ),
        ),
        findsNothing,
      );

      expect(
        find.text(
          'SMS do\u011frulama kodu',
        ),
        findsNothing,
      );

      expect(
        find.text(
          'Giri\u015f Kodu G\u00f6nder',
        ),
        findsOneWidget,
      );
    },
  );
}
