import 'package:intl/intl.dart';

class SaleReportRow {
  const SaleReportRow({
    required this.diaRaw,
    required this.codigoBarra,
    required this.produto,
    required this.quantidade,
    required this.deposito,
    required this.usuario,
    this.idVenda,
    this.tipoPagamento,
    this.valorUnitario,
    this.valorTotalLinha,
    this.desconto,
    this.valorTotalVenda,
  });

  final String diaRaw;
  final String codigoBarra;
  final String produto;
  final double quantidade;
  final String deposito;
  final String usuario;
  /// Agrupamento de venda (mesmo valor em todas as linhas de uma venda).
  final int? idVenda;
  final String? tipoPagamento;
  /// Preço unitário do produto no momento da venda.
  final double? valorUnitario;
  /// Valor da linha = quantidade * valor_unitario.
  final double? valorTotalLinha;
  /// Desconto aplicado (string original do banco, ex.: "R$20.00").
  final String? desconto;
  /// Valor final da venda após o desconto (mesmo em todas as linhas da venda).
  final double? valorTotalVenda;

  /// Colunas extras no relatório para depósitos da feira (ex.: Feira em Hidrolândia).
  static bool showsVendaGroupingForDeposito(String depositoNome) {
    final n = _normDepositoName(depositoNome);
    return n.contains('feira') && n.contains('hidroland');
  }

  static String _normDepositoName(String s) {
    return s
        .trim()
        .toLowerCase()
        .replaceAll('ã', 'a')
        .replaceAll('â', 'a')
        .replaceAll('á', 'a')
        .replaceAll('à', 'a');
  }

  static final _sqlDate = DateFormat('yyyy-MM-dd');
  static final _displayDate = DateFormat('dd-MM-yyyy');

  /// Exibe dia no formato DD-MM-YYYY quando o servidor manda YYYY-MM-DD ou data parseável.
  String get diaDisplay {
    final s = diaRaw.trim();
    if (s.isEmpty) return '';
    final head = s.split(RegExp(r'[T\s]')).first;
    try {
      final d = _sqlDate.parseStrict(head);
      return _displayDate.format(d);
    } catch (_) {
      final d = DateTime.tryParse(s);
      if (d != null) {
        return _displayDate.format(DateTime(d.year, d.month, d.day));
      }
      return s;
    }
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0;
  }

  static double? _toDoubleOrNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return double.tryParse(s.replaceAll(',', '.'));
  }

  static int? _toIntOrNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }

  static dynamic _raw(Map<String, dynamic> r, List<String> keys) {
    for (final k in keys) {
      if (r.containsKey(k)) return r[k];
      final hit =
          r.entries.where((e) => e.key.toLowerCase() == k.toLowerCase());
      if (hit.isNotEmpty) return hit.first.value;
    }
    return null;
  }

  factory SaleReportRow.fromRow(Map<String, dynamic> r) {
    String pick(List<String> keys) {
      for (final k in keys) {
        if (r.containsKey(k)) return (r[k] ?? '').toString();
        final hit =
            r.entries.where((e) => e.key.toLowerCase() == k.toLowerCase());
        if (hit.isNotEmpty) return (hit.first.value ?? '').toString();
      }
      return '';
    }

    final tp = pick(['tipo_pagamento', 'tipoPagamento']).trim();
    final valorUnitario =
        _toDouble(_raw(r, ['valor_unitario', 'valorUnitario']));
    final valorTotalLinha =
        _toDouble(_raw(r, ['valor_total', 'valorTotal']));
    final valorTotalVenda =
        _toDoubleOrNull(_raw(r, ['valor_total_venda', 'valorTotalVenda']));
    final descontoStr = pick(['desconto']);
    final desconto =
        descontoStr.trim().isEmpty ? null : descontoStr.trim();

    return SaleReportRow(
      diaRaw: pick(['dia', 'vp.dia']),
      codigoBarra: pick(['codigo_barra', 'codigoBarras']),
      produto: pick(['produto']),
      quantidade: _toDouble(_raw(r, ['quantidade', 'qtde'])),
      deposito: pick(['deposito']),
      usuario: pick(['usuario']),
      idVenda: _toIntOrNull(_raw(r, ['id_venda', 'idVenda'])),
      tipoPagamento: tp.isEmpty ? null : tp,
      valorUnitario: valorUnitario > 0 ? valorUnitario : null,
      valorTotalLinha: valorTotalLinha > 0
          ? valorTotalLinha
          : (valorUnitario * _toDouble(_raw(r, ['quantidade', 'qtde']))),
      desconto: desconto,
      valorTotalVenda: valorTotalVenda,
    );
  }
}
