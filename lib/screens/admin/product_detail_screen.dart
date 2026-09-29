import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../services/products_api.dart';
import '../../theme/app_colors.dart';
import '../../utils/format_money.dart';
import '../../utils/friendly_error_message.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_shell_background.dart';
import '../../widgets/glass_card.dart';

/// Consulta de um produto. O cadastro é feito no Bling e sincronizado com o servidor.
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.codigoInterno});

  final int codigoInterno;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Product? _produto;
  bool _loading = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final p = await ProductsApi.getByCodigoInterno(widget.codigoInterno);
      if (mounted) setState(() => _produto = p);
    } catch (e) {
      if (mounted) setState(() => _loadError = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _campo(IconData icon, String label, String valor) {
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.darkTextMuted, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.labelMedium?.copyWith(color: AppColors.darkTextMuted)),
                const SizedBox(height: 2),
                SelectableText(
                  valor.isEmpty ? '—' : valor,
                  style: theme.bodyLarge?.copyWith(color: AppColors.cream),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _produto;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Produto #${widget.codigoInterno}'),
        backgroundColor: Colors.black.withValues(alpha: 0.35),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppShellBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: _loading && p == null
                  ? const Center(child: AppLoadingIndicator(size: 48))
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_loadError != null) ...[
                            GlassCard(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: AppColors.danger),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _loadError!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: AppColors.darkTextMuted),
                                    ),
                                  ),
                                  TextButton(onPressed: _load, child: const Text('Tentar novamente')),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          GlassCard(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, color: AppColors.cream),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'O cadastro de produtos é feito no Bling. As alterações chegam aqui '
                                    'automaticamente em até 15 minutos.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: AppColors.darkTextMuted),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (p != null) ...[
                            const SizedBox(height: 12),
                            GlassCard(
                              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _campo(Icons.inventory_2_outlined, 'Nome', p.nome),
                                  _campo(Icons.qr_code_2_rounded, 'Código de barras', p.codigoBarra),
                                  _campo(Icons.payments_outlined, 'Preço custo', formatBrl(p.precoCusto)),
                                  _campo(Icons.sell_outlined, 'Preço venda', formatBrl(p.precoVenda)),
                                  _campo(
                                    Icons.toggle_on_rounded,
                                    'Status',
                                    p.isAtivo ? 'Ativo' : 'Inativo',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
