import 'package:http/http.dart' as http;

import 'api_client.dart';

/// Falha no upload (`step: upload`) ou na importação (`step: importar`).
class ProductsImportException implements Exception {
  ProductsImportException(
    this.message, {
    this.statusCode,
    this.step,
  });

  final String message;
  final int? statusCode;
  final String? step;

  @override
  String toString() =>
      'ProductsImportException(step: $step, statusCode: $statusCode, message: $message)';
}

abstract final class ProductsImportApi {
  static final _uploadUri = Uri.parse('https://cantinhomake.com.br/api/upload-xls');
  static final _importUri = Uri.parse('https://cantinhomake.com.br/api/importar-produtos');

  /// Token do administrador logado.
  static Map<String, String> get _headers => ApiClient.authHeaders();

  static String _shortMessage(String body, {int max = 450}) {
    final t = body.trim();
    if (t.isEmpty) return 'Sem detalhes no corpo da resposta.';
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…';
  }

  static Future<void> uploadXls({
    required String filePath,
    String? fileName,
  }) async {
    final req = http.MultipartRequest('POST', _uploadUri);
    req.headers.addAll(_headers);
    req.files.add(
      await http.MultipartFile.fromPath(
        'xls_file',
        filePath,
        filename: fileName,
      ),
    );
    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ProductsImportException(
        _shortMessage(resp.body),
        statusCode: resp.statusCode,
        step: 'upload',
      );
    }
  }

  static Future<void> uploadXlsBytes({
    required List<int> bytes,
    required String fileName,
  }) async {
    final req = http.MultipartRequest('POST', _uploadUri);
    req.headers.addAll(_headers);
    req.files.add(
      http.MultipartFile.fromBytes(
        'xls_file',
        bytes,
        filename: fileName.isEmpty ? 'produtos.csv' : fileName,
      ),
    );
    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ProductsImportException(
        _shortMessage(resp.body),
        statusCode: resp.statusCode,
        step: 'upload',
      );
    }
  }

  static Future<void> importarProdutos() async {
    final resp = await http.post(_importUri, headers: _headers);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ProductsImportException(
        _shortMessage(resp.body),
        statusCode: resp.statusCode,
        step: 'importar',
      );
    }
  }
}
