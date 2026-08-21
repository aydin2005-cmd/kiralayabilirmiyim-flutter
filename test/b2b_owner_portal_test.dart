import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiralayabilir_miyim/services/b2b_helpers.dart';

void main() {
  test('normalizes Turkish mobile phone', () {
    expect(normalizeTurkeyMobile('0507 182 33 99'), '+905071823399');
    expect(normalizeTurkeyMobile('+90 507 182 33 99'), '+905071823399');
    expect(normalizeTurkeyMobile('5071823399'), '+905071823399');
    expect(normalizeTurkeyMobile('2121234567'), isNull);
  });

  test('owner portal source uses separate B2B token client', () {
    final client = File('lib/services/b2b_api_client.dart').readAsStringSync();
    final splash = File('lib/screens/splash_screen.dart').readAsStringSync();

    expect(client, contains("static const _tokenKey = 'b2b_access_token'"));
    expect(client, isNot(contains("static const _tokenKey = 'access_token'")));
    expect(splash, contains('B2BEntryScreen'));

    expect(
      splash,
      contains('ElevatedButton.icon'),
    );
    expect(
      splash,
      contains(
        'backgroundColor: FlowColors.navy',
      ),
    );
    expect(
      splash,
      contains(
        'foregroundColor: Colors.white',
      ),
    );
    expect(
      splash,
      contains(
        'minimumSize: const Size.fromHeight(56)',
      ),
    );
    expect(
      splash,
      contains('fontSize: 17'),
    );
    expect(
      splash,
      contains(
        'fontWeight: FontWeight.w900',
      ),
    );
    expect(
      splash,
      contains('size: 22'),
    );
    expect(splash, contains('Kurumsal Giriş'));
  });

  test('owner portal contains required backend flows', () {
    final root = Directory('lib/screens');
    final source = root
        .listSync()
        .whereType<File>()
        .where((file) => file.path.contains('b2b_'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(source, contains('/b2b/auth/activate/start'));
    expect(source, contains('/b2b/auth/activate/verify'));
    expect(source, contains('/b2b/auth/login/start'));
    expect(source, contains('/b2b/auth/login/verify'));
    expect(source, contains('/b2b/portal/credits'));
    expect(source, contains('/b2b/packages/checkout'));
    expect(source, contains('/b2b/members/invite'));
    expect(source, contains('/b2b/portal/referral-links'));
    expect(source, contains('/b2b/portal/applications'));
  });

  test('B2B OTP screens use Retriever, one-time-code, and shared coordinator',
      () {
    final login = File('lib/screens/b2b_login_screen.dart').readAsStringSync();
    final activation =
        File('lib/screens/b2b_activation_screen.dart').readAsStringSync();

    for (final source in [login, activation]) {
      expect(source, contains('SmsRetrieverService.instance.start()'));
      expect(source, contains('OtpAutofillCoordinator'));
      expect(source, contains('AutofillHints.oneTimeCode'));
      expect(source, contains('otpAutofill.handleCodeChanged'));
      expect(source, contains('TextInput.finishAutofillContext'));
    }
  });

  test('individual OTP Retriever behavior remains wired', () {
    final login = File('lib/screens/login_screen.dart').readAsStringSync();
    final otp = File('lib/screens/otp_screen.dart').readAsStringSync();

    expect(login, contains('SmsRetrieverService.instance.start()'));
    expect(login.indexOf('SmsRetrieverService.instance.start()'),
        lessThan(login.indexOf("api.post('/auth/otp/start'")));
    expect(otp, contains('SmsRetrieverService.extractCode'));
    expect(otp, contains('AutofillHints.oneTimeCode'));
    expect(otp, contains('await verify()'));
  });
}
