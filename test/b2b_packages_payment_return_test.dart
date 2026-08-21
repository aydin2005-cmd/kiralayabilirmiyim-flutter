import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kiralayabilir_miyim/screens/b2b_packages_screen.dart';
import 'package:kiralayabilir_miyim/services/b2b_api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'pending payment storage survives client recreation and clears on logout',
    () async {
      FlutterSecureStorage.setMockInitialValues({});

      final first = B2BApiClient();

      await first.savePendingPaymentId(
        ' payment-1 ',
      );

      final second = B2BApiClient();

      expect(
        await second.readPendingPaymentId(),
        'payment-1',
      );

      await second.clearToken();

      expect(
        await second.readPendingPaymentId(),
        isNull,
      );
    },
  );

  testWidgets('checkout stores payment id and opens checkout URL',
      (tester) async {
    final api = _FakeB2BApiClient();
    final opened = <Uri>[];

    await tester.pumpWidget(_app(api: api, opened: opened));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Paketi Satın Al'));
    await tester.pumpAndSettle();

    expect(api.postPaths, ['/b2b/packages/checkout']);
    expect(api.postBodies.single, {'product_id': 'product-1'});
    expect(opened, [Uri.parse('https://paytr.example/checkout')]);
    expect(api.pendingPaymentId, 'payment-1');
    expect(find.text('Ödeme ID: payment-1'), findsOneWidget);
  });

  testWidgets('app resume with no payment id does not check backend',
      (tester) async {
    final api = _FakeB2BApiClient();

    await tester.pumpWidget(_app(api: api));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(api.getPaths, isEmpty);
  });

  testWidgets(
    'persisted payment restores after process restart and checks backend',
    (tester) async {
      final api = _FakeB2BApiClient(
        pendingPaymentId: 'payment-1',
        statusResponses: [_pendingStatus()],
      );

      await tester.pumpWidget(
        _app(
          api: api,
          autoRetryCount: 0,
        ),
      );

      await tester.pumpAndSettle();

      expect(
        api.getPaths,
        ['/b2b/packages/payments/payment-1'],
      );

      expect(
        find.text('Ödeme ID: payment-1'),
        findsOneWidget,
      );

      expect(
        api.pendingPaymentId,
        'payment-1',
      );
    },
  );

  testWidgets(
    'terminal restored payment clears recovery state',
    (tester) async {
      final api = _FakeB2BApiClient(
        pendingPaymentId: 'payment-1',
        statusResponses: [_activeStatus()],
      );

      await tester.pumpWidget(
        _app(
          api: api,
          autoRetryCount: 0,
        ),
      );

      await tester.pumpAndSettle();

      expect(
        api.getPaths,
        ['/b2b/packages/payments/payment-1'],
      );

      expect(
        api.pendingPaymentId,
        isNull,
      );

      expect(
        api.pendingPaymentClearCount,
        1,
      );

      expect(
        find.text(
          'Ödemeniz alındı. Paketiniz hesabınıza tanımlandı.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('app resume with pending payment checks backend', (tester) async {
    final api = _FakeB2BApiClient(
      statusResponses: [_pendingStatus()],
    );

    await tester.pumpWidget(_app(api: api, autoRetryCount: 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paketi Satın Al'));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(api.getPaths, ['/b2b/packages/payments/payment-1']);
  });

  testWidgets(
      'browser return alone never shows success before backend response',
      (tester) async {
    final completer = Completer<Map<String, dynamic>>();
    final api = _FakeB2BApiClient(statusCompleter: completer);

    await tester.pumpWidget(_app(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paketi Satın Al'));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(
      find.text('Ödemeniz alındı. Paketiniz hesabınıza tanımlandı.'),
      findsNothing,
    );

    completer.complete(_activeStatus());
    await tester.pumpAndSettle();

    expect(
      find.text('Ödemeniz alındı. Paketiniz hesabınıza tanımlandı.'),
      findsOneWidget,
    );
  });

  testWidgets('multiple resume signals do not start duplicate check loops',
      (tester) async {
    final completer = Completer<Map<String, dynamic>>();
    final api = _FakeB2BApiClient(statusCompleter: completer);

    await tester.pumpWidget(_app(api: api, autoRetryCount: 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paketi Satın Al'));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(api.getPaths, ['/b2b/packages/payments/payment-1']);

    completer.complete(_activeStatus());
    await tester.pumpAndSettle();
  });

  testWidgets('pending response does not show success UI', (tester) async {
    final api = _FakeB2BApiClient(
      statusResponses: [_pendingStatus()],
    );

    await tester.pumpWidget(_app(api: api, autoRetryCount: 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paketi Satın Al'));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(
      find.text(
          'Ödemeniz henüz doğrulanmadı. Biraz sonra tekrar kontrol edebilirsiniz.'),
      findsOneWidget,
    );
    expect(
      find.text('Ödemeniz alındı. Paketiniz hesabınıza tanımlandı.'),
      findsNothing,
    );
  });

  testWidgets('pending retries until active status shows success',
      (tester) async {
    final api = _FakeB2BApiClient(
      statusResponses: [
        _pendingStatus(),
        _pendingStatus(),
        _activeStatus(),
      ],
    );

    await tester.pumpWidget(_app(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paketi Satın Al'));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(api.getPaths, [
      '/b2b/packages/payments/payment-1',
      '/b2b/packages/payments/payment-1',
      '/b2b/packages/payments/payment-1',
    ]);
    expect(
      find.text('Ödemeniz alındı. Paketiniz hesabınıza tanımlandı.'),
      findsOneWidget,
    );
  });

  testWidgets('paid awaiting activation is not final success', (tester) async {
    final api = _FakeB2BApiClient(
      statusResponses: [_awaitingActivationStatus()],
    );

    await tester.pumpWidget(_app(api: api, autoRetryCount: 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paketi Satın Al'));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(
      find.text('Ödemeniz alındı. Paketiniz hesabınıza tanımlandı.'),
      findsNothing,
    );
    expect(
      find.text(
        'Ödemeniz alındı. Paketinizin hesabınıza tanımlanması tamamlanıyor. Biraz sonra tekrar kontrol edebilirsiniz.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('RiskMetriks yönetici'), findsNothing);
  });

  testWidgets('paid awaiting activation retries until active status',
      (tester) async {
    final api = _FakeB2BApiClient(
      statusResponses: [
        _awaitingActivationStatus(),
        _activeStatus(),
      ],
    );

    await tester.pumpWidget(_app(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paketi Satın Al'));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(api.getPaths, [
      '/b2b/packages/payments/payment-1',
      '/b2b/packages/payments/payment-1',
    ]);
    expect(
      find.text('Ödemeniz alındı. Paketiniz hesabınıza tanımlandı.'),
      findsOneWidget,
    );
  });

  for (final scenario in [
    (
      name: 'failed',
      status: _failedStatus(),
      message: 'Ödeme tamamlanamadı.',
    ),
    (
      name: 'cancelled',
      status: _cancelledStatus(),
      message: 'Ödeme işlemi iptal edildi.',
    ),
    (
      name: 'refunded',
      status: _refundedStatus(),
      message: 'Ödeme iade edildi.',
    ),
  ]) {
    testWidgets('${scenario.name} status shows friendly message',
        (tester) async {
      final api = _FakeB2BApiClient(
        statusResponses: [scenario.status],
      );

      await tester.pumpWidget(_app(api: api, autoRetryCount: 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paketi Satın Al'));
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text(scenario.message), findsOneWidget);
    });
  }

  testWidgets('manual status button still checks backend', (tester) async {
    final api = _FakeB2BApiClient(
      statusResponses: [_activeStatus()],
    );

    await tester.pumpWidget(_app(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paketi Satın Al'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ödeme Durumunu Kontrol Et'));
    await tester.pumpAndSettle();

    expect(api.getPaths, ['/b2b/packages/payments/payment-1']);
    expect(
      find.text('Ödemeniz alındı. Paketiniz hesabınıza tanımlandı.'),
      findsOneWidget,
    );
  });

  testWidgets('manual status during auto-check does not duplicate request',
      (tester) async {
    final completer = Completer<Map<String, dynamic>>();
    final api = _FakeB2BApiClient(statusCompleter: completer);

    await tester.pumpWidget(_app(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paketi Satın Al'));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.tap(find.text('Ödeme Durumunu Kontrol Et'));
    await tester.pump();

    expect(api.getPaths, ['/b2b/packages/payments/payment-1']);

    completer.complete(_activeStatus());
    await tester.pumpAndSettle();
  });

  testWidgets('dispose during delayed retry does not update disposed widget',
      (tester) async {
    final api = _FakeB2BApiClient(
      statusResponses: [
        _pendingStatus(),
        _activeStatus(),
      ],
    );

    await tester.pumpWidget(
      _app(
        api: api,
        retryDelay: const Duration(seconds: 1),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paketi Satın Al'));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump(const Duration(seconds: 2));

    expect(tester.takeException(), isNull);
  });

  test('portal keeps return-refresh hook for package screen', () {
    final source =
        File('lib/screens/b2b_portal_screen.dart').readAsStringSync();

    expect(source, contains('B2BPackagesScreen(canPurchase: canManage)'));
    expect(source, contains('.then((_) => load())'));
  });
}

Widget _app({
  required _FakeB2BApiClient api,
  List<Uri>? opened,
  int autoRetryCount = 4,
  Duration retryDelay = Duration.zero,
}) {
  return MaterialApp(
    home: B2BPackagesScreen(
      canPurchase: true,
      apiClient: api,
      autoRetryCount: autoRetryCount,
      retryDelay: retryDelay,
      checkoutLauncher: (uri) async {
        opened?.add(uri);
        return true;
      },
    ),
  );
}

Map<String, dynamic> _product() {
  return {
    'product_id': 'product-1',
    'name': 'Başlangıç Paketi',
    'description': 'Test paketi',
    'credit_count': 10,
    'price_amount': 100,
    'vat_amount': 20,
    'total_amount': 120,
    'currency': 'TRY',
    'validity_days': 120,
  };
}

Map<String, dynamic> _checkoutResponse() {
  return {
    'purchase_id': 'purchase-1',
    'payment_id': 'payment-1',
    'product_code': 'STARTER',
    'product_name': 'Başlangıç Paketi',
    'credit_count': 10,
    'net_amount': 100,
    'vat_rate': 20,
    'vat_amount': 20,
    'amount': 120,
    'currency': 'TRY',
    'validity_days': 120,
    'purchase_status': 'pending_payment',
    'payment_status': 'pending',
    'provider': 'paytr',
    'checkout_url': 'https://paytr.example/checkout',
    'reused': false,
  };
}

Map<String, dynamic> _pendingStatus() {
  return {
    ..._checkoutResponse(),
    'checkout_url': 'https://paytr.example/checkout',
  };
}

Map<String, dynamic> _activeStatus() {
  return {
    ..._checkoutResponse(),
    'payment_status': 'paid',
    'purchase_status': 'active',
    'activated_at': '2026-08-17T10:00:00Z',
  };
}

Map<String, dynamic> _awaitingActivationStatus() {
  return {
    ..._checkoutResponse(),
    'payment_status': 'paid',
    'purchase_status': 'awaiting_activation',
  };
}

Map<String, dynamic> _failedStatus() {
  return {
    ..._checkoutResponse(),
    'payment_status': 'failed',
    'purchase_status': 'cancelled',
  };
}

Map<String, dynamic> _cancelledStatus() {
  return {
    ..._checkoutResponse(),
    'payment_status': 'cancelled',
    'purchase_status': 'cancelled',
  };
}

Map<String, dynamic> _refundedStatus() {
  return {
    ..._checkoutResponse(),
    'payment_status': 'refunded',
    'purchase_status': 'refunded',
  };
}

class _FakeB2BApiClient extends B2BApiClient {
  final List<Map<String, dynamic>> statusResponses;
  final Completer<Map<String, dynamic>>? statusCompleter;

  String? pendingPaymentId;
  final pendingPaymentWrites = <String>[];
  int pendingPaymentClearCount = 0;

  final postPaths = <String>[];
  final postBodies = <Map<String, dynamic>>[];
  final getPaths = <String>[];

  _FakeB2BApiClient({
    this.statusResponses = const [],
    this.statusCompleter,
    this.pendingPaymentId,
  });

  @override
  Future<void> savePendingPaymentId(
    String paymentId,
  ) async {
    final normalized = paymentId.trim();

    pendingPaymentWrites.add(
      normalized,
    );

    pendingPaymentId = normalized.isEmpty ? null : normalized;
  }

  @override
  Future<String?> readPendingPaymentId() async {
    return pendingPaymentId;
  }

  @override
  Future<void> clearPendingPaymentId() async {
    pendingPaymentClearCount++;
    pendingPaymentId = null;
  }

  @override
  Future<List<Map<String, dynamic>>> getList(String path) async {
    expect(path, '/b2b/packages/products');
    return [_product()];
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    postPaths.add(path);
    postBodies.add(body);
    return _checkoutResponse();
  }

  @override
  Future<Map<String, dynamic>> get(String path) async {
    getPaths.add(path);
    if (statusCompleter != null) {
      return statusCompleter!.future;
    }

    if (statusResponses.isEmpty) {
      return _pendingStatus();
    }

    final index = getPaths.length - 1;
    if (index >= statusResponses.length) {
      return statusResponses.last;
    }

    return statusResponses[index];
  }
}
