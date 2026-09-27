import 'dart:convert';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../utils/app_constants.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();
  final http.Client _client = http.Client();
  static const _timeout = Duration(seconds: 30);

  Future<Map<String, String>> _headers() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      headers['Authorization'] = 'Bearer ${await user.getIdToken()}';
    }

    if (!AppConstants.disableAppCheck) {
      try {
        final appCheckToken = await FirebaseAppCheck.instance.getToken();
        if (appCheckToken != null && appCheckToken.isNotEmpty) {
          headers['X-Firebase-AppCheck'] = appCheckToken;
        }
      } catch (_) {
        // App Check unavailable.
      }
    }

    return headers;
  }

  Future<dynamic> get(String path) => _request('GET', path);

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) =>
      _request('POST', path, body: body);

  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) =>
      _request('PATCH', path, body: body);

  Future<dynamic> delete(String path) => _request('DELETE', path);

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('${AppConstants.apiBaseUrl}$path');
    final headers = await _headers();

    final response = switch (method) {
      'GET' => await _client.get(uri, headers: headers).timeout(_timeout),
      'POST' =>
        await _client.post(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(_timeout),
      'PATCH' => await _client.patch(uri,
          headers: headers, body: jsonEncode(body ?? {})).timeout(_timeout),
      'DELETE' => await _client.delete(uri, headers: headers).timeout(_timeout),
      _ => throw ArgumentError('Unsupported method $method'),
    };

    dynamic decoded;
    try {
      decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.body;
      }
      decoded = null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['error']?.toString() ?? 'Request failed'
          : 'Request failed';
      throw ApiException(response.statusCode, message);
    }

    return decoded;
  }
}
