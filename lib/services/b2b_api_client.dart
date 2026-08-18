import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'api_client.dart';

class B2BApiClient {
  static const String baseUrl = ApiClient.baseUrl;

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'b2b_access_token';

  final http.Client _httpClient;

  B2BApiClient({
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
    } on PlatformException {
      await clearToken();
      await _storage.write(key: _tokenKey, value: token);
    }
  }

  Future<String?> getToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } on PlatformException {
      return null;
    }
  }

  Future<void> clearToken() async {
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {
      // B2B token cleanup is best effort and intentionally does not
      // delete the candidate application's separate access token.
    }
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
    final response = await _httpClient.post(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
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
    required String billingAddress,
    required String ownerPhone,
  }) {
    return postPublic(
      '/b2b/onboarding/register',
      {
        'legal_name': legalName,
        'tax_number': taxNumber,
        'billing_address': billingAddress,
        'owner_phone': ownerPhone,
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
