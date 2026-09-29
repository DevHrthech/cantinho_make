import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/scanned_line.dart';
import '../models/session_user.dart';
import '../services/products_lookup.dart';
import '../services/stock_submit.dart';
import '../theme/app_colors.dart';
import '../utils/format_money.dart';
import '../utils/friendly_error_message.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/app_shell_background.dart';
import '../widgets/glass_card.dart';
import 'barcode_scanner_screen.dart';

enum StockOperationMode { saida, entrada }

class StockOperationScreen extends StatefulWidget {
  const StockOperationScreen({super.key, required this.mode, required this.user});

  final StockOperationMode mode;
  final SessionUser user;

  @override
  State<StockOperationScreen> createState() => _StockOperationScreenState();
}

class _StockOperationScreenState extends State<StockOperationScreen> {
  static const _formasPagamento = ['PIX', 'Dinheiro', 'Crédito', 'Débito'];
  // Até 4x: é o que está cadastrado no Bling.
  static const _parcelasOpcoes = ['Avista', '2X', '3X', '4X'];
  static const _descontoOpcoes = ['Não', 'Sim'];
  static const _descontoTipoOpcoes = <String>['Porcentagem', r'Valor (R$)'];

  final List<ScannedLine> _lines = [];
  bool _resolving = false;
  bool _submitting = false;
  final TextEditingController _descontoValorCtrl = TextEditingController();
  final TextEditingController _valorRecebidoCtrl = TextEditingController();

  String _formaPagamentoFeira = _formasPagamento.first;
  String _parcelasFeira = _parcelasOpcoes.first;
  String _desconto = _descontoOpcoes.first;
  String _descontoTipo = _descontoTipoOpcoes.first;

  String get _title =>
      widget.mode == StockOperationMode.saida ? 'Venda' : 'Entrada de produtos';

  String get _hint => widget.mode == StockOperationMode.saida
      ? 'Leia os códigos para registrar a venda. O envio ao estoque central será integrado depois.'
      : 'Leia os códigos para registrar a entrada. A conferência com o depósito central virá depois.';

  String _tipoPagamentoFeiraParaRegistro() {
    if (_formaPagamentoFeira == 'Crédito') {
      return 'Crédito - $_parcelasFeira';
    }
    return _formaPagamentoFeira;
  }

  Future<void> _openScanner() async {
    final code = await Navigator.of(context).push<String?>(
      PageRouteBuilder<String?>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const BarcodeScannerScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
    if (!mounted || code == null || code.isEmpty) return;
    await _addBarcode(code);
  }

  @override
  void dispose() {
    _descontoValorCtrl.dispose();
    _valorRecebidoCtrl.dispose();
    super.dispose();
  }

  double get _total =>
      _lines.fold<double>(0, (sum, l) => sum + l.lineTotal);

  double _descontoValorNumerico() {
    if (_desconto != 'Sim') return 0;
    if (_descontoTipo.startsWith('Porcentagem')) {
      final raw = _descontoValorCtrl.text.trim().replaceAll(',', '.');
      final n = double.tryParse(raw) ?? 0;
      if (n <= 0) return 0;
      return (_total * (n / 100.0)).clamp(0, _total).toDouble();
    }
    final digits = _descontoValorCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0;
    final cents = int.tryParse(digits) ?? 0;
    final n = cents / 100.0;
    if (n <= 0) return 0;
    return n.clamp(0, _total).toDouble();
  }

  String? _descontoFormatadoParaRegistro() {
    if (_desconto != 'Sim') return null;
    final v = _descontoValorNumerico();
    if (v <= 0) return null;
    return 'R\$${v.toStringAsFixed(2)}';
  }

  double get _totalComDesconto {
    final d = _descontoValorNumerico();
    return (_total - d).clamp(0, double.infinity).toDouble();
  }

  double? _valorRecebidoNumerico() {
    final raw = _valorRecebidoCtrl.text
        .replaceAll(RegExp(r'[^0-9]'), '')
        .trim();
    if (raw.isEmpty) return null;
    final cents = int.tryParse(raw);
    if (cents == null) return null;
    return cents / 100.0;
  }

  void _formatarValorRecebido(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      _valorRecebidoCtrl.value = const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
      return;
    }
    final cents = int.parse(digits);
    final formatted = (cents / 100).toStringAsFixed(2);
    final buf = StringBuffer();
    final intPart = formatted.split('.').first;
    final decPart = formatted.split('.').last;
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write('.');
      buf.write(intPart[i]);
    }
    final text = 'R\$ $buf,$decPart';
    _valorRecebidoCtrl.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _formatarValorDesconto(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      _descontoValorCtrl.value = const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
      return;
    }
    final cents = int.parse(digits);
    final formatted = (cents / 100).toStringAsFixed(2);
    final buf = StringBuffer();
    final intPart = formatted.split('.').first;
    final decPart = formatted.split('.').last;
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write('.');
      buf.write(intPart[i]);
    }
    final text = 'R\$ $buf,$decPart';
    _descontoValorCtrl.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _mergeProductIntoLines(ProductRecord product) {
    setState(() {
      final i = _lines.indexWhere((e) => e.barcode == product.codigoBarras);
      if (i >= 0) {
        final cur = _lines[i];
        _lines[i] = cur.copyWith(quantity: cur.quantity + 1);
      } else {
        _lines.add(
          ScannedLine(
            barcode: product.codigoBarras,
            name: product.nome,
            unitPrice: product.precoVenda,
            quantity: 1,
            codigoInterno: product.codigoInterno,
          ),
        );
      }
    });
  }

  Future<ProductRecord?> _pickProductDialog(List<ProductRecord> candidates, String scanned) async {
    return showDialog<ProductRecord>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Vários produtos com este código'),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.sizeOf(ctx).height * 0.45,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Lido: $scanned\nToque no item correto.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: AppColors.darkTextMuted),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: candidates.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final p = candidates[i];
                    return ListTile(
                      dense: true,
                      title: Text(
                        p.nome,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.cream, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        p.codigoBarras,
                        style: const TextStyle(color: AppColors.darkTextMuted, fontSize: 12),
                      ),
                      onTap: () => Navigator.pop(ctx, p),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        ],
      ),
    );
  }

  Future<void> _handleBarcodeNotFound(String barcode) async {
    final action = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Produto não encontrado'),
        content: Text(
          'Código: $barcode\n\n'
          'Confira o código, atualize a lista de produtos ou busque pelo nome.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'ok'), child: const Text('Ok')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'search'),
            child: const Text('Buscar por nome'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'search') await _openSearchByNameDialog();
  }

  Future<void> _openSearchByNameDialog() async {
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Busca por nome está disponível apenas no aplicativo mobile.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final picked = await showDialog<ProductRecord?>(
      context: context,
      useRootNavigator: true,
      builder: (dialogCtx) => const _SearchProductDialog(),
    );

    if (!mounted) return;
    if (picked != null) _mergeProductIntoLines(picked);
  }

  Future<void> _addBarcode(String raw) async {
    final barcode = raw.trim();
    if (barcode.isEmpty) return;

    setState(() => _resolving = true);
    try {
      final matches = await const ProductsLookupService().findProductsMatchingBarcode(barcode);
      if (!mounted) return;

      if (matches.isEmpty) {
        await _handleBarcodeNotFound(barcode);
        return;
      }
      if (matches.length == 1) {
        _mergeProductIntoLines(matches.first);
        return;
      }
      final chosen = await _pickProductDialog(matches, barcode);
      if (!mounted || chosen == null) return;
      _mergeProductIntoLines(chosen);
    } catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Erro ao buscar produto'),
          content: Text('Código: ${e.runtimeType}\n\n$e'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Ok')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _addBarcode(barcode);
              },
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  void _clear() {
    if (_lines.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar lista?'),
        content: const Text('Todos os itens lidos nesta sessão serão removidos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(_lines.clear);
            },
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
  }

  Future<void> _concludeOperation() async {
    if (_lines.isEmpty || _submitting) return;

    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Gravar venda/inventário no servidor está disponível apenas no aplicativo mobile.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Validação: em Dinheiro, se houver valor recebido, ele não pode ser negativo.
    if (_formaPagamentoFeira == 'Dinheiro') {
      final vr = _valorRecebidoNumerico();
      if (vr != null && vr < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Valor recebido não pode ser negativo.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      final svc = const StockSubmitService();
      String? tipoPagamento;
      double? valorRecebido;
      String? desconto;
      if (widget.mode == StockOperationMode.saida) {
        tipoPagamento = _tipoPagamentoFeiraParaRegistro();
        if (_formaPagamentoFeira == 'Dinheiro') {
          valorRecebido = _valorRecebidoNumerico();
        }
        desconto = _descontoFormatadoParaRegistro();
      }

      final outcome = widget.mode == StockOperationMode.saida
          ? await svc.concludeSaida(
              user: widget.user,
              lines: List<ScannedLine>.of(_lines),
              tipoPagamento: tipoPagamento,
              valorRecebido: valorRecebido,
              desconto: desconto,
            )
          : await svc.concludeEntrada(user: widget.user, lines: List<ScannedLine>.of(_lines));

      if (!mounted) return;

      if (outcome.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.mode == StockOperationMode.saida
                  ? 'Venda registrada e enviada.'
                  : 'Inventário registrado e enviado.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Não foi possível enviar agora'),
          content: Text(
            'Os dados foram salvos neste aparelho e podem ser reenviados depois.\n\n'
            '${friendlyErrorMessageFromString(outcome.message ?? '')}',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Ok')),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openEditPriceDialog(ScannedLine item, int index) async {
    if (!mounted) return;
    
    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) => _EditPriceDialog(initialPrice: item.unitPrice),
    );

    if (result != null && mounted) {
      setState(() {
        _lines[index] = item.copyWith(unitPrice: result);
      });
    }
  }

  int _crossAxisCount(double width) {
    if (width >= 1100) return 4;
    if (width >= 800) return 3;
    if (width >= 520) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: Colors.black.withValues(alpha: 0.35),
      ),
      bottomNavigationBar: _lines.isEmpty
          ? null
          : SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                child: GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.mode == StockOperationMode.saida) ...[
                        Row(
                          children: [
                            Text(
                              'Valor Total',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: AppColors.creamDeep,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const Spacer(),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: Text(
                                formatBrl(_total),
                                key: ValueKey('total_${_total.toStringAsFixed(2)}'),
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: AppColors.cream,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        if (_desconto == 'Sim' && _descontoValorNumerico() > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'Desconto',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.darkTextMuted,
                                    ),
                              ),
                              const Spacer(),
                              Text(
                                '- ${formatBrl(_descontoValorNumerico())}',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppColors.cream,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                'Total com desconto',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      color: AppColors.creamDeep,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const Spacer(),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: Text(
                                  formatBrl(_totalComDesconto),
                                  key: ValueKey('td_${_totalComDesconto.toStringAsFixed(2)}'),
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: AppColors.cream,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Desconto',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: AppColors.creamDeep,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          key: ValueKey<String>('desconto_$_desconto'),
                          initialValue: _desconto,
                          items: _descontoOpcoes
                              .map(
                                (e) => DropdownMenuItem<String>(
                                  value: e,
                                  child: Text(e),
                                ),
                              )
                              .toList(),
                          onChanged: _submitting
                              ? null
                              : (v) => setState(() {
                                    _desconto = v ?? _descontoOpcoes.first;
                                  }),
                          dropdownColor: AppColors.darkCardElevated,
                          style: const TextStyle(color: AppColors.cream),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                        if (_desconto == 'Sim') ...[
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            key: ValueKey<String>('desconto_tipo_$_descontoTipo'),
                            initialValue: _descontoTipo,
                            items: _descontoTipoOpcoes
                                .map(
                                  (e) => DropdownMenuItem<String>(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                            onChanged: _submitting
                                ? null
                                : (v) => setState(() {
                                      _descontoTipo = v ?? _descontoTipoOpcoes.first;
                                    }),
                            dropdownColor: AppColors.darkCardElevated,
                            style: const TextStyle(color: AppColors.cream),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _descontoValorCtrl,
                            enabled: !_submitting,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: AppColors.cream),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: _descontoTipo.startsWith('Porcentagem')
                                  ? 'Ex.: 10 (para 10%)'
                                : r'Ex.: 5,00',
                              labelText: _descontoTipo.startsWith('Porcentagem')
                                  ? 'Desconto (%)'
                                : r'Desconto (R$)',
                              labelStyle: const TextStyle(color: AppColors.creamDeep),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                            onChanged: (v) {
                              if (_descontoTipo.startsWith('Valor')) {
                                _formatarValorDesconto(v);
                              }
                              setState(() {});
                            },
                          ),
                        ],
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Forma de Pagamento',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: AppColors.creamDeep,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          key: ValueKey<String>('fp_$_formaPagamentoFeira'),
                          initialValue: _formaPagamentoFeira,
                          items: _formasPagamento
                              .map(
                                (e) => DropdownMenuItem<String>(
                                  value: e,
                                  child: Text(e),
                                ),
                              )
                              .toList(),
                          onChanged: _submitting
                              ? null
                              : (v) => setState(() {
                                    _formaPagamentoFeira = v ?? _formasPagamento.first;
                                    if (_formaPagamentoFeira == 'Crédito') {
                                      _parcelasFeira = _parcelasOpcoes.first;
                                    }
                                  }),
                          dropdownColor: AppColors.darkCardElevated,
                          style: const TextStyle(color: AppColors.cream),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                        if (_formaPagamentoFeira == 'Crédito') ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Parcelas',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: AppColors.creamDeep,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            key: const ValueKey<String>('parcelas_dropdown'),
                            initialValue: _parcelasFeira,
                            items: _parcelasOpcoes
                                .map(
                                  (e) => DropdownMenuItem<String>(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                            onChanged: _submitting
                                ? null
                                : (v) => setState(
                                      () => _parcelasFeira = v ?? _parcelasOpcoes.first,
                                    ),
                            dropdownColor: AppColors.darkCardElevated,
                            style: const TextStyle(color: AppColors.cream),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ],
                        if (_formaPagamentoFeira == 'Dinheiro') ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: _valorRecebidoCtrl,
                            enabled: !_submitting,
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: AppColors.cream),
                            decoration: const InputDecoration(
                              isDense: true,
                              labelText: r'Valor recebido (R$)',
                              labelStyle: TextStyle(color: AppColors.creamDeep),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                            onChanged: (v) {
                              _formatarValorRecebido(v);
                              setState(() {});
                            },
                          ),
                          Builder(builder: (context) {
                            final recebido = _valorRecebidoNumerico();
                            if (recebido == null) return const SizedBox.shrink();
                            final diff = recebido - _totalComDesconto;
                            if (diff.abs() < 0.005) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Valor exato',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: AppColors.cream),
                                  ),
                                ),
                              );
                            }
                            if (diff > 0) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Troco: ${formatBrl(diff)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: const Color(0xFF6FE39A),
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                              );
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Falta: ${formatBrl(-diff)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: const Color(0xFFFF6B6B),
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                            );
                          }),
                        ],
                        const SizedBox(height: 10),
                      ] else ...[
                        Row(
                          children: [
                            Text(
                              'Valor Total',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: AppColors.creamDeep,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const Spacer(),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: Text(
                                formatBrl(_total),
                                key: ValueKey(_total.toStringAsFixed(2)),
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: AppColors.cream,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: _submitting ? null : _concludeOperation,
                              child: _submitting
                                  ? const AppLoadingIndicator(size: 24)
                                  : Text(
                                      widget.mode == StockOperationMode.saida
                                          ? 'Concluir Venda'
                                          : 'Concluir Inventário',
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppShellBackground(),
          LayoutBuilder(
            builder: (context, constraints) {
              final cross = _crossAxisCount(constraints.maxWidth);
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        MediaQuery.paddingOf(context).top + kToolbarHeight + 12,
                        20,
                        8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _hint,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.darkTextMuted,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _ScanCTA(onScan: _openScanner, busy: _resolving),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              if (!kIsWeb) ...[
                                TextButton.icon(
                                  onPressed: _resolving ? null : _openSearchByNameDialog,
                                  icon: const Icon(Icons.search_rounded, color: AppColors.cream),
                                  label: const Text('Buscar nome'),
                                ),
                                const Spacer(),
                              ] else
                                const Spacer(),
                              if (_lines.isNotEmpty)
                                TextButton.icon(
                                  onPressed: _resolving ? null : _clear,
                                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.cream),
                                  label: const Text('Limpar'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                'Produtos lidos',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.cream,
                                ),
                              ),
                              const Spacer(),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                child: Text(
                                  '${_lines.length}',
                                  key: ValueKey(_lines.length),
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.cream,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  _lines.isEmpty
                      ? SliverFillRemaining(
                          child: Center(
                            child: Text(
                              'Nenhum produto lido ainda.',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppColors.darkTextMuted,
                              ),
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                          sliver: SliverGrid(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cross,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 1.8,
                            ),
                            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = _lines[index];
                return GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Nome e botões de editar/excluir
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      color: AppColors.cream,
                                      fontWeight: FontWeight.w700,
                                    ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.cream),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _openEditPriceDialog(item, index),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.cream),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    setState(() {
                                      _lines.removeAt(index);
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Código de barras
                        Text(
                          item.barcode,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.darkTextMuted,
                              ),
                        ),
                        const Spacer(),
                        // Botões de quantidade e valores
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Botões de quantidade
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, size: 24, color: AppColors.cream),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    setState(() {
                                      if (item.quantity > 1) {
                                        _lines[index] = item.copyWith(
                                          quantity: item.quantity - 1,
                                        );
                                      } else {
                                        _lines.removeAt(index);
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${item.quantity}',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: AppColors.cream,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, size: 24, color: AppColors.cream),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    setState(() {
                                      _lines[index] = item.copyWith(
                                        quantity: item.quantity + 1,
                                      );
                                    });
                                  },
                                ),
                              ],
                            ),
                            // Valores
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Preço: ${formatBrl(item.unitPrice)}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppColors.cream,
                                      ),
                                ),
                                Text(
                                  formatBrl(item.lineTotal),
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        color: AppColors.cream,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: _lines.length,
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

class _SearchProductDialog extends StatefulWidget {
  const _SearchProductDialog();

  @override
  State<_SearchProductDialog> createState() => __SearchProductDialogState();
}

class __SearchProductDialogState extends State<_SearchProductDialog> {
  final TextEditingController _ctrl = TextEditingController();
  List<ProductRecord> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.length < 2) {
      setState(() {
        _error = 'Digite pelo menos 2 letras.';
        _results = [];
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await const ProductsLookupService().searchProductsByName(q);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _results = list;
        if (list.isEmpty) {
          _error = 'Nenhum produto com esse nome.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _results = [];
        _error = friendlyErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Buscar por nome'),
      content: SizedBox(
        width: double.maxFinite,
        height: 380,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _ctrl,
              style: const TextStyle(color: AppColors.cream),
              decoration: InputDecoration(
                hintText: 'Ex.: corretivo matte',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _loading ? null : _search,
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: AppColors.cream.withValues(alpha: 0.85)),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: _results.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final p = _results[i];
                  return ListTile(
                    dense: true,
                    title: Text(
                      p.nome,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.cream,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      p.codigoBarras,
                      style: const TextStyle(
                        color: AppColors.darkTextMuted,
                        fontSize: 12,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, p),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}

class _EditPriceDialog extends StatefulWidget {
  final double initialPrice;
  const _EditPriceDialog({required this.initialPrice});

  @override
  State<_EditPriceDialog> createState() => __EditPriceDialogState();
}

class __EditPriceDialogState extends State<_EditPriceDialog> {
  late TextEditingController _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: _formatarPrecoParaExibicao(widget.initialPrice),
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  String _formatarPrecoParaExibicao(double price) {
    final cents = (price * 100).toInt();
    final formatted = (cents / 100).toStringAsFixed(2);
    final buf = StringBuffer();
    final intPart = formatted.split('.').first;
    final decPart = formatted.split('.').last;
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write('.');
      buf.write(intPart[i]);
    }
    return 'R\$ $buf,$decPart';
  }

  void _formatarCampoPreco(String raw, TextEditingController controller) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      controller.value = const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
      return;
    }
    final cents = int.parse(digits);
    final formatted = (cents / 100).toStringAsFixed(2);
    final buf = StringBuffer();
    final intPart = formatted.split('.').first;
    final decPart = formatted.split('.').last;
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write('.');
      buf.write(intPart[i]);
    }
    final text = 'R\$ $buf,$decPart';
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  double? _parsePrecoNumerico(String formattedPrice) {
    final raw = formattedPrice.replaceAll(RegExp(r'[^0-9]'), '').trim();
    if (raw.isEmpty) return null;
    final cents = int.tryParse(raw);
    if (cents == null) return null;
    return cents / 100.0;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar Preço'),
      content: TextField(
        controller: _priceController,
        onChanged: (raw) => _formatarCampoPreco(raw, _priceController),
        keyboardType: TextInputType.number,
        style: const TextStyle(color: AppColors.cream),
        decoration: const InputDecoration(
          labelText: 'Novo Preço (R\$)',
          labelStyle: TextStyle(color: AppColors.creamDeep),
          hintText: 'Ex.: R\$ 29,99',
        ),
      ),
      backgroundColor: AppColors.darkCardElevated,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final newPrice = _parsePrecoNumerico(_priceController.text);
            if (newPrice != null && newPrice > 0) {
              Navigator.pop(context, newPrice);
            }
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

class _ScanCTA extends StatelessWidget {
  const _ScanCTA({required this.onScan, required this.busy});

  final VoidCallback onScan;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      onPressed: busy ? null : onScan,
      icon: busy
          ? const AppLoadingIndicator(size: 20)
          : const Icon(Icons.barcode_reader),
      label: Text(busy ? 'Buscando produto...' : 'Escanear Código de Barras'),
    );
  }
}
