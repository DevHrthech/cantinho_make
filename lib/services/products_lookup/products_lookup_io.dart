import 'package:sqflite/sqflite.dart';

import '../local_db.dart';
import 'products_lookup_stub.dart' show ProductRecord;

export 'products_lookup_stub.dart' show ProductRecord;

class ProductsLookupService {
  const ProductsLookupService();

  /// Comprimento mínimo do código para tentar correspondência por prefixo
  /// (evita `LIKE '12%'` retornar centenas de itens).
  static const int minBarcodePrefixLength = 8;

  static const int maxBarcodeMatches = 50;

  ProductRecord _rowToRecord(Map<String, Object?> r) {
    return ProductRecord(
      codigoInterno: _toIntOrNull(r['codigo_interno']),
      codigoBarras: (r['codigo_barras'] ?? '').toString(),
      nome: (r['nome'] ?? '').toString(),
      precoVenda: _toDouble(r['preco_venda']),
    );
  }

  /// Resolve leitura manual ou scanner: igualdade exata; se não achar e o código
  /// for longo o suficiente, produtos cujo `codigo_barras` **começa** com o texto lido
  /// (ex.: etiqueta com 13 dígitos e cadastro com 14).
  Future<List<ProductRecord>> findProductsMatchingBarcode(String barcode) async {
    final b = barcode.trim();
    if (b.isEmpty) return const [];

    final db = (await LocalDb.instance.database) as Database;
    const cols = ['codigo_interno', 'codigo_barras', 'nome', 'preco_venda'];

    final exact = await db.query(
      'produtos',
      columns: cols,
      where: 'codigo_barras = ?',
      whereArgs: [b],
      orderBy: 'codigo_barras ASC',
      limit: maxBarcodeMatches,
    );
    if (exact.isNotEmpty) {
      return exact.map(_rowToRecord).toList();
    }

    if (b.length < minBarcodePrefixLength) {
      return const [];
    }

    final escaped = _escapeLikePattern(b);
    final prefixRows = await db.query(
      'produtos',
      columns: cols,
      where: r"codigo_barras LIKE ? ESCAPE '\'",
      whereArgs: ['$escaped%'],
      orderBy: 'codigo_barras ASC',
      limit: maxBarcodeMatches,
    );
    return prefixRows.map(_rowToRecord).toList();
  }

  /// Busca por trecho do nome (mínimo 2 caracteres úteis).
  Future<List<ProductRecord>> searchProductsByName(
    String query, {
    int limit = 40,
  }) async {
    final q = query.trim().replaceAll(RegExp(r'[%_\\]'), '');
    if (q.length < 2) return const [];

    final db = (await LocalDb.instance.database) as Database;
    final escaped = _escapeLikePattern(q);
    final rows = await db.query(
      'produtos',
      columns: const ['codigo_interno', 'codigo_barras', 'nome', 'preco_venda'],
      where: r"nome LIKE ? ESCAPE '\'",
      whereArgs: ['%$escaped%'],
      orderBy: 'nome COLLATE NOCASE ASC',
      limit: limit,
    );
    return rows.map(_rowToRecord).toList();
  }

  /// Mantido para compatibilidade: só retorna se houver **exatamente uma** linha
  /// após a mesma lógica de [findProductsMatchingBarcode].
  Future<ProductRecord?> findByBarcode(String barcode) async {
    final list = await findProductsMatchingBarcode(barcode);
    if (list.length == 1) return list.first;
    return null;
  }

  static String _escapeLikePattern(String raw) {
    return raw.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
  }

  int? _toIntOrNull(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  double _toDouble(Object? v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0;
  }
}
