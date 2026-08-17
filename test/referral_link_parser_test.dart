import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiralayabilir_miyim/services/referral_link_parser.dart';

void main() {
  test('valid HTTPS referral URL returns token', () {
    expect(
      b2bReferralTokenFromUri(
        Uri.parse('https://kiralayabilirmiyim.com/basvuru/abc123'),
      ),
      'abc123',
    );
  });

  test('valid custom scheme referral returns token', () {
    expect(
      b2bReferralTokenFromUri(
        Uri.parse('kiralayabilirmiyim://b2b-referral?token=abc123'),
      ),
      'abc123',
    );
  });

  test('missing HTTPS token is rejected', () {
    expect(
      b2bReferralTokenFromUri(
        Uri.parse('https://kiralayabilirmiyim.com/basvuru/'),
      ),
      isNull,
    );
  });

  test('HTTPS referral path without token is rejected', () {
    expect(
      b2bReferralTokenFromUri(
        Uri.parse('https://kiralayabilirmiyim.com/basvuru'),
      ),
      isNull,
    );
  });

  test('HTTP referral URL is rejected', () {
    expect(
      b2bReferralTokenFromUri(
        Uri.parse('http://kiralayabilirmiyim.com/basvuru/token123'),
      ),
      isNull,
    );
  });

  test('similar HTTPS path is rejected', () {
    expect(
      b2bReferralTokenFromUri(
        Uri.parse('https://kiralayabilirmiyim.com/basvuruXYZ/token123'),
      ),
      isNull,
    );
  });

  test('uppercase HTTPS host returns token', () {
    expect(
      b2bReferralTokenFromUri(
        Uri.parse('https://KIRALAYABILIRMIYIM.COM/basvuru/token123'),
      ),
      'token123',
    );
  });

  test('wrong host is rejected', () {
    expect(
      b2bReferralTokenFromUri(
        Uri.parse('https://example.com/basvuru/abc123'),
      ),
      isNull,
    );
  });

  test('wrong path is rejected', () {
    expect(
      b2bReferralTokenFromUri(
        Uri.parse('https://kiralayabilirmiyim.com/davet/abc123'),
      ),
      isNull,
    );
  });

  test('payment-result URI is not treated as a referral', () {
    expect(
      b2bReferralTokenFromUri(
        Uri.parse(
          'kiralayabilirmiyim://payment-result?application_id=app-1',
        ),
      ),
      isNull,
    );
  });

  test('mobile App Link and Universal Link config is present', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final entitlements = File(
      'ios/Runner/Runner.entitlements',
    ).readAsStringSync();

    expect(manifest, contains('android:autoVerify="true"'));
    expect(manifest, contains('android:scheme="https"'));
    expect(manifest, contains('android:host="kiralayabilirmiyim.com"'));
    expect(manifest, contains('android:pathPrefix="/basvuru/"'));
    expect(manifest, contains('android:host="payment-result"'));
    expect(manifest, contains('android:host="b2b-referral"'));
    expect(entitlements, contains('webcredentials:kiralayabilirmiyim.com'));
    expect(entitlements, contains('applinks:kiralayabilirmiyim.com'));
  });
}
