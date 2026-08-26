import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/deposito.dart';
import '../../models/sale_report_row.dart';
import '../../models/session_user.dart';
import '../../services/deposits_api.dart';
import '../../services/sales_report_api.dart';
import '../../theme/app_colors.dart';
import '../../utils/format_money.dart';
import '../../utils/pdf_export.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/glass_card.dart';
import '../../services/sales_report_pdf.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.user});

  final SessionUser user;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  static final _fmtDisplay = DateFormat('dd-MM-yyyy');

  DateTime? _dataInicial;
  DateTime? _dataFinal;

  List<Deposito> _depositos = const [];
  String? _depositoAdminNome;
  bool _depositosCarregando = false;

  List<SaleReportRow>? _linhas;
  bool _consultando = false;
  String? _erroConsulta;

  bool _pdfBusy = false;

  int _rowsPerPage = 25;
  int _pageM = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dataFinal = DateTime(now.year, now.month, now.day);
    _dataInicial = _dataFinal!.subtract(const Duration(days: 30));
    if (widget.user.isAdmin) {
      _carregarDepositos();
    }
  }

  Future<void> _carregarDepositos() async {
    setState(() {
      _depositosCarregando = true;
    });
    try {
      final list = await DepositsApi.listActive();
      if (!mounted) return;
      setState(() {
        _depositos = list;
        _depositoAdminNome = _escolherDepositoInicial(list);
      });
    } catch (_) {
      if (mounted) setState(() => _depositos = const []);
    } finally {
      if (mounted) setState(() => _depositosCarregando = false);
    }
  }

  String? _escolherDepositoInicial(List<Deposito> list) {
    if (list.isEmpty) return null;
    final u = widget.user.deposito.trim();
    if (u.isNotEmpty) {
      final hit = list
          .where((d) => d.nome.trim().toLowerCase() == u.toLowerCase())
          .toList();
      if (hit.isNotEmpty) return hit.first.nome;
    }
    return list.first.nome;
  }

  String get _depositoFiltro {
    if (widget.user.isAdmin) {
      return (_depositoAdminNome ?? widget.user.deposito).trim();
    }
    return widget.user.deposito.trim();
  }

  /// Depósito da feira em Hidrolândia: exibe `id_venda` e `tipo_pagamento` no relatório.
  bool get _mostrarIdVendaTipoPagamento =>
      SaleReportRow.showsVendaGroupingForDeposito(_depositoFiltro);

  Future<void> _pickData({required bool inicial}) async {
    final now = DateTime.now();
    final current = inicial ? _dataInicial : _dataFinal;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  surface: AppColors.darkCardElevated,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() {
      if (inicial) {
        _dataInicial = DateTime(picked.year, picked.month, picked.day);
      } else {
        _dataFinal = DateTime(picked.year, picked.month, picked.day);
      }
      _linhas = null;
      _pageM = 0;
    });
  }

  Future<void> _consultar() async {
    final di = _dataInicial;
    final df = _dataFinal;
    if (di == null || df == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe a data inicial e a data final.')),
      );
      return;
    }
    if (di.isAfter(df)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A data inicial não pode ser depois da final.')),
      );
      return;
    }
    final dep = _depositoFiltro;
    if (dep.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Depósito não definido para o relatório.')),
      );
      return;
    }

    setState(() {
      _consultando = true;
      _erroConsulta = null;
      _linhas = null;
      _pageM = 0;
    });
    try {
      final rows = await SalesReportApi.list(
        dataInicial: di,
        dataFinal: df,
        depositoNome: dep,
      );
      if (!mounted) return;
      setState(() {
        _linhas = rows;
        _consultando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _consultando = false;
        _erroConsulta = e.toString();
      });
    }
  }

  Future<void> _exportPdf() async {
    final di = _dataInicial;
    final df = _dataFinal;
    final linhas = _linhas;
    if (di == null || df == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Defina as datas do relatório antes de exportar.')),
      );
      return;
    }
    if (linhas == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Consulte os dados antes de gerar o PDF.')),
      );
      return;
    }
    final dep = _depositoFiltro;
    if (dep.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Depósito não definido para o relatório.')),
      );
      return;
    }

    setState(() => _pdfBusy = true);
    try {
      final bytes = await SalesReportPdf.buildBytes(
        dataInicial: di,
        dataFinal: df,
        depositoNome: dep,
        rows: linhas,
        showVendaGroupingColumns: SaleReportRow.showsVendaGroupingForDeposito(dep),
      );
      if (!mounted) return;
      await exportOrSharePdfBytes(
        bytes: bytes,
        filename: 'Espelho_Espelho_Meu_relatorio_vendas.pdf',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb
                ? 'PDF baixado. Verifique a pasta de downloads do navegador.'
                : 'PDF gerado com sucesso.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao gerar PDF: $e')),
      );
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  String _fmtQtd(double q) {
    if (q == q.roundToDouble()) return '${q.toInt()}';
    return q.toStringAsFixed(2).replaceAll('.', ',');
  }

  List<Widget> _totaisResumo(List<SaleReportRow> data) {
    if (data.isEmpty) return const [];
    final sumVendas = data.fold<double>(
      0,
      (s, r) => s + (r.valorTotalLinha ?? 0),
    );
    // Soma o desconto uma única vez por venda (id_venda) para não multiplicar.
    final descontoPorVenda = <int, double>{};
    double descontoSemId = 0;
    // Soma o valor total da venda uma única vez por venda (id_venda) para não multiplicar.
    final valorTotalVendaPorVenda = <int, double>{};
    double valorTotalVendaSemId = 0;
    for (final r in data) {
      final d = r.desconto;
      if (d != null && d.isNotEmpty) {
        final m = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(d);
        if (m != null) {
          final v = double.tryParse(m.group(1)!.replaceAll(',', '.')) ?? 0;
          final id = r.idVenda;
          if (id == null) {
            descontoSemId += v;
          } else if (!descontoPorVenda.containsKey(id)) {
            descontoPorVenda[id] = v;
          }
        }
      }
      // Processa valor total da venda
      final vtv = r.valorTotalVenda;
      if (vtv != null) {
        final id = r.idVenda;
        if (id == null) {
          valorTotalVendaSemId += vtv;
        } else if (!valorTotalVendaPorVenda.containsKey(id)) {
          valorTotalVendaPorVenda[id] = vtv;
        }
      }
    }
    final sumDesconto =
        descontoPorVenda.values.fold<double>(0, (s, v) => s + v) +
            descontoSemId;
    final sumValorTotalVenda =
        valorTotalVendaPorVenda.values.fold<double>(0, (s, v) => s + v) +
            valorTotalVendaSemId;

    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.darkTextMuted,
        );
    final valueStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppColors.cream,
          fontWeight: FontWeight.w800,
        );

    Widget col(String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: labelStyle),
              const SizedBox(height: 4),
              Text(value, style: valueStyle),
            ],
          ),
        );

    return [
      const SizedBox(height: 14),
      LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 600;
          final values = <Widget>[
            col('Soma valor total', formatBrl(sumVendas)),
            col('Soma descontos', formatBrl(sumDesconto)),
            col('Soma valor total venda', formatBrl(sumValorTotalVenda)),
          ];
          if (wide) {
            return GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  values[0],
                  Container(
                    width: 1,
                    height: 40,
                    color: AppColors.cream.withValues(alpha: 0.18),
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  values[1],
                  Container(
                    width: 1,
                    height: 40,
                    color: AppColors.cream.withValues(alpha: 0.18),
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  values[2],
                ],
              ),
            );
          }
          return GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                values[0],
                const Divider(height: 24, color: Colors.white24),
                values[1],
                const Divider(height: 24, color: Colors.white24),
                values[2],
              ],
            ),
          );
        },
      ),
    ];
  }

  Widget _dateField({required String label, required bool inicial}) {
    final d = inicial ? _dataInicial : _dataFinal;
    return InkWell(
      onTap: () => _pickData(inicial: inicial),
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          hintText: 'Toque para escolher (ex.: DD-MM-AAAA)',
          prefixIcon: const Icon(Icons.calendar_today_rounded),
        ),
        child: Text(
          d == null ? '' : _fmtDisplay.format(d),
          style: const TextStyle(color: AppColors.cream),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Text(
          'Vendas no período (API). O depósito padrão do seu usuário é usado quando você não é administrador.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.darkTextMuted),
        ),
        const SizedBox(height: 14),
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Filtros',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.cream,
                    ),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 600;
                  final rowDates = wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _dateField(label: 'Data inicial', inicial: true)),
                            const SizedBox(width: 12),
                            Expanded(child: _dateField(label: 'Data final', inicial: false)),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _dateField(label: 'Data inicial', inicial: true),
                            const SizedBox(height: 12),
                            _dateField(label: 'Data final', inicial: false),
                          ],
                        );

                  if (!widget.user.isAdmin) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        rowDates,
                        const SizedBox(height: 12),
                        Text(
                          'Depósito: ${widget.user.deposito}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.darkTextMuted,
                              ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      rowDates,
                      const SizedBox(height: 12),
                      if (_depositosCarregando)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: AppLoadingIndicator(size: 32)),
                        )
                      else if (_depositos.isEmpty)
                        Text(
                          'Nenhum depósito ativo encontrado.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.darkTextMuted,
                              ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          key: ValueKey(
                            '${_depositos.length}_${_depositoAdminNome ?? ''}',
                          ),
                          initialValue: _depositoAdminNome,
                          items: _depositos
                              .map(
                                (d) => DropdownMenuItem(
                                  value: d.nome,
                                  child: Text(d.nome),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              _depositoAdminNome = v;
                              _linhas = null;
                              _pageM = 0;
                            });
                          },
                          dropdownColor: AppColors.darkCardElevated,
                          style: const TextStyle(color: AppColors.cream),
                          decoration: const InputDecoration(
                            labelText: 'Depósito',
                            prefixIcon: Icon(Icons.warehouse_rounded),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: (_consultando || _pdfBusy) ? null : _consultar,
                icon: _consultando
                    ? const AppLoadingIndicator(size: 22)
                    : const Icon(Icons.search_rounded),
                label: Text(_consultando ? 'Consultando…' : 'Consultar vendas'),
              ),
              if (_linhas != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: (_pdfBusy || _consultando) ? null : _exportPdf,
                  icon: _pdfBusy
                      ? const AppLoadingIndicator(size: 22)
                      : const Icon(Icons.picture_as_pdf_outlined, color: AppColors.cream),
                  label: Text(_pdfBusy ? 'Gerando PDF…' : 'Exportar PDF'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.cream,
                    side: BorderSide(color: AppColors.cream.withValues(alpha: 0.45)),
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_erroConsulta != null)
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.danger),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _erroConsulta!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.darkTextMuted,
                        ),
                  ),
                ),
              ],
            ),
          ),
        if (_erroConsulta != null) const SizedBox(height: 12),
        if (_linhas != null) ...[
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: LayoutBuilder(
              builder: (context, c) {
                final data = _linhas!;
                if (data.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Nenhuma venda encontrada no período.',
                      style: TextStyle(color: AppColors.cream),
                    ),
                  );
                }

                final useTable = c.maxWidth >= 720;
                if (!useTable) {
                  final totalPages = (data.length / _rowsPerPage).ceil().clamp(1, 1 << 30);
                  final safePage = _pageM.clamp(0, totalPages - 1);
                  final start = safePage * _rowsPerPage;
                  final end = (start + _rowsPerPage).clamp(0, data.length);
                  final pageItems = data.sublist(start, end);

                  return SelectionArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...pageItems.map((r) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: GlassCard(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SelectableText(
                                    r.produto,
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          color: AppColors.cream,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  SelectableText(
                                    '${r.diaDisplay} · ${_fmtQtd(r.quantidade)} un. · '
                                    'Vlr unit.: ${r.valorUnitario != null ? formatBrl(r.valorUnitario!) : '—'}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppColors.darkTextMuted,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  SelectableText(
                                    'Código de barras: ${r.codigoBarra} · ${r.deposito} · ${r.usuario}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppColors.darkTextMuted,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  SelectableText(
                                    'Valor total: ${r.valorTotalLinha != null ? formatBrl(r.valorTotalLinha!) : '—'}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppColors.darkTextMuted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  SelectableText(
                                    'Desconto: ${r.desconto ?? '—'} · '
                                    'Valor total venda: ${r.valorTotalVenda != null ? formatBrl(r.valorTotalVenda!) : '—'}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppColors.darkTextMuted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  if (_mostrarIdVendaTipoPagamento) ...[
                                    const SizedBox(height: 4),
                                    SelectableText(
                                      'ID venda: ${r.idVenda ?? '—'} · '
                                      'Forma pagamento: ${r.tipoPagamento ?? '—'}',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: AppColors.darkTextMuted,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Anterior',
                              onPressed: safePage <= 0
                                  ? null
                                  : () => setState(() => _pageM = safePage - 1),
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
                                  : () => setState(() => _pageM = safePage + 1),
                              icon: const Icon(Icons.chevron_right_rounded, color: AppColors.cream),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }

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

                final source = _SalesReportSource(
                  rows: data,
                  fmtQtd: _fmtQtd,
                  cellStyle: dataTextStyle,
                  showVendaGroupingColumns: _mostrarIdVendaTipoPagamento,
                );

                final baseOptions = const <int>[25, 40, 60, 100];
                final options = <int>{...baseOptions, _rowsPerPage}.toList()..sort();

                final showVg = _mostrarIdVendaTipoPagamento;
                final tableColumns = <DataColumn>[
                  const DataColumn(label: Text('Dia')),
                  const DataColumn(label: Text('Código de Barras')),
                  const DataColumn(label: Text('Produto')),
                  const DataColumn(label: Text('Qtd')),
                  const DataColumn(label: Text('Valor unitário')),
                  const DataColumn(label: Text('Valor total')),
                  const DataColumn(label: Text('Desconto')),
                  const DataColumn(label: Text('Valor total venda')),
                  const DataColumn(label: Text('Depósito')),
                  const DataColumn(label: Text('Usuário')),
                  if (showVg) ...[
                    const DataColumn(label: Text('ID venda')),
                    const DataColumn(label: Text('Forma pagamento')),
                  ],
                ];

                return SelectionArea(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Builder(
                      builder: (context) {
                        final mqW = MediaQuery.sizeOf(context).width;
                        final safeW = (c.maxWidth.isFinite && c.maxWidth > 0) ? c.maxWidth : mqW;
                        final tableWidth = showVg
                            ? (safeW < 1500 ? 1500.0 : safeW)
                            : (safeW < 1320 ? 1320.0 : safeW);

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
                                setState(() => _rowsPerPage = v);
                              },
                              header: Text(
                                'Vendas (${data.length})',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      color: AppColors.cream,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              columns: tableColumns,
                              source: source,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          ..._totaisResumo(_linhas!),
        ],
      ],
    );
  }
}

class _SalesReportSource extends DataTableSource {
  _SalesReportSource({
    required this.rows,
    required this.fmtQtd,
    required this.cellStyle,
    required this.showVendaGroupingColumns,
  });

  final List<SaleReportRow> rows;
  final String Function(double) fmtQtd;
  final TextStyle? cellStyle;
  final bool showVendaGroupingColumns;

  @override
  DataRow? getRow(int index) {
    if (index < 0 || index >= rows.length) return null;
    final r = rows[index];
    final style = cellStyle;
    return DataRow(
      cells: [
        DataCell(SelectableText(r.diaDisplay, style: style)),
        DataCell(SelectableText(r.codigoBarra, style: style)),
        DataCell(SelectableText(r.produto, style: style)),
        DataCell(SelectableText(fmtQtd(r.quantidade), style: style)),
        DataCell(SelectableText(
          r.valorUnitario != null ? formatBrl(r.valorUnitario!) : '—',
          style: style,
        )),
        DataCell(SelectableText(
          r.valorTotalLinha != null ? formatBrl(r.valorTotalLinha!) : '—',
          style: style,
        )),
        DataCell(SelectableText(r.desconto ?? '—', style: style)),
        DataCell(SelectableText(
          r.valorTotalVenda != null ? formatBrl(r.valorTotalVenda!) : '—',
          style: style,
        )),
        DataCell(SelectableText(r.deposito, style: style)),
        DataCell(SelectableText(r.usuario, style: style)),
        if (showVendaGroupingColumns) ...[
          DataCell(SelectableText(r.idVenda?.toString() ?? '—', style: style)),
          DataCell(SelectableText(r.tipoPagamento ?? '—', style: style)),
        ],
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => rows.length;

  @override
  int get selectedRowCount => 0;
}
