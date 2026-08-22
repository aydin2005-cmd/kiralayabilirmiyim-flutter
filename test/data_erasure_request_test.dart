import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiralayabilir_miyim/screens/data_erasure_request_screen.dart';
import 'package:kiralayabilir_miyim/screens/splash_screen.dart';
import 'package:kiralayabilir_miyim/services/api_client.dart';

void main() {
  testWidgets('splash exposes data erasure request entry', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey('data-erasure-request-entry'),
      ),
      findsOneWidget,
    );
    expect(
      find.text('Veri Silme Talebi'),
      findsOneWidget,
    );
  });

  testWidgets(
    'data erasure request verifies phone without deleting data',
    (tester) async {
      final api = _DataErasureApiClient();

      await tester.pumpWidget(
        MaterialApp(
          home: DataErasureRequestScreen(
            apiClient: api,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(
          const ValueKey('data-erasure-phone-field'),
        ),
        '5551112233',
      );

      await tester.tap(
        find.text('SMS Kodu Gönder'),
      );
      await tester.pumpAndSettle();

      expect(api.calls, hasLength(1));
      expect(
        api.calls[0].path,
        '/auth/data-erasure/start',
      );
      expect(
        api.calls[0].body,
        {
          'phone_number': '+905551112233',
        },
      );

      expect(
        find.byKey(
          const ValueKey('data-erasure-phone-field'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey('data-erasure-otp-field'),
        ),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(
          const ValueKey('data-erasure-otp-field'),
        ),
        '123456',
      );

      await tester.tap(
        find.text('Talebi Doğrula'),
      );
      await tester.pumpAndSettle();

      expect(api.calls, hasLength(2));
      expect(
        api.calls[1].path,
        '/auth/data-erasure/verify',
      );
      expect(
        api.calls[1].body,
        {
          'challenge_id': 'erase-challenge',
          'code': '123456',
        },
      );

      expect(
        find.text('Talebiniz doğrulandı'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'bu aşamada hiçbir veri silinmez',
        ),
        findsNothing,
      );
      expect(
        find.textContaining(
          'sistemimizde size ait bir kayıt bulunup bulunmadığı',
        ),
        findsOneWidget,
      );
    },
  );
}

class _DataErasureCall {
  final String path;
  final Map<String, dynamic> body;

  const _DataErasureCall(
    this.path,
    this.body,
  );
}

class _DataErasureApiClient extends ApiClient {
  final List<_DataErasureCall> calls = [];

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    calls.add(
      _DataErasureCall(
        path,
        Map<String, dynamic>.from(body),
      ),
    );

    if (path == '/auth/data-erasure/start') {
      return {
        'success': true,
        'message': 'Doğrulama kodu gönderildi',
        'phone_number': '+905551112233',
        'challenge_id': 'erase-challenge',
        'expires_in_seconds': 180,
        'resend_available_in_seconds': 60,
        'code_length': 6,
        'provider': 'test',
      };
    }

    if (path == '/auth/data-erasure/verify') {
      return {
        'success': true,
        'message':
            'Veri silme talebiniz için telefon doğrulaması tamamlandı.',
      };
    }

    throw ApiException('Unexpected path: $path');
  }
}
