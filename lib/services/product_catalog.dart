import 'dart:math' as math;

/// Catálogo local de exemplo. No futuro pode vir de API por filial.
class ProductInfo {
  const ProductInfo({
    required this.barcode,
    required this.name,
    required this.unitPrice,
  });

  final String barcode;
  final String name;
  final double unitPrice;
}

abstract final class ProductCatalog {
  static const Map<String, ({String name, double price})> _known = {
    '7891000310507': (name: 'Água mineral 500 ml', price: 2.50),
    '7891234567890': (name: 'Chocolate ao leite 90 g', price: 8.90),
    '7894900011517': (name: 'Refrigerante lata 350 ml', price: 4.29),
    '7896004004173': (name: 'Café torrado 500 g', price: 24.90),
  };

  static ProductInfo resolve(String barcode) {
    final trimmed = barcode.trim();
    final hit = _known[trimmed];
    if (hit != null) {
      return ProductInfo(barcode: trimmed, name: hit.name, unitPrice: hit.price);
    }
    final pseudo = _pseudoPrice(trimmed);
    return ProductInfo(
      barcode: trimmed,
      name: 'Produto ($trimmed)',
      unitPrice: pseudo,
    );
  }

  /// Preço fictício estável por código (até integrar com estoque real).
  static double _pseudoPrice(String code) {
    var h = 0;
    for (final u in code.codeUnits) {
      h = 0x1fffffff & (h * 31 + u);
    }
    final cents = h % 15000; // R$ 0,00 a R$ 149,99
    return math.max(0.99, cents / 100.0);
  }
}
