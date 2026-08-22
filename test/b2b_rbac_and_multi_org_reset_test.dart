import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiralayabilir_miyim/screens/b2b_password_reset_screen.dart';
import 'package:kiralayabilir_miyim/screens/b2b_portal_screen.dart';
import 'package:kiralayabilir_miyim/services/b2b_api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('operator sees candidate referrals but not team management',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: B2BPortalScreen(
          apiClient: _OperatorPortalApiClient(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Paketler'), findsOneWidget);
    expect(find.text('Aday Davetleri'), findsOneWidget);
    expect(find.text('Başvurular'), findsOneWidget);
    expect(find.text('Ekip Üyeleri'), findsNothing);
  });

  testWidgets(
      'multi-org password reset asks for organization and submits selected id',
      (tester) async {
    final api = _MultiOrgResetApiClient();

    await tester.pumpWidget(
      MaterialApp(
        home: B2BPasswordResetScreen(
          initialPhone: '+905551112233',
          apiClient: api,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('SMS Kodu Gönder'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'SMS doğrulama kodu'),
      '123456',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Yeni kurumsal şifre'),
      'SelectedOrg!123',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Yeni kurumsal şifre tekrar'),
      'SelectedOrg!123',
    );

    await tester.tap(find.text('Şifreyi Yenile'));
    await tester.pumpAndSettle();

    expect(find.textContaining('CAMEX'), findsOneWidget);
    expect(find.textContaining('Bakırköy 221'), findsOneWidget);
    expect(
      find.textContaining(
        'Yalnızca seçtiğiniz kurumun şifresi değiştirilecektir.',
      ),
      findsOneWidget,
    );
    expect(api.selectedOrganizationId, isNull);

    await tester.tap(find.textContaining('CAMEX'));
    await tester.pumpAndSettle();

    expect(api.selectedOrganizationId, 'camex-org');
    expect(api.verifyCalls, 2);
  });
}

class _OperatorPortalApiClient extends B2BApiClient {
  @override
  Future<Map<String, dynamic>> get(String path) async {
    if (path == '/b2b/auth/me') {
      return {
        'member_id': 'operator-1',
        'organization_id': 'org-1',
        'organization_name': 'Operator Test Kurumu',
        'phone_number': '+905551112233',
        'role': 'operator',
      };
    }

    if (path == '/b2b/portal/credits') {
      return {
        'usable_credits': 3,
        'awaiting_activation_credits': 0,
      };
    }

    throw StateError('Unexpected GET $path');
  }
}

class _MultiOrgResetApiClient extends B2BApiClient {
  int verifyCalls = 0;
  String? selectedOrganizationId;

  @override
  Future<Map<String, dynamic>> postPublic(
    String path,
    Map<String, dynamic> body,
  ) async {
    if (path.endsWith('/start')) {
      return {
        'success': true,
        'challenge_id': 'reset-challenge',
        'expires_in_seconds': 180,
        'resend_available_in_seconds': 60,
        'code_length': 6,
        'provider': 'test',
      };
    }

    if (path.endsWith('/verify')) {
      verifyCalls += 1;
      selectedOrganizationId = body['organization_id']?.toString();

      if (selectedOrganizationId == null) {
        return {
          'success': true,
          'selection_required': true,
          'organizations': [
            {
              'organization_id': 'camex-org',
              'organization_name': 'CAMEX',
              'role': 'owner',
            },
            {
              'organization_id': 'bakirkoy-org',
              'organization_name': 'Bakırköy 221',
              'role': 'operator',
            },
          ],
        };
      }

      return {
        'success': true,
        'selection_required': false,
        'organizations': [],
        'organization_id': selectedOrganizationId,
        'organization_name': 'CAMEX',
      };
    }

    throw StateError('Unexpected POST $path');
  }
}
