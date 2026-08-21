import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kiralayabilir_miyim/screens/b2b_login_screen.dart';
import 'package:kiralayabilir_miyim/screens/b2b_members_screen.dart';
import 'package:kiralayabilir_miyim/screens/b2b_portal_screen.dart';
import 'package:kiralayabilir_miyim/services/b2b_api_client.dart';

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
    FlutterSecureStorage.setMockInitialValues({
      'b2b_access_token': 'session-token',
    });
  });

  testWidgets(
    'switch organization clears session and reauthenticates with same phone',
    (tester) async {
      await tester.binding.setSurfaceSize(
        const Size(1000, 2400),
      );
      addTearDown(
        () => tester.binding.setSurfaceSize(null),
      );
      final requestPaths = <String>[];

      final httpClient = MockClient((request) async {
        requestPaths.add(
          '${request.method} ${request.url.path}',
        );

        if (request.method == 'GET' && request.url.path == '/b2b/auth/me') {
          return http.Response(
            jsonEncode({
              'success': true,
              'member_id': 'member-self',
              'organization_id': 'org-a',
              'organization_name': 'Firma A',
              'phone_e164': '+905551112233',
              'role': 'admin',
              'status': 'active',
            }),
            200,
            headers: {
              'content-type': 'application/json',
            },
          );
        }

        if (request.method == 'GET' &&
            request.url.path == '/b2b/portal/credits') {
          return http.Response(
            jsonEncode({
              'usable_credits': 5,
              'awaiting_activation_credits': 0,
            }),
            200,
            headers: {
              'content-type': 'application/json',
            },
          );
        }

        if (request.method == 'POST' &&
            request.url.path == '/b2b/auth/logout') {
          return http.Response(
            jsonEncode({
              'success': true,
            }),
            200,
            headers: {
              'content-type': 'application/json',
            },
          );
        }

        fail(
          'Unexpected request: ${request.method} ${request.url.path}',
        );
      });

      final api = B2BApiClient(
        httpClient: httpClient,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: B2BPortalScreen(
            apiClient: api,
          ),
        ),
      );

      final switchFinder = find.byKey(
        const ValueKey(
          'b2b-switch-organization',
        ),
      );

      await _pumpUntil(
        tester,
        () => switchFinder.evaluate().isNotEmpty,
      );

      expect(
        switchFinder,
        findsOneWidget,
      );

      await tester.ensureVisible(
        switchFinder,
      );
      await tester.pump();

      await tester.tap(
        switchFinder,
      );

      await _pumpUntil(
        tester,
        () => find.byType(B2BLoginScreen).evaluate().isNotEmpty,
      );

      expect(
        find.byType(B2BLoginScreen),
        findsOneWidget,
      );

      expect(
        requestPaths,
        contains('POST /b2b/auth/logout'),
      );

      const storage = FlutterSecureStorage();

      expect(
        await storage.read(
          key: 'b2b_access_token',
        ),
        isNull,
      );

      expect(
        find.byType(EditableText),
        findsNWidgets(2),
      );

      final phoneField = tester.widget<EditableText>(
        find.byType(EditableText).first,
      );

      expect(
        phoneField.controller.text,
        '5551112233',
      );
    },
  );

  testWidgets(
    'member management hides actions for current member only',
    (tester) async {
      await tester.binding.setSurfaceSize(
        const Size(1000, 2400),
      );
      addTearDown(
        () => tester.binding.setSurfaceSize(null),
      );
      final httpClient = MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/b2b/members') {
          return http.Response(
            jsonEncode([
              {
                'member_id': 'member-self',
                'organization_id': 'org-a',
                'phone_e164': '+905551112233',
                'role': 'admin',
                'status': 'active',
                'last_login_at': null,
              },
              {
                'member_id': 'member-other',
                'organization_id': 'org-a',
                'phone_e164': '+905559998877',
                'role': 'operator',
                'status': 'active',
                'last_login_at': null,
              },
            ]),
            200,
            headers: {
              'content-type': 'application/json',
            },
          );
        }

        fail(
          'Unexpected request: ${request.method} ${request.url.path}',
        );
      });

      final api = B2BApiClient(
        httpClient: httpClient,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: B2BMembersScreen(
            currentMemberId: 'member-self',
            apiClient: api,
          ),
        ),
      );

      await _pumpUntil(
        tester,
        () => find
            .byKey(
              const ValueKey(
                'b2b-member-self-chip',
              ),
            )
            .evaluate()
            .isNotEmpty,
      );

      expect(
        find.byKey(
          const ValueKey(
            'b2b-member-self-chip',
          ),
        ),
        findsOneWidget,
      );

      expect(
        find.byKey(
          const ValueKey(
            'b2b-member-actions-member-self',
          ),
        ),
        findsNothing,
      );

      expect(
        find.byKey(
          const ValueKey(
            'b2b-member-actions-member-other',
          ),
        ),
        findsOneWidget,
      );

      expect(
        find.text('Siz'),
        findsOneWidget,
      );
    },
  );
}
