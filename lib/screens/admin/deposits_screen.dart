import 'package:flutter/material.dart';

import '../../models/deposito.dart';
import '../../services/deposits_api.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/glass_card.dart';
import 'deposit_form_screen.dart';

class DepositsScreen extends StatefulWidget {
  const DepositsScreen({super.key});

  @override
  State<DepositsScreen> createState() => _DepositsScreenState();
}

class _DepositsScreenState extends State<DepositsScreen> {
  late Future<List<Deposito>> _future;

  @override
  void initState() {
    super.initState();
    _future = DepositsApi.list();
  }

  Future<void> _refresh() async {
    setState(() => _future = DepositsApi.list());
    await _future;
  }

  Future<void> _openCreate() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const DepositFormScreen.create()),
    );
    if (ok == true) _refresh();
  }

  Future<void> _openEdit(int id) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => DepositFormScreen.edit(depositId: id)),
    );
    if (ok == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Deposito>>(
      future: _future,
      builder: (context, snap) {
        final loading = snap.connectionState != ConnectionState.done;
        final data = snap.data ?? const <Deposito>[];
        final err = snap.error;

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Depósitos cadastrados (API).',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.darkTextMuted),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: loading ? null : _openCreate,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Novo'),
                    style: FilledButton.styleFrom(
                      foregroundColor: AppColors.cream,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ],
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
                          'Erro ao carregar depósitos: $err',
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
                    // grid (tabela) no desktop/web; lista no mobile estreito
                    final useTable = c.maxWidth >= 520;
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
                          child: Text('Nenhum depósito encontrado.', style: TextStyle(color: AppColors.cream)),
                        );
                      }
                      return Column(
                        children: data.map((d) {
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
                                          d.nome,
                                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                color: AppColors.cream,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'ID: ${d.id} · ${d.status}',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: AppColors.darkTextMuted,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Editar',
                                    onPressed: () => _openEdit(d.id),
                                    icon: const Icon(Icons.edit_rounded, color: AppColors.cream),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    }

                    final table = DataTable(
                      headingTextStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.darkTextMuted,
                            fontWeight: FontWeight.w700,
                          ),
                      dataTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.cream),
                      headingRowColor: WidgetStatePropertyAll(Colors.white.withValues(alpha: 0.04)),
                      columns: const [
                        DataColumn(label: Text('ID')),
                        DataColumn(label: Text('Nome')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('')),
                      ],
                      rows: [
                        if (loading)
                          const DataRow(
                            cells: [
                              DataCell(Text('…')),
                              DataCell(AppLoadingIndicator(size: 28)),
                              DataCell(Text('')),
                              DataCell(SizedBox.shrink()),
                            ],
                          )
                        else if (data.isEmpty)
                          const DataRow(
                            cells: [
                              DataCell(Text('-')),
                              DataCell(Text('Nenhum depósito encontrado')),
                              DataCell(Text('-')),
                              DataCell(SizedBox.shrink()),
                            ],
                          )
                        else
                          ...data.map((d) {
                            final statusColor = d.isAtivo ? AppColors.success : AppColors.warning;
                            return DataRow(
                              cells: [
                                DataCell(Text('${d.id}')),
                                DataCell(Text(d.nome)),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      color: statusColor.withValues(alpha: 0.15),
                                    ),
                                    child: Text(
                                      d.status,
                                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                            color: statusColor,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  IconButton(
                                    tooltip: 'Editar',
                                    onPressed: () => _openEdit(d.id),
                                    icon: const Icon(Icons.edit_rounded, color: AppColors.cream),
                                  ),
                                ),
                              ],
                            );
                          }),
                      ],
                    );

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: c.maxWidth),
                        child: table,
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

