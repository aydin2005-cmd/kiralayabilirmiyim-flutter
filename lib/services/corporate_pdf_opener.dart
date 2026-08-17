import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class CorporatePdfOpenException implements Exception {
  final String message;

  const CorporatePdfOpenException(this.message);

  @override
  String toString() => message;
}

class CorporatePdfOpener {
  const CorporatePdfOpener();

  Future<String> open({
    required Uint8List bytes,
    required String applicationId,
  }) async {
    if (bytes.isEmpty || !_looksLikePdf(bytes)) {
      throw const CorporatePdfOpenException(
        'Rapor dosyası geçerli görünmüyor. Lütfen tekrar deneyin.',
      );
    }

    final directory = await getTemporaryDirectory();
    final safeId = _safeFilePart(applicationId);
    final file = File(
      '${directory.path}${Platform.pathSeparator}'
      'kiralayabilir_miyim_sonuc_$safeId.pdf',
    );

    await file.writeAsBytes(bytes, flush: true);

    final result = await OpenFilex.open(
      file.path,
      type: 'application/pdf',
    );

    if (result.type != ResultType.done) {
      throw const CorporatePdfOpenException(
        'PDF görüntüleyici açılamadı. Lütfen cihazınızda PDF açabilen bir uygulama olduğundan emin olun.',
      );
    }

    return file.path;
  }

  bool _looksLikePdf(Uint8List bytes) {
    if (bytes.length < 5) return false;

    return bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46 &&
        bytes[4] == 0x2D;
  }

  String _safeFilePart(String value) {
    final normalized = value.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    final trimmed = normalized.replaceAll(RegExp(r'_+'), '_');

    if (trimmed.isEmpty) return 'rapor';
    if (trimmed.length <= 80) return trimmed;

    return trimmed.substring(0, 80);
  }
}
