import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException(statusCode: $statusCode, message: $message)';
}

/// Cliente das rotas `/api/v2` (login por usuário com token).
abstract final class ApiClient {
  static String baseUrl = 'https://cantinhomake.com.br/api/v2';
  static const Duration _timeout = Duration(seconds: 20);

  /// Token da sessão atual; definido no login e limpo no logout.
  static String? token;

  static Map<String, String> authHeaders() => {
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static Map<String, String> _headers() => {
        ...authHeaders(),
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  static Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send(() => http.get(_uri(path, query), headers: _headers()));

  static Future<dynamic> post(String path, Object body) => _send(
        () => http.post(_uri(path), headers: _headers(), body: jsonEncode(body)),
      );

  static Future<dynamic> put(String path, Object body) => _send(
        () => http.put(_uri(path), headers: _headers(), body: jsonEncode(body)),
      );

  static Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  static Future<dynamic> _send(Future<http.Response> Function() request) async {
    final resp = await request().timeout(_timeout);
    dynamic payload;
    if (resp.body.trim().isNotEmpty) {
      try {
        payload = jsonDecode(resp.body);
      } catch (_) {
        payload = resp.body;
      }
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final msg = payload is Map && payload['error'] != null
          ? payload['error'].toString()
          : 'HTTP ${resp.statusCode}';
      throw ApiException(msg, statusCode: resp.statusCode);
    }
    return payload;
  }

  /// Lista em `data` da resposta.
  static List<Map<String, dynamic>> rows(dynamic payload) {
    final data = payload is Map ? payload['data'] : payload;
    if (data is! List) return const [];
    return data.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
  }

  /// Objeto em `data` da resposta.
  static Map<String, dynamic> item(dynamic payload) {
    final data = payload is Map ? payload['data'] : null;
    if (data is Map) return data.cast<String, dynamic>();
    throw ApiException('Resposta inesperada do servidor.');
  }
}
