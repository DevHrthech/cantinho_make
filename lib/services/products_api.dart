import '../models/product.dart';
import 'query_api.dart';

abstract final class ProductsApi {
  static Future<List<Product>> list() async {
    const sql =
        'SELECT Codigo_Interno, nome, codigo_barra, preco_custo, preco_venda, status FROM produtos';
    final payload = await QueryApi.postSql(sql);
    final rows = QueryApi.coerceRows(payload);
    return rows.map(Product.fromRow).where((p) => p.codigoInterno != 0).toList();
  }

  static Future<Product> getByCodigoInterno(int codigoInterno) async {
    final payload = await QueryApi.postSql(
      'SELECT Codigo_Interno, nome, nome_abreviado, codigo_barra, preco_custo, preco_venda, status '
      'FROM produtos WHERE Codigo_Interno = $codigoInterno',
    );
    final rows = QueryApi.coerceRows(payload);
    if (rows.isNotEmpty) return Product.fromRow(rows.first);
    if (payload is Map) return Product.fromRow(payload.cast<String, dynamic>());
    throw QueryApiException('Produto não encontrado');
  }

  static Future<void> update({
    required int codigoInterno,
    required String nome,
    required String nomeAbreviado,
    required String codigoBarra,
    required double precoCusto,
    required double precoVenda,
    required String status,
  }) async {
    final n = QueryApi.sqlEscape(nome);
    final na = QueryApi.sqlEscape(nomeAbreviado);
    final cb = QueryApi.sqlEscape(codigoBarra);
    final st = QueryApi.sqlEscape(status);
    final pc = precoCusto.toStringAsFixed(2);
    final pv = precoVenda.toStringAsFixed(2);

    final sql =
        "UPDATE `produtos` SET "
        "`nome`='$n',"
        "`nome_abreviado`='$na',"
        "`codigo_barra`='$cb',"
        "`preco_custo`='$pc',"
        "`preco_venda`='$pv',"
        "`status`='$st' "
        "WHERE `Codigo_Interno` = $codigoInterno";
    await QueryApi.postSql(sql);
  }
}

