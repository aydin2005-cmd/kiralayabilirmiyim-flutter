import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'api_client.dart';

class B2BApiClient {
  static const String baseUrl = ApiClient.baseUrl;
  static const b2bPrivacyNoticeVersion =
      'b2b-privacy-notice-acknowledgement-v1-2026-08-18';
  static const b2bTermsVersion = 'b2b-terms-acceptance-v1-2026-08-18';

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'b2b_access_token';
  static const _pendingPaymentKey = 'b2b_pending_payment_id';

  // A B2B login is intentionally process-scoped. Server-side session TTL and
  // revocation remain authoritative, but an app process restart must require a
  // fresh corporate login/OTP instead of silently restoring a bearer token.
  static String? _runtimeToken;

  final http.Client _httpClient;

  B2BApiClient({
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  Future<void> saveToken(String token) async {
    final normalized = token.trim();
    _runtimeToken = normalized.isEmpty ? null : normalized;

    // Remove tokens persisted by older app versions. Failure is best-effort;
    // the current process never reads the legacy secure-storage token.
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {
      // Runtime-only B2B authentication remains effective for this process.
    }
  }

  Future<String?> getToken() async {
    return _runtimeToken;
  }

  Future<void> savePendingPaymentId(
    String paymentId,
  ) async {
    final normalized = paymentId.trim();

    if (normalized.isEmpty) {
      await clearPendingPaymentId();
      return;
    }

    try {
      await _storage.write(
        key: _pendingPaymentKey,
        value: normalized,
      );
    } catch (_) {
      // Payment recovery persistence is best effort.
      // Backend payment state remains authoritative.
    }
  }

  Future<String?> readPendingPaymentId() async {
    try {
      final value = await _storage.read(
        key: _pendingPaymentKey,
      );

      final normalized = value?.trim();

      if (normalized == null || normalized.isEmpty) {
        return null;
      }

      return normalized;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearPendingPaymentId() async {
    try {
      await _storage.delete(
        key: _pendingPaymentKey,
      );
    } catch (_) {
      // Best-effort cleanup only.
    }
  }

  Future<void> clearToken() async {
    _runtimeToken = null;

    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {
      // B2B session cleanup is best effort and intentionally does not
      // delete the candidate application's separate access token.
    }

    await clearPendingPaymentId();
  }

  Future<Map<String, String>> _headers({
    bool includeAuth = true,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
    };

    if (includeAuth) {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final requestBody = Map<String, dynamic>.from(body);

    // A deliberate package purchase tap supersedes only the exact pending
    // payment this app previously adopted. With no persisted pending payment,
    // normal backend checkout/reuse behavior remains unchanged.
    if (path == '/b2b/packages/checkout' &&
        !requestBody.containsKey('replace_pending')) {
      final pendingPaymentId = await readPendingPaymentId();

      if (pendingPaymentId != null && pendingPaymentId.isNotEmpty) {
        requestBody['replace_pending'] = true;
        requestBody['replace_pending_payment_id'] = pendingPaymentId;
      }
    }

    final response = await _httpClient.post(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(requestBody),
    );
    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> postPublic(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _httpClient.post(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(includeAuth: false),
      body: jsonEncode(body),
    );
    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> registerSelfService({
    required String legalName,
    required String taxNumber,
    required String taxOffice,
    required String billingAddress,
    required String contactEmail,
    required String ownerPhone,
    required bool privacyNoticeAcknowledged,
    required String privacyNoticeVersion,
    required bool termsAccepted,
    required String termsVersion,
  }) {
    return postPublic(
      '/b2b/onboarding/register',
      {
        'legal_name': legalName,
        'tax_number': taxNumber,
        'tax_office': taxOffice,
        'billing_address': billingAddress,
        'contact_email': contactEmail,
        'owner_phone': ownerPhone,
        'privacy_notice_acknowledged': privacyNoticeAcknowledged,
        'privacy_notice_version': privacyNoticeVersion,
        'terms_accepted': termsAccepted,
        'terms_version': termsVersion,
      },
    );
  }

  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _httpClient.patch(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> get(String path) async {
    final response = await _httpClient.get(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
    );
    return _decodeMap(response);
  }

  Future<List<Map<String, dynamic>>> getList(String path) async {
    final response = await _httpClient.get(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
    );

    final decoded = _decodeAny(response);
    if (decoded is! List) {
      throw const B2BApiException('Beklenen kurumsal liste yanıtı alınamadı.');
    }

    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<Uint8List> getBytes(String path) async {
    final response = await _httpClient.get(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
    );

    if (response.statusCode >= 400) {
      _throwError(response);
    }

    return response.bodyBytes;
  }

  dynamic _decodeAny(http.Response response) {
    if (response.statusCode >= 400) {
      _throwError(response);
    }

    if (response.body.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      return jsonDecode(response.body);
    } catch (_) {
      throw const B2BApiException(
        'Kurumsal işlem yanıtı okunamadı. Lütfen tekrar deneyin.',
      );
    }
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    final decoded = _decodeAny(response);

    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    throw const B2BApiException('Beklenen kurumsal yanıt alınamadı.');
  }

  Never _throwError(http.Response response) {
    String message =
        'Kurumsal işlem şu anda tamamlanamadı. Lütfen tekrar deneyin.';

    try {
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);

      if (decoded is Map) {
        final detail = decoded['detail'];

        if (detail is String && detail.trim().isNotEmpty) {
          message = detail.trim();
        } else if (detail is Map) {
          final detailMessage = detail['message'];
          if (detailMessage is String && detailMessage.trim().isNotEmpty) {
            message = detailMessage.trim();
          }
        }
      }
    } catch (_) {
      // Keep the generic user-facing error.
    }

    throw B2BApiException(
      message,
      statusCode: response.statusCode,
      retryAfterSeconds: _retryAfterSeconds(response),
    );
  }

  int? _retryAfterSeconds(http.Response response) {
    String? value;

    for (final entry in response.headers.entries) {
      if (entry.key.toLowerCase() == 'retry-after') {
        value = entry.value;
        break;
      }
    }

    final parsed = int.tryParse((value ?? '').trim());
    if (parsed == null || parsed <= 0) {
      return null;
    }

    return parsed;
  }
}

class B2BApiException implements Exception {
  final String message;
  final int? statusCode;
  final int? retryAfterSeconds;

  const B2BApiException(
    this.message, {
    this.statusCode,
    this.retryAfterSeconds,
  });

  @override
  String toString() => message;
}
