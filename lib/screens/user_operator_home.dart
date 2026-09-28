import 'dart:async';

import 'package:flutter/material.dart';

import '../models/session_user.dart';
import '../services/products_sync.dart';
import '../theme/app_colors.dart';
import '../widgets/app_shell_background.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/glass_card.dart';
import 'admin/reports_screen.dart';
import 'pending_stock_list_screen.dart';
import 'stock_operation_screen.dart';

class UserOperatorHome extends StatefulWidget {
  const UserOperatorHome({super.key, required this.user, required this.onLogout});

  final SessionUser user;
  final VoidCallback onLogout;

  @override
  State<UserOperatorHome> createState() => _UserOperatorHomeState();
}

class _UserOperatorHomeState extends State<UserOperatorHome> {
  bool _syncing = false;

  Future<void> _syncProdutos() async {
    if (_syncing) return;
    setState(() => _syncing = true);

    Future<void> showLoading() async {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return PopScope(
            canPop: false,
            child: AlertDialog(
              title: const Text('Atualizando produtos'),
              content: Row(
                children: const [
                  AppLoadingIndicator(size: 36),
                  SizedBox(width: 14),
                  Expanded(child: Text('Sincronizando com o servidor...')),
                ],
              ),
            ),
          );
        },
      );
    }

    void closeLoadingIfOpen() {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }

    Future<bool> showError({
      required String code,
      required String message,
    }) async {
      final retry = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Falha ao atualizar produtos'),
            content: Text(
              'Código: $code\n\n$message\n\n'
              'Verifique sua internet e tente novamente.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Ok'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Tentar novamente'),
              ),
            ],
          );
        },
      );
      return retry ?? false;
    }

    bool retry;
    do {
      retry = false;
      // mostra loading sem "await" pra não bloquear o fluxo
      unawaited(showLoading());

      try {
        final n = await const ProductsSyncService().syncProdutos();
        closeLoadingIfOpen();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Produtos atualizados: $n'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        closeLoadingIfOpen();
        final code = _errorCode(e);
        final msg = _errorMessage(e);
        retry = await showError(code: code, message: msg);
      }
    } while (retry && mounted);

    if (mounted) setState(() => _syncing = false);
  }

  String _errorCode(Object e) {
    // ApiException: ApiException(statusCode: 500, message: ...)
    final s = e.toString();
    final match = RegExp(r'statusCode:\s*(\d+)').firstMatch(s);
    if (match != null) return match.group(1)!;
    return e.runtimeType.toString();
  }

  String _errorMessage(Object e) {
    final s = e.toString();
    // tenta extrair o message do ApiException
    final match = RegExp(r'message:\s*(.*)\)$').firstMatch(s);
    if (match != null) return match.group(1)!.trim();
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppShellBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cantinho Make',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: AppColors.cream,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.user.displayName} · Depósito: ${widget.user.deposito}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.darkTextMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Sair',
                        onPressed: widget.onLogout,
                        icon: const Icon(Icons.logout_rounded, color: AppColors.cream),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Operações',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.cream,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Registre saída ou entrada de produtos por código de barras.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.darkTextMuted,
                    ),
                  ),
                  const SizedBox(height: 22),
                  GlassCard(
                    accentBorder: true,
                    onTap: _syncing ? null : _syncProdutos,
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: AppColors.cream.withValues(alpha: 0.12),
                          ),
                          child: Icon(
                            _syncing ? Icons.sync_rounded : Icons.refresh_rounded,
                            color: AppColors.cream,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Atualizar produtos',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.cream,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _syncing
                                    ? 'Atualizando no banco local...'
                                    : 'Baixar catálogo do servidor para o telefone',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.darkTextMuted,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        if (_syncing)
                          const AppLoadingIndicator(size: 22)
                        else
                          const Icon(Icons.chevron_right_rounded, color: AppColors.cream),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  GlassCard(
                    accentBorder: true,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PendingVendasScreen(),
                        ),
                      );
                    },
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: AppColors.cream.withValues(alpha: 0.12),
                          ),
                          child: const Icon(Icons.cloud_upload_outlined, color: AppColors.cream, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vendas pendentes',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.cream,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Rever e reenviar vendas quando voltar a internet',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.darkTextMuted,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.cream),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  GlassCard(
                    accentBorder: true,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PendingInventariosScreen(),
                        ),
                      );
                    },
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: AppColors.cream.withValues(alpha: 0.12),
                          ),
                          child: const Icon(Icons.inventory_outlined, color: AppColors.cream, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Inventários pendentes',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.cream,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Rever e reenviar inventários salvos neste aparelho',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.darkTextMuted,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.cream),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  GlassCard(
                    accentBorder: true,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => StockOperationScreen(
                            mode: StockOperationMode.saida,
                            user: widget.user,
                          ),
                        ),
                      );
                    },
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: AppColors.cream.withValues(alpha: 0.12),
                          ),
                          child: const Icon(Icons.output_rounded, color: AppColors.cream, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Venda',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.cream,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Baixa de estoque na filial',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.darkTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.cream),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  GlassCard(
                    accentBorder: true,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => StockOperationScreen(
                            mode: StockOperationMode.entrada,
                            user: widget.user,
                          ),
                        ),
                      );
                    },
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: AppColors.cream.withValues(alpha: 0.12),
                          ),
                          child: const Icon(Icons.input_rounded, color: AppColors.cream, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Entrada de produtos',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.cream,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Recebimento ou devolução ao estoque',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.darkTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.cream),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  GlassCard(
                    accentBorder: true,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => Scaffold(
                            extendBodyBehindAppBar: true,
                            appBar: AppBar(
                              title: const Text('Relatório de vendas'),
                              backgroundColor: Colors.black.withValues(alpha: 0.35),
                            ),
                            body: Stack(
                              fit: StackFit.expand,
                              children: [
                                const AppShellBackground(),
                                SafeArea(
                                  child: ReportsScreen(user: widget.user),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: AppColors.cream.withValues(alpha: 0.12),
                          ),
                          child: const Icon(Icons.analytics_outlined, color: AppColors.cream, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Relatório de vendas',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.cream,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Consulte vendas do seu depósito por período',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.darkTextMuted,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.cream),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
