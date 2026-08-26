import 'query_api.dart';

/// Linha de produto mais vendido (barra com meta de unidades).
class DashboardTopProduto {
  static const int kMetaUnidades = 50;

  const DashboardTopProduto({
    required this.nome,
    required this.unidades,
    this.metaUnidades = kMetaUnidades,
  });

  final String nome;
  final num unidades;
  final int metaUnidades;

  /// 0..1 em relação à meta (cap em 100%).
  double get progress => (unidades / metaUnidades).clamp(0.0, 1.0).toDouble();
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.totalFormatado,
    required this.usuariosAtivos,
    required this.depositosAtivos,
    required this.topProdutos,
  });

  final String totalFormatado;
  final int usuariosAtivos;
  final int depositosAtivos;
  final List<DashboardTopProduto> topProdutos;
}

abstract final class DashboardApi {
  static const _sqlTotalVendido = r'''
SELECT SUM(vp.quantidade * pr.preco_venda) AS total_vendido, CONCAT('R$ ', FORMAT(SUM(quantidade * preco_venda), 2, 'pt_BR')) AS total_formatado FROM VendaProdutos vp inner join produtos pr on vp.codigo_barra = pr.codigo_barra;
''';

  static const _sqlTopProdutos = r'''
SELECT produto, SUM(quantidade) AS total_unidades FROM VendaProdutos GROUP BY produto ORDER BY total_unidades DESC LIMIT 4;
''';

  static const _sqlDepositos = r'''
select COUNT(*) as quantidade_depositos from depositos where status = 'Ativo' 
''';

  static const _sqlUsuarios = r'''
select COUNT(*) as quantidade_usuarios from usuarios where status = 'Ativo' 
''';

  static dynamic _cell(Map<String, dynamic> row, String column) {
    for (final e in row.entries) {
      if (e.key.toLowerCase() == column.toLowerCase()) return e.value;
    }
    return null;
  }

  static int _parseCount(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim()) ?? 0;
    return 0;
  }

  static num _parseNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    if (v is String) {
      final s = v.trim().replaceAll(',', '.');
      return num.tryParse(s) ?? 0;
    }
    return 0;
  }

  static Future<DashboardSnapshot> load() async {
    final payloads = await Future.wait<dynamic>([
      QueryApi.postSql(_sqlTotalVendido.trim()),
      QueryApi.postSql(_sqlTopProdutos.trim()),
      QueryApi.postSql(_sqlDepositos.trim()),
      QueryApi.postSql(_sqlUsuarios.trim()),
    ]);

    final totalRows = QueryApi.coerceRows(payloads[0]);
    String totalFormatado = '—';
    if (totalRows.isNotEmpty) {
      final raw = _cell(totalRows.first, 'total_formatado');
      if (raw != null && raw.toString().trim().isNotEmpty) {
        totalFormatado = raw.toString().trim();
      }
    }

    final topRows = QueryApi.coerceRows(payloads[1]);
    final topProdutos = topRows.map((row) {
      final nome = _cell(row, 'produto')?.toString().trim() ?? '';
      final u = _parseNum(_cell(row, 'total_unidades'));
      return DashboardTopProduto(nome: nome.isEmpty ? '(sem nome)' : nome, unidades: u);
    }).toList();

    final depRows = QueryApi.coerceRows(payloads[2]);
    final depositosAtivos = depRows.isEmpty
        ? 0
        : _parseCount(_cell(depRows.first, 'quantidade_depositos'));

    final usrRows = QueryApi.coerceRows(payloads[3]);
    final usuariosAtivos = usrRows.isEmpty
        ? 0
        : _parseCount(_cell(usrRows.first, 'quantidade_usuarios'));

    return DashboardSnapshot(
      totalFormatado: totalFormatado,
      usuariosAtivos: usuariosAtivos,
      depositosAtivos: depositosAtivos,
      topProdutos: topProdutos,
    );
  }
}
