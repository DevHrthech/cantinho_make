import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import '../../models/deposito.dart';
import '../../services/deposits_api.dart';
import '../../services/users_api.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_shell_background.dart';
import '../../widgets/glass_card.dart';

class UserFormScreen extends StatefulWidget {
  const UserFormScreen.create({super.key}) : idUsuario = null;

  const UserFormScreen.edit({super.key, required this.idUsuario});

  final int? idUsuario;

  bool get isEdit => idUsuario != null;

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _telefone = TextEditingController();
  final _cpf = TextEditingController();
  final _cidade = TextEditingController();
  final _senha = TextEditingController();

  final _maskTelefone = MaskTextInputFormatter(mask: '(##) #####-####');
  final _maskCpf = MaskTextInputFormatter(mask: '###.###.###-##');

  List<Deposito> _depositos = const [];
  /// Salva o **nome** do depósito (no banco o campo `deposito` guarda o nome).
  String? _depositoNome;
  String _perfil = 'Usuario';
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
    _email.dispose();
    _telefone.dispose();
    _cpf.dispose();
    _cidade.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      // dropdown depósitos
      _depositos = await DepositsApi.list();

      if (widget.isEdit) {
        final u = await UsersApi.getById(widget.idUsuario!);
        _nome.text = u.nome;
        _email.text = u.email;
        _telefone.text = u.telefone;
        _cpf.text = u.cpf;
        _cidade.text = u.cidade;
        _perfil = _normalizePerfil(u.perfil);
        _status = _normalizeStatus(u.status);

        // tenta casar pelo id (string) ou pelo nome
        final rawDep = u.deposito.trim();
        _depositoNome = _pickDepositoNome(rawDep);
      } else {
        _perfil = 'Usuario';
        _status = 'Ativo';
        _depositoNome = _depositos.isNotEmpty ? _depositos.first.nome : null;
        // senha default sugerida
        _senha.text = '123456';
      }
    } catch (e) {
      _loadError = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _pickDepositoNome(String raw) {
    if (_depositos.isEmpty) return null;
    final byId = _depositos.where((d) => '${d.id}' == raw).toList();
    if (byId.isNotEmpty) return byId.first.nome;
    final byNome = _depositos
        .where((d) => d.nome.trim().toLowerCase() == raw.toLowerCase())
        .toList();
    if (byNome.isNotEmpty) return byNome.first.nome;
    return _depositos.first.nome;
  }

  String _normalizePerfil(String v) {
    final s = v.trim().toLowerCase();
    if (s == 'administrador' || s == 'admin') return 'Administrador';
    if (s == 'feira') return 'Feira';
    return 'Usuario';
  }

  String _normalizeStatus(String s) {
    final v = s.trim().toLowerCase();
    if (v == 'inativo' || v == '0' || v == 'false') return 'Inativo';
    return 'Ativo';
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_depositoNome == null || _depositoNome!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um depósito.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      if (widget.isEdit) {
        await UsersApi.update(
          idUsuario: widget.idUsuario!,
          nome: _nome.text.trim(),
          email: _email.text.trim(),
          senha: _senha.text.trim().isEmpty ? null : _senha.text.trim(),
          telefone: _telefone.text.trim(),
          cpf: _cpf.text.trim(),
          cidade: _cidade.text.trim(),
          deposito: _depositoNome!,
          perfil: _perfil,
          status: _status,
        );
      } else {
        await UsersApi.create(
          nome: _nome.text.trim(),
          email: _email.text.trim(),
          senha: _senha.text.trim(),
          telefone: _telefone.text.trim(),
          cpf: _cpf.text.trim(),
          cidade: _cidade.text.trim(),
          deposito: _depositoNome!,
          perfil: _perfil,
          status: _status,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEdit ? 'Usuário atualizado.' : 'Usuário cadastrado.'),
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

  Widget _twoCol(
    BuildContext context, {
    required BoxConstraints constraints,
    required Widget left,
    required Widget right,
  }) {
    final wide = constraints.maxWidth >= 760;
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          left,
          const SizedBox(height: 14),
          right,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 14),
        Expanded(child: right),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEdit ? 'Editar usuário' : 'Cadastrar usuário';

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
              child: _loading && _depositos.isEmpty && _loadError == null
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
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'Dados do usuário',
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.cream,
                                            ),
                                      ),
                                      const SizedBox(height: 14),
                                      _twoCol(
                                        context,
                                        constraints: constraints,
                                        left: TextFormField(
                                          controller: _nome,
                                          style: const TextStyle(color: AppColors.cream),
                                          decoration: const InputDecoration(
                                            labelText: 'Nome',
                                            prefixIcon: Icon(Icons.badge_outlined),
                                          ),
                                          validator: (v) => (v == null || v.trim().isEmpty)
                                              ? 'Informe o nome'
                                              : null,
                                        ),
                                        right: TextFormField(
                                          controller: _email,
                                          style: const TextStyle(color: AppColors.cream),
                                          decoration: const InputDecoration(
                                            labelText: 'Email',
                                            prefixIcon: Icon(Icons.alternate_email_rounded),
                                          ),
                                          validator: (v) => (v == null || v.trim().isEmpty)
                                              ? 'Informe o email'
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      _twoCol(
                                        context,
                                        constraints: constraints,
                                        left: TextFormField(
                                          controller: _telefone,
                                          inputFormatters: [_maskTelefone],
                                          keyboardType: TextInputType.phone,
                                          style: const TextStyle(color: AppColors.cream),
                                          decoration: const InputDecoration(
                                            labelText: 'Telefone',
                                            prefixIcon: Icon(Icons.phone_rounded),
                                          ),
                                          validator: (v) => (v == null || v.trim().isEmpty)
                                              ? 'Informe o telefone'
                                              : null,
                                        ),
                                        right: TextFormField(
                                          controller: _cpf,
                                          inputFormatters: [_maskCpf],
                                          keyboardType: TextInputType.number,
                                          style: const TextStyle(color: AppColors.cream),
                                          decoration: const InputDecoration(
                                            labelText: 'CPF',
                                            prefixIcon: Icon(Icons.assignment_ind_outlined),
                                          ),
                                          validator: (v) => (v == null || v.trim().isEmpty)
                                              ? 'Informe o CPF'
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      _twoCol(
                                        context,
                                        constraints: constraints,
                                        left: TextFormField(
                                          controller: _cidade,
                                          style: const TextStyle(color: AppColors.cream),
                                          decoration: const InputDecoration(
                                            labelText: 'Cidade',
                                            prefixIcon: Icon(Icons.location_city_rounded),
                                          ),
                                          validator: (v) => (v == null || v.trim().isEmpty)
                                              ? 'Informe a cidade'
                                              : null,
                                        ),
                                        right: DropdownButtonFormField<String>(
                                          initialValue: _depositoNome,
                                          items: _depositos
                                              .map(
                                                (d) => DropdownMenuItem(
                                                  value: d.nome,
                                                  child: Text(d.nome),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: _loading
                                              ? null
                                              : (v) => setState(() => _depositoNome = v),
                                          dropdownColor: AppColors.darkCardElevated,
                                          style: const TextStyle(color: AppColors.cream),
                                          decoration: const InputDecoration(
                                            labelText: 'Depósito',
                                            prefixIcon: Icon(Icons.warehouse_rounded),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      _twoCol(
                                        context,
                                        constraints: constraints,
                                        left: DropdownButtonFormField<String>(
                                          initialValue: _perfil,
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'Administrador',
                                              child: Text('Administrador'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'Usuario',
                                              child: Text('Usuario'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'Feira',
                                              child: Text('Feira'),
                                            ),
                                          ],
                                          onChanged: _loading
                                              ? null
                                              : (v) => setState(() => _perfil = v ?? 'Usuario'),
                                          dropdownColor: AppColors.darkCardElevated,
                                          style: const TextStyle(color: AppColors.cream),
                                          decoration: const InputDecoration(
                                            labelText: 'Perfil',
                                            prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                                          ),
                                        ),
                                        right: DropdownButtonFormField<String>(
                                          initialValue: _status,
                                          items: const [
                                            DropdownMenuItem(value: 'Ativo', child: Text('Ativo')),
                                            DropdownMenuItem(
                                              value: 'Inativo',
                                              child: Text('Inativo'),
                                            ),
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
                                      ),
                                      const SizedBox(height: 14),
                                      TextFormField(
                                        controller: _senha,
                                        obscureText: true,
                                        style: const TextStyle(color: AppColors.cream),
                                        decoration: InputDecoration(
                                          labelText: widget.isEdit ? 'Senha (opcional)' : 'Senha',
                                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                                        ),
                                        validator: (v) {
                                          if (!widget.isEdit &&
                                              (v == null || v.trim().isEmpty)) {
                                            return 'Informe a senha';
                                          }
                                          return null;
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
                                  );
                                },
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

