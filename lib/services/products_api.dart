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

  /// Atualiza agora a tabela de produtos do servidor com o cadastro do Bling.
  /// Retorna o resumo: criados, atualizados, vinculados, inativados, pendentes, erros.
  static Future<Map<String, int>> sincronizarBling() async {
    final payload = await ApiClient.post('/bling/sincronizar-produtos', const {});
    return ApiClient.item(payload).map((k, v) => MapEntry(k, v is num ? v.toInt() : 0));
  }
}
