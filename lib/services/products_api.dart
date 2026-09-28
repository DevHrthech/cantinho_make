import '../models/product.dart';
import 'api_client.dart';

abstract final class ProductsApi {
  static Future<List<Product>> list() async {
    final payload = await ApiClient.get('/produtos');
    return ApiClient.rows(payload)
        .map(Product.fromRow)
        .where((p) => p.codigoInterno != 0)
        .toList();
  }

  static Future<Product> getByCodigoInterno(int codigoInterno) async {
    final payload = await ApiClient.get('/produtos/$codigoInterno');
    return Product.fromRow(ApiClient.item(payload));
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
    await ApiClient.put('/produtos/$codigoInterno', {
      'nome': nome,
      'nome_abreviado': nomeAbreviado,
      'codigo_barra': codigoBarra,
      'preco_custo': double.parse(precoCusto.toStringAsFixed(2)),
      'preco_venda': double.parse(precoVenda.toStringAsFixed(2)),
      'status': status,
    });
  }
}
