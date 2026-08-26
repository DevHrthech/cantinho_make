import 'package:flutter/material.dart';

import '../../services/dashboard_api.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/glass_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.onOpenSaida,
    required this.onOpenEntrada,
  });

  final VoidCallback onOpenSaida;
  final VoidCallback onOpenEntrada;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<DashboardSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = DashboardApi.load();
  }

  Future<void> _reload() async {
    setState(() => _future = DashboardApi.load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardSnapshot>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: AppLoadingIndicator(size: 56));
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      'Não foi possível carregar o painel.',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.cream),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snap.error.toString(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.darkTextMuted),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final data = snap.data!;

        return LayoutBuilder(
          builder: (context, c) {
            final pad = const EdgeInsets.fromLTRB(16, 0, 16, 24);
            final wide = c.maxWidth >= 720;
            return RefreshIndicator(
              onRefresh: _reload,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: pad,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: _TotalVendidoCard(totalFormatado: data.totalFormatado)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MetricCard(
                              title: 'Usuários',
                              value: '${data.usuariosAtivos}',
                              subtitle: 'ativos',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MetricCard(
                              title: 'Depósitos',
                              value: '${data.depositosAtivos}',
                              subtitle: 'ativos',
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _TotalVendidoCard(totalFormatado: data.totalFormatado),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              title: 'Usuários',
                              value: '${data.usuariosAtivos}',
                              subtitle: 'ativos',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MetricCard(
                              title: 'Depósitos',
                              value: '${data.depositosAtivos}',
                              subtitle: 'ativos',
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    _TopProdutosCard(itens: data.topProdutos),
                    const SizedBox(height: 14),
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ações rápidas',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.cream,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: widget.onOpenSaida,
                                icon: const Icon(Icons.output_rounded, size: 20),
                                label: const Text('Venda'),
                                style: FilledButton.styleFrom(
                                  foregroundColor: AppColors.cream,
                                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: widget.onOpenEntrada,
                                icon: const Icon(Icons.input_rounded, size: 20),
                                label: const Text('Entrada de produtos'),
                                style: FilledButton.styleFrom(
                                  foregroundColor: AppColors.cream,
                                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TotalVendidoCard extends StatelessWidget {
  const _TotalVendidoCard({required this.totalFormatado});

  final String totalFormatado;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accentBorder: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Valor total vendido',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.darkTextMuted,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            totalFormatado,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.cream,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.darkTextMuted,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.cream,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.darkTextMuted),
          ),
        ],
      ),
    );
  }
}

class _TopProdutosCard extends StatelessWidget {
  const _TopProdutosCard({required this.itens});

  final List<DashboardTopProduto> itens;

  static String _fmtUn(num u) {
    if (u == u.roundToDouble()) return '${u.toInt()}';
    return u.toStringAsFixed(2).replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Produtos mais vendidos',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.cream,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 14),
          if (itens.isEmpty)
            Text(
              'Nenhuma venda de produto encontrada ainda.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.darkTextMuted),
            )
          else
            ...itens.map((p) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.nome,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.cream,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        Text(
                          '${_fmtUn(p.unidades)} un.',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: AppColors.darkTextMuted,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: p.progress,
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
