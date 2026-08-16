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
}
