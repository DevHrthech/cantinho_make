import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../local_db.dart';
import '../api_client.dart';

class ProductsSyncService {
  const ProductsSyncService();

  Future<int> syncProdutos() async {
    final payload = await ApiClient.get('/produtos');
    final rows = ApiClient.rows(payload);

    final db = (await LocalDb.instance.database) as Database;

    return db.transaction<int>((txn) async {
      await txn.delete('produtos');

      final batch = txn.batch();
      for (final row in rows) {
        batch.insert(
          'produtos',
          _mapRow(row),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
      return rows.length;
    });
  }

  Map<String, Object?> _mapRow(Map<String, dynamic> row) {
    dynamic pick(List<String> keys) {
      for (final k in keys) {
        if (row.containsKey(k)) return row[k];
        // tenta case-insensitive
        final found = row.entries
            .where((e) => e.key.toLowerCase() == k.toLowerCase())
            .map((e) => e.value)
            .toList();
        if (found.isNotEmpty) return found.first;
      }
      return null;
    }

    final codigoInterno = pick(['Codigo_Interno', 'codigo_interno', 'codigoInterno']);
    final codigoBarras = pick(['codigo_barras', 'codigo_barra', 'codigoBarras']);

    return <String, Object?>{
      'codigo_interno': _toIntOrNull(codigoInterno),
      'codigo_barras': codigoBarras?.toString(),
      'nome': pick(['nome'])?.toString(),
      'preco_venda': _toDoubleOrNull(pick(['preco_venda', 'precoVenda'])),
      'status': pick(['status'])?.toString(),
    };
  }

  int? _toIntOrNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  double? _toDoubleOrNull(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.'));
  }
}

