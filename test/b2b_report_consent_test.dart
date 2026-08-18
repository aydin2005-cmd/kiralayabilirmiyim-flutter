import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiralayabilir_miyim/models/application_type.dart';
import 'package:kiralayabilir_miyim/screens/b2b_report_consent_screen.dart';
import 'package:kiralayabilir_miyim/services/app_state.dart';

void main() {
  tearDown(() {
    AppState.instance.clearB2BReferralContext();
    AppState.instance.resetApplicationFlow();
  });

  testWidgets('report consent keeps organization-specific wording visible',
      (tester) async {
    AppState.instance.applicationId = 'app-123';
    AppState.instance.configureB2BReferral(
      referralToken: 'ref-token',
      organizationName: 'RiskMetriks Kurumsal',
      consentTextVersion: 'b2b-result-report-share-v1-2026-08-15',
      consentText:
          'Sonuç Raporumun RiskMetriks Kurumsal ile paylaşılmasına açık rıza veriyorum.',
    );
    AppState.instance.selectB2BCorporateFlow();

    await tester.pumpWidget(
      const MaterialApp(
        home: B2BReportConsentScreen(
          applicationType: ApplicationType.homeRental,
        ),
      ),
    );

    expect(find.text('Sonuç Raporu Paylaşımı'), findsOneWidget);
    expect(find.textContaining('RiskMetriks Kurumsal'), findsWidgets);
    expect(
      find.textContaining(
        'ham Findeks Risk Raporu kuruma paylaşılmaz',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('revoke'), findsNothing);
    expect(find.textContaining('Ödeme'), findsNothing);
  });

  test('report consent request contract remains unchanged', () {
    final source =
        File('lib/screens/b2b_report_consent_screen.dart').readAsStringSync();

    expect(source, contains("'/b2b/referrals/"));
    expect(source, contains("'application_id': applicationId"));
    expect(source, contains("'report_share_consent': true"));
    expect(source, contains("'consent_text_version': consentVersion"));
    expect(source, isNot(contains('revoked_at')));
    expect(source, isNot(contains('PaymentFlow')));
  });
}
