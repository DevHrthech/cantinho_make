class Product {
  const Product({
    required this.codigoInterno,
    required this.nome,
    required this.nomeAbreviado,
    required this.codigoBarra,
    required this.precoCusto,
    required this.precoVenda,
    required this.status,
  });

  final int codigoInterno;
  final String nome;
  final String nomeAbreviado;
  final String codigoBarra;
  final double precoCusto;
  final double precoVenda;
  final String status;

  bool get isAtivo {
    final s = status.trim().toLowerCase();
    // A API pode vir como "Sim/Não", e também aceitamos "Ativo/Inativo", 1/0, true/false.
    if (s.isEmpty) return false;
    if (s == 'sim' || s == 'ativo' || s == '1' || s == 'true') return true;
    if (s == 'não' || s == 'nao' || s == 'inativo' || s == '0' || s == 'false') return false;
    // fallback: mantém compatibilidade com valores antigos (não quebra visual)
    return true;
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    final s = v.toString().trim();
    if (s.isEmpty) return 0;
    return double.tryParse(s.replaceAll(',', '.')) ?? 0;
  }

  factory Product.fromRow(Map<String, dynamic> r) {
    return Product(
      codigoInterno: _toInt(r['Codigo_Interno'] ?? r['codigo_interno'] ?? r['codigoInterno']),
      nome: (r['nome'] ?? '').toString(),
      nomeAbreviado: (r['nome_abreviado'] ?? r['nomeAbreviado'] ?? '').toString(),
      codigoBarra: (r['codigo_barra'] ?? r['codigo_barras'] ?? r['codigoBarra'] ?? '').toString(),
      precoCusto: _toDouble(r['preco_custo'] ?? r['precoCusto']),
      precoVenda: _toDouble(r['preco_venda'] ?? r['precoVenda']),
      status: (r['status'] ?? '').toString(),
    );
  }
}

