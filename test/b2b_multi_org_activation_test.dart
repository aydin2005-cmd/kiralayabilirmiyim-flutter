import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kiralayabilir_miyim/screens/b2b_activation_screen.dart';
import 'package:kiralayabilir_miyim/screens/b2b_login_screen.dart';
import 'package:kiralayabilir_miyim/services/b2b_api_client.dart';

const _smsRetrieverChannel = MethodChannel(
  'com.riskmetriks.kiralayabilirmiyim/sms_retriever',
);

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition,
) async {
  for (var i = 0; i < 40; i++) {
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
    'multi-org activation reveals organizations only after OTP verification',
    (tester) async {
      final startBodies = <Map<String, dynamic>>[];
      final verifyBodies = <Map<String, dynamic>>[];

      final httpClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;

        if (request.url.path == '/b2b/auth/activate/start') {
          startBodies.add(body);

          return http.Response(
            jsonEncode({
              'success': true,
              'selection_required': false,
              'challenge_id': 'activation-challenge-1',
              'code_length': 6,
            }),
            200,
            headers: {
              'content-type': 'application/json',
            },
          );
        }

        if (request.url.path == '/b2b/auth/activate/verify') {
          verifyBodies.add(body);

          if (!body.containsKey('organization_id')) {
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

          expect(
            body['organization_id'],
            'org-b',
          );

          return http.Response(
            jsonEncode({
              'success': true,
              'selection_required': false,
              'member_id': 'member-b',
              'organization_id': 'org-b',
              'organization_name': 'Firma B',
              'role': 'operator',
              'status': 'active',
            }),
            200,
            headers: {
              'content-type': 'application/json',
            },
          );
        }

        fail(
          'Unexpected request path: ${request.url.path}',
        );
      });

      final api = B2BApiClient(
        httpClient: httpClient,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: B2BActivationScreen(
            initialPhone: '5551112233',
            apiClient: api,
          ),
        ),
      );

      // SECURITY: organization choices must not be exposed before OTP.
      expect(
        find.byKey(
          const ValueKey(
            'b2b-activation-org-org-a',
          ),
        ),
        findsNothing,
      );

      expect(
        find.byKey(
          const ValueKey(
            'b2b-activation-org-org-b',
          ),
        ),
        findsNothing,
      );

      await tester.tap(
        find.text(
          'Aktivasyon Kodu G\u00f6nder',
        ),
      );

      await _pumpUntil(
        tester,
        () => startBodies.isNotEmpty,
      );

      expect(
        startBodies,
        hasLength(1),
      );

      expect(
        startBodies.single.containsKey(
          'organization_id',
        ),
        isFalse,
      );

      await _pumpUntil(
        tester,
        () => find.byType(EditableText).evaluate().length == 4,
      );

      expect(
        find.byType(EditableText),
        findsNWidgets(4),
      );

      // Still no organization disclosure merely because OTP was sent.
      expect(
        find.byKey(
          const ValueKey(
            'b2b-activation-org-org-a',
          ),
        ),
        findsNothing,
      );

      expect(
        find.byKey(
          const ValueKey(
            'b2b-activation-org-org-b',
          ),
        ),
        findsNothing,
      );

      await tester.enterText(
        find.byType(EditableText).at(1),
        '123456',
      );

      await tester.enterText(
        find.byType(EditableText).at(2),
        'sample-password-123',
      );

      await tester.enterText(
        find.byType(EditableText).at(3),
        'sample-password-123',
      );

      await tester.tap(
        find.text(
          'Aktivasyonu Tamamla',
        ),
      );

      await _pumpUntil(
        tester,
        () => verifyBodies.isNotEmpty,
      );

      expect(
        verifyBodies,
        hasLength(1),
      );

      expect(
        verifyBodies.first['challenge_id'],
        'activation-challenge-1',
      );

      expect(
        verifyBodies.first['code'],
        '123456',
      );

      expect(
        verifyBodies.first.containsKey(
          'organization_id',
        ),
        isFalse,
      );

      // Only now, after OTP verification, may organization choices appear.
      await _pumpUntil(
        tester,
        () => find
            .byKey(
              const ValueKey(
                'b2b-activation-org-org-b',
              ),
            )
            .evaluate()
            .isNotEmpty,
      );

      expect(
        find.byKey(
          const ValueKey(
            'b2b-activation-org-org-a',
          ),
        ),
        findsOneWidget,
      );

      expect(
        find.byKey(
          const ValueKey(
            'b2b-activation-org-org-b',
          ),
        ),
        findsOneWidget,
      );

      expect(
        find.byType(B2BLoginScreen),
        findsNothing,
      );

      final orgBFinder = find.byKey(
        const ValueKey(
          'b2b-activation-org-org-b',
        ),
      );

      await tester.ensureVisible(orgBFinder);
      await tester.pump();

      await tester.tap(orgBFinder);

      await _pumpUntil(
        tester,
        () => verifyBodies.length >= 2,
      );

      expect(
        verifyBodies,
        hasLength(2),
      );

      expect(
        verifyBodies[1]['organization_id'],
        'org-b',
      );

      expect(
        verifyBodies[1]['challenge_id'],
        'activation-challenge-1',
      );

      expect(
        verifyBodies[1]['code'],
        '123456',
      );

      await _pumpUntil(
        tester,
        () => find.byType(B2BLoginScreen).evaluate().isNotEmpty,
      );

      expect(
        find.byType(B2BLoginScreen),
        findsOneWidget,
      );
    },
  );
}
