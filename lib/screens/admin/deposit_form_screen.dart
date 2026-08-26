import 'package:flutter/material.dart';

import '../../services/deposits_api.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_shell_background.dart';
import '../../widgets/glass_card.dart';

class DepositFormScreen extends StatefulWidget {
  const DepositFormScreen.create({super.key}) : depositId = null;

  const DepositFormScreen.edit({super.key, required this.depositId});

  final int? depositId;

  bool get isEdit => depositId != null;

  @override
  State<DepositFormScreen> createState() => _DepositFormScreenState();
}

class _DepositFormScreenState extends State<DepositFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nome = TextEditingController();
  String _status = 'Ativo';
  bool _loading = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit) {
      _fetch();
    }
  }

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final d = await DepositsApi.getById(widget.depositId!);
      _nome.text = d.nome;
      _status = _normalizeStatus(d.status);
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

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      if (widget.isEdit) {
        await DepositsApi.update(
          id: widget.depositId!,
          nome: _nome.text.trim(),
          status: _status,
        );
      } else {
        await DepositsApi.create(
          nome: _nome.text.trim(),
          status: _status,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEdit ? 'Depósito atualizado.' : 'Depósito cadastrado.'),
        ),
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
    final title = widget.isEdit ? 'Editar depósito' : 'Cadastrar depósito';
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.black.withValues(alpha: 0.35),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppShellBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: _loading && widget.isEdit && _nome.text.isEmpty
                  ? const Center(child: AppLoadingIndicator(size: 48))
                  : Column(
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
                                TextButton(
                                  onPressed: _fetch,
                                  child: const Text('Tentar novamente'),
                                ),
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
                                  'Dados do depósito',
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
                                    prefixIcon: Icon(Icons.warehouse_rounded),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Informe o nome';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                DropdownButtonFormField<String>(
                                  initialValue: _status,
                                  items: const [
                                    DropdownMenuItem(value: 'Ativo', child: Text('Ativo')),
                                    DropdownMenuItem(value: 'Inativo', child: Text('Inativo')),
                                  ],
                                  onChanged: _loading ? null : (v) => setState(() => _status = v ?? 'Ativo'),
                                  dropdownColor: AppColors.darkCardElevated,
                                  style: const TextStyle(color: AppColors.cream),
                                  decoration: const InputDecoration(
                                    labelText: 'Status',
                                    prefixIcon: Icon(Icons.toggle_on_rounded),
                                  ),
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
        ],
      ),
    );
  }
}

