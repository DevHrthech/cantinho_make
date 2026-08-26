import 'dart:convert';

import 'package:http/http.dart' as http;

class QueryApiException implements Exception {
  QueryApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'QueryApiException(statusCode: $statusCode, message: $message)';
}

abstract final class QueryApi {
  static const String baseUrl = 'https://cantinhomake.com.br/api/querys';
  static const String token = 'cheqmais';

  static Map<String, String> _headers() => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  static Future<dynamic> postSql(String sql) async {
    final resp = await http.post(
      Uri.parse(baseUrl),
      headers: _headers(),
      body: jsonEncode({'sql': sql}),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw QueryApiException(
        resp.body.trim().isEmpty ? 'HTTP ${resp.statusCode}' : resp.body,
        statusCode: resp.statusCode,
      );
    }

    if (resp.body.trim().isEmpty) return null;

    try {
      return jsonDecode(resp.body);
    } catch (_) {
      return resp.body;
    }
  }

  static List<Map<String, dynamic>> coerceRows(dynamic payload) {
    if (payload is List) {
      return payload
          .whereType<Map>()
          .map((m) => m.cast<String, dynamic>())
          .toList();
    }
    if (payload is Map) {
      final dyn = payload['data'] ??
          payload['rows'] ??
          payload['result'] ??
          payload['results'];
      if (dyn is List) {
        return dyn
            .whereType<Map>()
            .map((m) => m.cast<String, dynamic>())
            .toList();
      }
    }
    return const <Map<String, dynamic>>[];
  }

  static String sqlEscape(String value) => value.replaceAll("'", "''");
}
