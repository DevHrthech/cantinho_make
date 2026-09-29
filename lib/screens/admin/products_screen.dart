import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../services/products_api.dart';
import '../../theme/app_colors.dart';
import '../../utils/format_money.dart';
import '../../utils/friendly_error_message.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/glass_card.dart';
import 'product_detail_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  late Future<List<Product>> _future;
  int _rowsPerPage = 25;
  int _page = 0;
  final _searchCtrl = TextEditingController();
  String? _query;
  bool _syncBusy = false;

  @override
  void initState() {
    super.initState();
    _future = ProductsApi.list();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _future = ProductsApi.list());
    await _future;
  }

  Future<void> _openDetail(int codigoInterno) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailScreen(codigoInterno: codigoInterno),
      ),
    );
  }

  /// Puxa agora o cadastro do Bling (o servidor também faz isso a cada 15 minutos).
  Future<void> _sincronizarBling() async {
    if (_syncBusy) return;
    setState(() => _syncBusy = true);
    try {
      final r = await ProductsApi.sincronizarBling();
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      final pendentes = r['pendentes'] ?? 0;
      final msg = 'Bling: ${r['criados'] ?? 0} novo(s), ${r['atualizados'] ?? 0} atualizado(s), '
          '${r['inativados'] ?? 0} inativado(s).'
          '${pendentes > 0 ? ' Ainda faltam $pendentes; toque de novo para continuar.' : ''}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível sincronizar: ${friendlyErrorMessage(e)}')),
      );
    } finally {
      if (mounted) setState(() => _syncBusy = false);
    }
  }

  Future<void> _pickRowsPerPage() async {
    final ctrl = TextEditingController(text: '$_rowsPerPage');
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Linhas por página'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Quantidade',
              helperText: 'Sugestões: 25, 40, 60, 100 (ou qualquer número)',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final v = int.tryParse(ctrl.text.trim());
                Navigator.pop(ctx, v);
              },
              child: const Text('Aplicar'),
            ),
          ],
        );
      },
    );
    if (picked == null) return;
    final v = picked < 1 ? 1 : picked;
    setState(() {
      _rowsPerPage = v;
      _page = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Product>>(
      future: _future,
      builder: (context, snap) {
        final loading = snap.connectionState != ConnectionState.done;
        final all = snap.data ?? const <Product>[];
        final err = snap.error;

        final q = (_query ?? '').trim().toLowerCase();
        final data = q.isEmpty
            ? all
            : all.where((p) => p.nome.trim().toLowerCase().contains(q)).toList();

        final baseOptions = const <int>[25, 40, 60, 100];
        final options = <int>{
          ...baseOptions,
          _rowsPerPage,
        }.toList()
          ..sort();

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Produtos sincronizados do Bling. Cadastro e alterações são feitos no Bling.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.darkTextMuted),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: (loading || _syncBusy) ? null : _sincronizarBling,
                        icon: _syncBusy
                            ? const AppLoadingIndicator(size: 18)
                            : const Icon(Icons.sync_rounded, size: 18),
                        label: const Text('Sincronizar com Bling'),
                        style: FilledButton.styleFrom(
                          foregroundColor: AppColors.cream,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: loading ? null : _pickRowsPerPage,
                        icon: const Icon(Icons.format_list_numbered_rounded, size: 18),
                        label: Text('Linhas: $_rowsPerPage'),
                        style: FilledButton.styleFrom(
                          foregroundColor: AppColors.cream,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GlassCard(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: AppColors.cream),
                  decoration: InputDecoration(
                    labelText: 'Pesquisar por nome',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: (_query ?? '').trim().isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpar',
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {
                                _query = null;
                                _page = 0;
                              });
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                  onChanged: (v) {
                    setState(() {
                      _query = v;
                      _page = 0;
                    });
                  },
                ),
              ),
              const SizedBox(height: 12),
              if (err != null) ...[
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.danger),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Erro ao carregar produtos: $err',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.darkTextMuted),
                        ),
                      ),
                      TextButton(onPressed: _refresh, child: const Text('Recarregar')),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              GlassCard(
                padding: const EdgeInsets.all(14),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final useTable = c.maxWidth >= 860;
                    if (!useTable) {
                      if (loading) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: AppLoadingIndicator(size: 48)),
                        );
                      }
                      if (data.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Nenhum produto encontrado.',
                            style: TextStyle(color: AppColors.cream),
                          ),
                        );
                      }
                      final totalPages = (data.length / _rowsPerPage).ceil().clamp(1, 1 << 30);
                      final safePage = _page.clamp(0, totalPages - 1);
                      final start = safePage * _rowsPerPage;
                      final end = (start + _rowsPerPage).clamp(0, data.length);
                      final pageItems = data.sublist(start, end);

                      return Column(
                        children: [
                          ...pageItems.map((p) {
                          final statusColor = p.isAtivo ? AppColors.success : AppColors.warning;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: GlassCard(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.nome,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                color: AppColors.cream,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Código: ${p.codigoInterno} · Barras: ${p.codigoBarra}',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: AppColors.darkTextMuted,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Custo: ${formatBrl(p.precoCusto)} · Venda: ${formatBrl(p.precoVenda)}',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: AppColors.darkTextMuted,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(999),
                                            color: statusColor.withValues(alpha: 0.15),
                                          ),
                                          child: Text(
                                            p.status,
                                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                  color: statusColor,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Detalhes',
                                    onPressed: () => _openDetail(p.codigoInterno),
                                    icon: const Icon(Icons.visibility_rounded, color: AppColors.cream),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'Anterior',
                                onPressed: safePage <= 0
                                    ? null
                                    : () => setState(() => _page = safePage - 1),
                                icon: const Icon(Icons.chevron_left_rounded, color: AppColors.cream),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'Página ${safePage + 1} de $totalPages',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppColors.darkTextMuted,
                                        ),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Próxima',
                                onPressed: safePage >= totalPages - 1
                                    ? null
                                    : () => setState(() => _page = safePage + 1),
                                icon: const Icon(Icons.chevron_right_rounded, color: AppColors.cream),
                              ),
                            ],
                          ),
                        ],
                      );
                    }

                    if (loading) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: AppLoadingIndicator(size: 48)),
                      );
                    }
                    if (data.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Nenhum produto encontrado.',
                          style: TextStyle(color: AppColors.cream),
                        ),
                      );
                    }

                    final source = _ProductsTableSource(
                      products: data,
                      onOpen: _openDetail,
                      context: context,
                    );

                    final headingTextStyle =
                        Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.darkTextMuted,
                              fontWeight: FontWeight.w800,
                            ) ??
                            const TextStyle(
                              color: AppColors.darkTextMuted,
                              fontWeight: FontWeight.w800,
                            );
                    final dataTextStyle =
                        Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.cream,
                            ) ??
                            const TextStyle(color: AppColors.cream);

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Builder(
                        builder: (context) {
                          final mqW = MediaQuery.sizeOf(context).width;
                          final safeW = (c.maxWidth.isFinite && c.maxWidth > 0) ? c.maxWidth : mqW;
                          // evita largura infinita/zero no Flutter Web (causa tela vazia até relayout)
                          final tableWidth = safeW < 980 ? 980.0 : safeW;

                          return SizedBox(
                            width: tableWidth,
                            child: DataTableTheme(
                              data: DataTableThemeData(
                                headingTextStyle: headingTextStyle,
                                dataTextStyle: dataTextStyle,
                                headingRowColor: WidgetStatePropertyAll(
                                  Colors.white.withValues(alpha: 0.04),
                                ),
                                dividerThickness: 0.6,
                                horizontalMargin: 16,
                                columnSpacing: 18,
                              ),
                              child: PaginatedDataTable(
                                showFirstLastButtons: true,
                                arrowHeadColor: AppColors.cream,
                                rowsPerPage: _rowsPerPage,
                                availableRowsPerPage: options,
                                onRowsPerPageChanged: (v) {
                                  if (v == null) return;
                                  setState(() {
                                    _rowsPerPage = v;
                                    _page = 0;
                                  });
                                },
                                header: Row(
                                  children: [
                                    Text(
                                      'Produtos (${data.length})',
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                            color: AppColors.cream,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const Spacer(),
                                    TextButton.icon(
                                      onPressed: _pickRowsPerPage,
                                      icon: const Icon(Icons.tune_rounded),
                                      label: const Text('Personalizar'),
                                    ),
                                  ],
                                ),
                                columns: const [
                                  DataColumn(label: Text('Código')),
                                  DataColumn(label: Text('Nome')),
                                  DataColumn(label: Text('Barras')),
                                  DataColumn(label: Text('Custo')),
                                  DataColumn(label: Text('Venda')),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('')),
                                ],
                                source: source,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProductsTableSource extends DataTableSource {
  _ProductsTableSource({
    required this.products,
    required this.onOpen,
    required this.context,
  });

  final List<Product> products;
  final Future<void> Function(int codigoInterno) onOpen;
  final BuildContext context;

  @override
  DataRow? getRow(int index) {
    if (index < 0 || index >= products.length) return null;
    final p = products[index];
    final statusColor = p.isAtivo ? AppColors.success : AppColors.warning;

    return DataRow(
      cells: [
        DataCell(Text('${p.codigoInterno}')),
        DataCell(Text(p.nome)),
        DataCell(Text(p.codigoBarra)),
        DataCell(Text(formatBrl(p.precoCusto))),
        DataCell(Text(formatBrl(p.precoVenda))),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: statusColor.withValues(alpha: 0.15),
            ),
            child: Text(
              p.status,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ),
        DataCell(
          IconButton(
            tooltip: 'Detalhes',
            onPressed: () => onOpen(p.codigoInterno),
            icon: const Icon(Icons.visibility_rounded, color: AppColors.cream),
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => products.length;

  @override
  int get selectedRowCount => 0;
}
