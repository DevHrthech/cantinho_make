class ScannedLine {
  const ScannedLine({
    required this.barcode,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    this.codigoInterno,
  });

  final String barcode;
  final String name;
  final double unitPrice;
  final int quantity;
  final int? codigoInterno;

  double get lineTotal => unitPrice * quantity;

  ScannedLine copyWith({
    int? quantity,
    double? unitPrice,
  }) {
    return ScannedLine(
      barcode: barcode,
      name: name,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      codigoInterno: codigoInterno,
    );
  }
}
