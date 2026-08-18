import 'dart:async';
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
import 'package:kiralayabilir_miyim/services/b2b_helpers.dart';
import 'package:kiralayabilir_miyim/widgets/primary_button.dart';

const _smsRetrieverChannel = MethodChannel(
  'com.riskmetriks.kiralayabilirmiyim/sms_retriever',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_smsRetrieverChannel, (call) async {
      switch (call.method) {
        case 'startSmsRetriever':
          return true;
        case 'stopSmsRetriever':
          return true;
      }

      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_smsRetrieverChannel, null);
  });

  group('B2BApiException retry-after', () {
    test('parses positive integer retry-after headers', () async {
      final first = await _captureException('45');
      final second = await _captureException('120');

      expect(first.statusCode, 429);
      expect(first.message, 'Çok fazla deneme yapıldı.');
      expect(first.retryAfterSeconds, 45);
      expect(second.retryAfterSeconds, 120);
    });

    test('ignores missing, malformed, zero and negative retry-after headers',
        () async {
      expect((await _captureException(null)).retryAfterSeconds, isNull);
      expect((await _captureException('soon')).retryAfterSeconds, isNull);
      expect((await _captureException('0')).retryAfterSeconds, isNull);
      expect((await _captureException('-10')).retryAfterSeconds, isNull);
    });

    test('preserves existing non-429 status and detail behavior', () async {
      final api = B2BApiClient(
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({'detail': 'Kurumsal oturum bulunamadı.'}),
            401,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      try {
        await api.get('/b2b/portal/me');
        fail('Expected B2BApiException');
      } on B2BApiException catch (error) {
        expect(error.statusCode, 401);
        expect(error.message, 'Kurumsal oturum bulunamadı.');
        expect(error.retryAfterSeconds, isNull);
      }
    });
  });

  test('formatRetryAfterHint uses conservative rounded units', () {
    expect(
      formatRetryAfterHint(1),
      'Yaklaşık 1 saniye sonra tekrar deneyebilirsiniz.',
    );
    expect(
      formatRetryAfterHint(45),
      'Yaklaşık 45 saniye sonra tekrar deneyebilirsiniz.',
    );
    expect(
      formatRetryAfterHint(59),
      'Yaklaşık 59 saniye sonra tekrar deneyebilirsiniz.',
    );
    expect(
      formatRetryAfterHint(60),
      'Yaklaşık 1 dakika sonra tekrar deneyebilirsiniz.',
    );
    expect(
      formatRetryAfterHint(61),
      'Yaklaşık 2 dakika sonra tekrar deneyebilirsiniz.',
    );
    expect(
      formatRetryAfterHint(3599),
      'Yaklaşık 60 dakika sonra tekrar deneyebilirsiniz.',
    );
    expect(
      formatRetryAfterHint(3600),
      'Yaklaşık 1 saat sonra tekrar deneyebilirsiniz.',
    );
    expect(
      formatRetryAfterHint(3601),
      'Yaklaşık 2 saat sonra tekrar deneyebilirsiniz.',
    );
    expect(formatRetryAfterHint(0), isNull);
    expect(formatRetryAfterHint(-1), isNull);
  });

  testWidgets('activation OTP start 429 shows SMS message and keeps screen',
      (tester) async {
    final api = _FakeOtpApiClient(
      startError: const B2BApiException(
        'Çok fazla SMS kodu istendi. Lütfen daha sonra tekrar deneyin.',
        statusCode: 429,
        retryAfterSeconds: 45,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: B2BActivationScreen(apiClient: api),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Yetkili cep telefonu'),
      '5551112233',
    );
    _pressButton(tester, 'Aktivasyon Kodu Gönder');
    await _pumpAsyncUi(tester);

    expect(api.postPaths, ['/b2b/auth/activate/start']);
    expect(find.byType(B2BActivationScreen), findsOneWidget);
    expect(find.textContaining('Çok fazla SMS kodu istendi.'), findsOneWidget);
    expect(find.textContaining('Yaklaşık 45 saniye'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'SMS doğrulama kodu'), findsNothing);
    expect(find.text('5551112233'), findsOneWidget);
  });

  testWidgets('activation duplicate tap sends only one OTP start request',
      (tester) async {
    final completer = Completer<Map<String, dynamic>>();
    final api = _FakeOtpApiClient(startCompleter: completer);

    await tester.pumpWidget(
      MaterialApp(
        home: B2BActivationScreen(apiClient: api),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Yetkili cep telefonu'),
      '5551112233',
    );

    _pressButton(tester, 'Aktivasyon Kodu Gönder');
    _pressButton(tester, 'Aktivasyon Kodu Gönder');
    await _pumpAsyncUi(tester);

    expect(api.postPaths, ['/b2b/auth/activate/start']);

    completer.complete(_challenge('activation-challenge'));
    await _pumpAsyncUi(tester);
  });

  testWidgets('activation manual verify path remains available after challenge',
      (tester) async {
    final api = _FakeOtpApiClient(
      startResponse: _challenge('activation-challenge'),
      verifyResponse: const {},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: B2BActivationScreen(apiClient: api),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Yetkili cep telefonu'),
      '5551112233',
    );
    _pressButton(tester, 'Aktivasyon Kodu Gönder');
    await _pumpAsyncUi(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'SMS doğrulama kodu'),
      '123456',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Yeni kurumsal şifre'),
      'SecretPass1',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Şifre tekrar'),
      'SecretPass1',
    );
    _pressButton(tester, 'Aktivasyonu Tamamla');
    await _pumpAsyncUi(tester);

    expect(api.postPaths, [
      '/b2b/auth/activate/start',
      '/b2b/auth/activate/verify',
    ]);
  });

  testWidgets('login OTP start 429 shows SMS message and keeps credentials',
      (tester) async {
    final api = _FakeOtpApiClient(
      startError: const B2BApiException(
        'Çok fazla SMS kodu istendi. Lütfen daha sonra tekrar deneyin.',
        statusCode: 429,
        retryAfterSeconds: 3601,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: B2BLoginScreen(apiClient: api),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Yetkili cep telefonu'),
      '+90 555 111 22 33',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Kurumsal şifre'),
      'SecretPass1',
    );
    _pressButton(tester, 'Giriş Kodu Gönder');
    await _pumpAsyncUi(tester);

    expect(api.postPaths, ['/b2b/auth/login/start']);
    expect(find.byType(B2BLoginScreen), findsOneWidget);
    expect(find.textContaining('Çok fazla SMS kodu istendi.'), findsOneWidget);
    expect(find.textContaining('Yaklaşık 2 saat'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'SMS doğrulama kodu'), findsNothing);
    expect(find.text('+90 555 111 22 33'), findsOneWidget);
    expect(find.text('SecretPass1'), findsOneWidget);
  });

  testWidgets('login duplicate tap sends only one OTP start request',
      (tester) async {
    final completer = Completer<Map<String, dynamic>>();
    final api = _FakeOtpApiClient(startCompleter: completer);

    await tester.pumpWidget(
      MaterialApp(
        home: B2BLoginScreen(apiClient: api),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Yetkili cep telefonu'),
      '5551112233',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Kurumsal şifre'),
      'SecretPass1',
    );

    _pressButton(tester, 'Giriş Kodu Gönder');
    _pressButton(tester, 'Giriş Kodu Gönder');
    await _pumpAsyncUi(tester);

    expect(api.postPaths, ['/b2b/auth/login/start']);

    completer.complete(_challenge('login-challenge'));
    await _pumpAsyncUi(tester);
  });

  testWidgets('login verify and success path remain unchanged', (tester) async {
    final api = _FakeOtpApiClient(
      startResponse: _challenge('login-challenge'),
      verifyResponse: {'access_token': 'b2b-session'},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: B2BLoginScreen(apiClient: api),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Yetkili cep telefonu'),
      '5551112233',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Kurumsal şifre'),
      'SecretPass1',
    );
    _pressButton(tester, 'Giriş Kodu Gönder');
    await _pumpAsyncUi(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'SMS doğrulama kodu'),
      '123456',
    );
    await _pumpAsyncUi(tester);

    expect(api.postPaths, [
      '/b2b/auth/login/start',
      '/b2b/auth/login/verify',
    ]);
    expect(api.savedTokens, ['b2b-session']);
  });
}

Future<void> _pumpAsyncUi(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  });
  await tester.pump(const Duration(milliseconds: 500));
}

void _pressButton(WidgetTester tester, String text) {
  tester
      .widget<PrimaryButton>(find.widgetWithText(PrimaryButton, text))
      .onPressed!();
}

Future<B2BApiException> _captureException(String? retryAfter) async {
  final api = B2BApiClient(
    httpClient: MockClient((request) async {
      return http.Response(
        jsonEncode({'detail': 'Çok fazla deneme yapıldı.'}),
        429,
        headers: {
          'content-type': 'application/json; charset=utf-8',
          if (retryAfter != null) 'Retry-After': retryAfter,
        },
      );
    }),
  );

  try {
    await api.postPublic('/b2b/onboarding/register', const {});
    fail('Expected B2BApiException');
  } on B2BApiException catch (error) {
    return error;
  }
}

Map<String, dynamic> _challenge(String id) {
  return {
    'challenge_id': id,
    'expires_in_seconds': 180,
    'resend_available_in_seconds': 60,
    'code_length': 6,
    'provider': 'test',
  };
}

class _FakeOtpApiClient extends B2BApiClient {
  final Object? startError;
  final Completer<Map<String, dynamic>>? startCompleter;
  final Map<String, dynamic> startResponse;
  final Map<String, dynamic> verifyResponse;

  final postPaths = <String>[];
  final savedTokens = <String>[];

  _FakeOtpApiClient({
    this.startError,
    this.startCompleter,
    Map<String, dynamic>? startResponse,
    Map<String, dynamic>? verifyResponse,
  })  : startResponse = startResponse ?? _challenge('challenge-1'),
        verifyResponse = verifyResponse ?? const {};

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    postPaths.add(path);

    if (path.endsWith('/start') && startError != null) {
      throw startError!;
    }

    if (path.endsWith('/start')) {
      if (startCompleter != null) {
        return startCompleter!.future;
      }

      return startResponse;
    }

    return verifyResponse;
  }

  @override
  Future<void> saveToken(String token) async {
    savedTokens.add(token);
  }
}
