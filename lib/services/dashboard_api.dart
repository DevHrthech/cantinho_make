import 'api_client.dart';

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
    final d = ApiClient.item(await ApiClient.get('/dashboard'));

    final raw = _cell(d, 'total_formatado');
    final totalFormatado =
        raw != null && raw.toString().trim().isNotEmpty ? raw.toString().trim() : '—';

    final topRaw = _cell(d, 'top_produtos');
    final topProdutos = (topRaw is List ? topRaw : const [])
        .whereType<Map>()
        .map((m) => m.cast<String, dynamic>())
        .map((row) {
      final nome = _cell(row, 'produto')?.toString().trim() ?? '';
      final u = _parseNum(_cell(row, 'total_unidades'));
      return DashboardTopProduto(nome: nome.isEmpty ? '(sem nome)' : nome, unidades: u);
    }).toList();

    return DashboardSnapshot(
      totalFormatado: totalFormatado,
      usuariosAtivos: _parseCount(_cell(d, 'usuarios_ativos')),
      depositosAtivos: _parseCount(_cell(d, 'depositos_ativos')),
      topProdutos: topProdutos,
    );
  }
}
