import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/pending_batch_row.dart';
import '../services/stock_submit.dart';
import '../theme/app_colors.dart';
import '../utils/friendly_error_message.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/app_shell_background.dart';
import '../widgets/glass_card.dart';

/// Lista vendas salvas localmente que ainda não foram confirmadas no servidor (`send <> Sim`).
class PendingVendasScreen extends StatelessWidget {
  const PendingVendasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PendingStockListScreen(isVenda: true);
  }
}

/// Lista inventários/entradas pendentes de envio.
class PendingInventariosScreen extends StatelessWidget {
  const PendingInventariosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PendingStockListScreen(isVenda: false);
  }
}

class PendingStockListScreen extends StatefulWidget {
  const PendingStockListScreen({super.key, required this.isVenda});

  final bool isVenda;

  @override
  State<PendingStockListScreen> createState() => _PendingStockListScreenState();
}

class _PendingStockListScreenState extends State<PendingStockListScreen> {
  final _svc = const StockSubmitService();
  Future<List<PendingBatchRow>>? _future;
  bool _sending = false;

  String get _title =>
      widget.isVenda ? 'Vendas pendentes' : 'Inventários pendentes';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future =
          widget.isVenda ? _svc.listPendingVendas() : _svc.listPendingInventarios();
    });
  }

  Future<void> _retryOne(PendingBatchRow row) async {
    if (kIsWeb || _sending) return;
    setState(() => _sending = true);
    try {
      final r =
          await _svc.retryBatch(isVenda: widget.isVenda, batchId: row.batchId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            r.success
                ? 'Lote enviado com sucesso.'
                : 'Falha: ${friendlyErrorMessageFromString(r.message ?? '')}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
      _reload();
    }
  }

  Future<void> _retryAll(List<PendingBatchRow> rows) async {
    if (kIsWeb || _sending || rows.isEmpty) return;
    setState(() => _sending = true);
    var ok = 0;
    var fail = 0;
    try {
      for (final row in rows) {
        final r =
            await _svc.retryBatch(isVenda: widget.isVenda, batchId: row.batchId);
        if (r.success) {
          ok++;
        } else {
          fail++;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enviados: $ok · Com falha: $fail'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: Colors.black.withValues(alpha: 0.35),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppShellBackground(),
          FutureBuilder<List<PendingBatchRow>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: AppLoadingIndicator(size: 48));
              }
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Erro ao carregar: ${snap.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.cream),
                    ),
                  ),
                );
              }
              final rows = snap.data ?? const <PendingBatchRow>[];
              if (kIsWeb) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Pendências ficam disponíveis apenas no aplicativo mobile.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.cream),
                    ),
                  ),
                );
              }
              if (rows.isEmpty) {
                return Center(
                  child: Text(
                    'Nenhuma pendência.',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: AppColors.cream),
                  ),
                );
              }
              return Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        MediaQuery.paddingOf(context).top + kToolbarHeight + 12,
                        20,
                        12,
                      ),
                      itemCount: rows.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final row = rows[i];
                        return GlassCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '${row.dia} · ${row.itemCount} ${row.itemCount == 1 ? 'item' : 'itens'}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: AppColors.cream,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Lote: ${row.batchId}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.darkTextMuted),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                row.usuario,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.darkTextMuted),
                              ),
                              Text(
                                'Depósito: ${row.deposito}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.darkTextMuted),
                              ),
                              if (row.httpStatus != null ||
                                  row.lastError != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'Última tentativa de envio',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(
                                        color: AppColors.creamDeep,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                if (row.httpStatus != null)
                                  Text(
                                    'Código HTTP: ${row.httpStatus}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: AppColors.cream),
                                  ),
                                if (row.lastError != null)
                                  Text(
                                    friendlyErrorMessageFromString(row.lastError!),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AppColors.darkTextMuted,
                                          height: 1.35,
                                        ),
                                  ),
                              ],
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed:
                                      _sending ? null : () => _retryOne(row),
                                  child: const Text('Reenviar este lote'),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: FilledButton(
                        onPressed: _sending ? null : () => _retryAll(rows),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: _sending
                            ? const AppLoadingIndicator(size: 24)
                            : Text(
                                widget.isVenda
                                    ? 'Enviar todas as vendas pendentes'
                                    : 'Enviar todos os inventários pendentes',
                              ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
