import 'package:flutter/material.dart';

import '../../services/products_api.dart';
import '../../theme/app_colors.dart';
import '../../utils/format_money.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_shell_background.dart';
import '../../widgets/glass_card.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen.edit({super.key, required this.codigoInterno});

  final int codigoInterno;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _nomeAbreviado = TextEditingController();
  final _codigoBarra = TextEditingController();
  final _precoCusto = TextEditingController();
  final _precoVenda = TextEditingController();

  String _status = 'Ativo';
  bool _loading = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nome.dispose();
    _nomeAbreviado.dispose();
    _codigoBarra.dispose();
    _precoCusto.dispose();
    _precoVenda.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final p = await ProductsApi.getByCodigoInterno(widget.codigoInterno);
      _nome.text = p.nome;
      _nomeAbreviado.text = p.nomeAbreviado;
      _codigoBarra.text = p.codigoBarra;
      _precoCusto.text = _moneyText(p.precoCusto);
      _precoVenda.text = _moneyText(p.precoVenda);
      _status = _normalizeStatus(p.status);
    } catch (e) {
      _loadError = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _normalizeStatus(String s) {
    final v = s.trim().toLowerCase();
    if (v == 'inativo' || v == '0' || v == 'false') return 'Inativo';
    return 'Ativo';
  }

  String _moneyText(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

  double _parseMoney(String input) {
    var s = input.trim();
    if (s.isEmpty) return 0;
    s = s.replaceAll(RegExp(r'[^0-9,.-]'), '');
    if (s.contains(',') && s.contains('.')) {
      // Se vier "1.234,56" remove separador de milhar.
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      s = s.replaceAll(',', '.');
    }
    return double.tryParse(s) ?? 0;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final pc = _parseMoney(_precoCusto.text);
    final pv = _parseMoney(_precoVenda.text);

    setState(() => _loading = true);
    try {
      await ProductsApi.update(
        codigoInterno: widget.codigoInterno,
        nome: _nome.text.trim(),
        nomeAbreviado: _nomeAbreviado.text.trim(),
        codigoBarra: _codigoBarra.text.trim(),
        precoCusto: pc,
        precoVenda: pv,
        status: _status,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produto atualizado.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Editar produto #${widget.codigoInterno}'),
        backgroundColor: Colors.black.withValues(alpha: 0.35),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppShellBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: _loading && _loadError == null && _nome.text.isEmpty
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
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Dados do produto',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.cream,
                                        ),
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _nome,
                                    style: const TextStyle(color: AppColors.cream),
                                    decoration: const InputDecoration(
                                      labelText: 'Nome',
                                      prefixIcon: Icon(Icons.inventory_2_outlined),
                                    ),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _nomeAbreviado,
                                    style: const TextStyle(color: AppColors.cream),
                                    decoration: const InputDecoration(
                                      labelText: 'Nome abreviado',
                                      prefixIcon: Icon(Icons.short_text_rounded),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _codigoBarra,
                                    style: const TextStyle(color: AppColors.cream),
                                    decoration: const InputDecoration(
                                      labelText: 'Código de barras',
                                      prefixIcon: Icon(Icons.qr_code_2_rounded),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _precoCusto,
                                          keyboardType: const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                          style: const TextStyle(color: AppColors.cream),
                                          decoration: const InputDecoration(
                                            labelText: 'Preço custo',
                                            prefixIcon: Icon(Icons.payments_outlined),
                                          ),
                                          validator: (v) => (v == null || v.trim().isEmpty)
                                              ? 'Informe o preço custo'
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _precoVenda,
                                          keyboardType: const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                          style: const TextStyle(color: AppColors.cream),
                                          decoration: const InputDecoration(
                                            labelText: 'Preço venda',
                                            prefixIcon: Icon(Icons.sell_outlined),
                                          ),
                                          validator: (v) => (v == null || v.trim().isEmpty)
                                              ? 'Informe o preço venda'
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  DropdownButtonFormField<String>(
                                    initialValue: _status,
                                    items: const [
                                      DropdownMenuItem(value: 'Ativo', child: Text('Ativo')),
                                      DropdownMenuItem(value: 'Inativo', child: Text('Inativo')),
                                    ],
                                    onChanged: _loading
                                        ? null
                                        : (v) => setState(() => _status = v ?? 'Ativo'),
                                    dropdownColor: AppColors.darkCardElevated,
                                    style: const TextStyle(color: AppColors.cream),
                                    decoration: const InputDecoration(
                                      labelText: 'Status',
                                      prefixIcon: Icon(Icons.toggle_on_rounded),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Builder(
                                    builder: (context) {
                                      final pc = _parseMoney(_precoCusto.text);
                                      final pv = _parseMoney(_precoVenda.text);
                                      return Text(
                                        'Prévia: custo ${formatBrl(pc)} · venda ${formatBrl(pv)}',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: AppColors.darkTextMuted,
                                            ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 18),
                                  FilledButton.icon(
                                    onPressed: _loading ? null : _save,
                                    icon: _loading
                                        ? const AppLoadingIndicator(size: 22)
                                        : const Icon(Icons.save_rounded),
                                    label: Text(_loading ? 'Salvando…' : 'Salvar'),
                                  ),
                                ],
                              ),
                            ),
                          ),
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

