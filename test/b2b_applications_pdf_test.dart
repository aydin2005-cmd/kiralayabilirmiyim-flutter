import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiralayabilir_miyim/screens/b2b_applications_screen.dart';
import 'package:kiralayabilir_miyim/services/b2b_api_client.dart';
import 'package:kiralayabilir_miyim/services/corporate_pdf_opener.dart';

void main() {
  testWidgets('eligible report shows corporate PDF button', (tester) async {
    await tester.pumpWidget(_appWith(rows: [_eligibleApplication()]));
    await tester.pumpAndSettle();

    expect(find.text('Sonuç Raporunu Görüntüle'), findsOneWidget);
    expect(find.textContaining('Mobil PDF görüntüleme'), findsNothing);
    expect(find.textContaining('Başvuru No'), findsOneWidget);
  });

  testWidgets('unavailable, negative, and pending reports do not show button',
      (tester) async {
    await tester.pumpWidget(
      _appWith(
        rows: [
          _eligibleApplication(
            id: 'negative-app',
            reportAvailable: false,
            evaluationCompleted: true,
            decision: 'Olumsuz',
            status: 'not_shareable',
          ),
          _eligibleApplication(
            id: 'pending-app',
            reportAvailable: false,
            evaluationCompleted: false,
            decision: null,
            status: 'analysis_pending',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sonuç Raporunu Görüntüle'), findsNothing);
  });

  testWidgets('tap fetches supplied endpoint and opens returned PDF bytes',
      (tester) async {
    final api = _FakeB2BApiClient(rows: [_eligibleApplication()]);
    final opener = _FakeCorporatePdfOpener();

    await tester.pumpWidget(_appWith(api: api, opener: opener));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sonuç Raporunu Görüntüle'));
    await tester.pumpAndSettle();

    expect(
        api.requestedBytePaths, ['/b2b/portal/applications/app-1/report.pdf']);
    expect(opener.openedApplicationIds, ['app-1']);
    expect(opener.openedBytes.single, _FakeB2BApiClient.pdfBytes);
  });

  testWidgets('duplicate tap while loading does not duplicate PDF request',
      (tester) async {
    final completer = Completer<Uint8List>();
    final api = _FakeB2BApiClient(
      rows: [_eligibleApplication()],
      bytesCompleter: completer,
    );
    final opener = _FakeCorporatePdfOpener();

    await tester.pumpWidget(_appWith(api: api, opener: opener));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sonuç Raporunu Görüntüle'));
    await tester.pump();
    await tester.tap(find.text('Rapor Açılıyor...'));
    await tester.pump();

    expect(
        api.requestedBytePaths, ['/b2b/portal/applications/app-1/report.pdf']);

    completer.complete(_FakeB2BApiClient.pdfBytes);
    await tester.pumpAndSettle();

    expect(opener.openedApplicationIds, ['app-1']);
  });

  testWidgets('expired report failure shows friendly Turkish message',
      (tester) async {
    final api = _FakeB2BApiClient(
      rows: [_eligibleApplication()],
      bytesError: const B2BApiException(
        'REPORT_NOT_AVAILABLE',
        statusCode: 404,
      ),
    );

    await tester.pumpWidget(
      _appWith(api: api, opener: _FakeCorporatePdfOpener()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sonuç Raporunu Görüntüle'));
    await tester.pumpAndSettle();

    expect(
      find.text('Sonuç raporu artık görüntülenebilir durumda değil.'),
      findsOneWidget,
    );
    expect(find.textContaining('REPORT_NOT_AVAILABLE'), findsNothing);
  });

  testWidgets('corporate PDF UI exposes no Findeks action or public URL',
      (tester) async {
    await tester.pumpWidget(_appWith(rows: [_eligibleApplication()]));
    await tester.pumpAndSettle();

    expect(find.textContaining('Findeks'), findsNothing);
    expect(find.textContaining('http'), findsNothing);
    expect(find.textContaining('token'), findsNothing);
  });
}

Widget _appWith({
  List<Map<String, dynamic>>? rows,
  _FakeB2BApiClient? api,
  _FakeCorporatePdfOpener? opener,
}) {
  return MaterialApp(
    home: B2BApplicationsScreen(
      apiClient: api ?? _FakeB2BApiClient(rows: rows ?? []),
      pdfOpener: opener ?? _FakeCorporatePdfOpener(),
    ),
  );
}

Map<String, dynamic> _eligibleApplication({
  String id = 'app-1',
  bool reportAvailable = true,
  bool evaluationCompleted = true,
  String? decision = 'Olumlu',
  String status = 'shareable',
}) {
  return {
    'application_id': id,
    'referral_label': 'Test Davet',
    'bound_at': '2026-08-15T12:00:00Z',
    'application_type': 'home_rental',
    'application_status': status,
    'evaluation_completed': evaluationCompleted,
    'decision': decision,
    'report_available': reportAvailable,
    'report_pdf_endpoint':
        reportAvailable ? '/b2b/portal/applications/$id/report.pdf' : null,
  };
}

class _FakeB2BApiClient extends B2BApiClient {
  static final pdfBytes = Uint8List.fromList('%PDF-1.4\nfake'.codeUnits);

  final List<Map<String, dynamic>> rows;
  final Completer<Uint8List>? bytesCompleter;
  final Object? bytesError;
  final requestedBytePaths = <String>[];

  _FakeB2BApiClient({
    required this.rows,
    this.bytesCompleter,
    this.bytesError,
  });

  @override
  Future<List<Map<String, dynamic>>> getList(String path) async {
    expect(path, '/b2b/portal/applications');
    return rows;
  }

  @override
  Future<Uint8List> getBytes(String path) async {
    requestedBytePaths.add(path);

    if (bytesError != null) throw bytesError!;
    if (bytesCompleter != null) return bytesCompleter!.future;

    return pdfBytes;
  }
}

class _FakeCorporatePdfOpener extends CorporatePdfOpener {
  final openedApplicationIds = <String>[];
  final openedBytes = <Uint8List>[];

  @override
  Future<String> open({
    required Uint8List bytes,
    required String applicationId,
  }) async {
    openedApplicationIds.add(applicationId);
    openedBytes.add(bytes);
    return 'temp/$applicationId.pdf';
  }
}
