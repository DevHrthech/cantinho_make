class ProductRecord {
  const ProductRecord({
    required this.codigoInterno,
    required this.codigoBarras,
    required this.nome,
    required this.precoVenda,
  });

  final int? codigoInterno;
  final String codigoBarras;
  final String nome;
  final double precoVenda;
}

class ProductsLookupService {
  const ProductsLookupService();

  Future<List<ProductRecord>> findProductsMatchingBarcode(String barcode) {
    throw UnsupportedError('Consulta SQLite não é suportada no Web.');
  }

  Future<List<ProductRecord>> searchProductsByName(String query, {int limit = 40}) {
    throw UnsupportedError('Consulta SQLite não é suportada no Web.');
  }

  Future<ProductRecord?> findByBarcode(String barcode) {
    throw UnsupportedError('Consulta SQLite não é suportada no Web.');
  }
}
