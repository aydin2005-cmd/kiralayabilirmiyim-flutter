import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  // Real Android phone default for current local test environment.
  // Change with --dart-define=API_BASE_URL=... if your computer IP changes.
  // Emulator alternative: --dart-define=API_BASE_URL=http://10.0.2.2:8000
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.kiralayabilirmiyim.com',
  );

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'access_token';

  Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
    } on PlatformException {
      await _resetSecureStorage();
      await _storage.write(key: _tokenKey, value: token);
    }
  }

  Future<String?> getToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } on PlatformException {
      await _resetSecureStorage();
      return null;
    }
  }

  Future<void> clearToken() async {
    try {
      await _storage.delete(key: _tokenKey);
    } on PlatformException {
      await _resetSecureStorage();
    }
  }

  Future<void> _resetSecureStorage() async {
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {
      // Best effort cleanup.
    }

    try {
      await _storage.deleteAll();
    } catch (_) {
      // Best effort cleanup.
    }
  }

  Future<Map<String, String>> _headers() async {
    final headers = {'Content-Type': 'application/json; charset=utf-8'};
    final token = await getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> post(
      String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final response =
        await http.post(uri, headers: await _headers(), body: jsonEncode(body));
    return _decode(response);
  }

  Future<Map<String, dynamic>> patch(
      String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await http.patch(uri,
        headers: await _headers(), body: jsonEncode(body));
    return _decode(response);
  }

  Future<Map<String, dynamic>> get(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await http.get(uri, headers: await _headers());
    return _decode(response);
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await http.delete(uri, headers: await _headers());
    return _decode(response);
  }

  Future<Map<String, dynamic>> uploadPdf(
      String path, File file, String applicationId) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = http.MultipartRequest('POST', uri);

    final token = await getToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields['application_id'] = applicationId;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final body = response.body.isEmpty ? '{}' : response.body;

    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      throw ApiException(
          'İşleminiz şu anda tamamlanamadı. Lütfen daha sonra tekrar deneyin.');
    }

    final map = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'data': decoded};

    if (response.statusCode >= 400) {
      final detail = map['detail'];
      if (detail is String && detail.isNotEmpty) {
        throw ApiException(detail);
      }
      throw ApiException(
          'İşleminiz şu anda tamamlanamadı. Lütfen daha sonra tekrar deneyin.');
    }

    return map;
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}
