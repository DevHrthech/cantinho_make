import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/deposito.dart';
import '../../services/deposits_api.dart';
import '../../services/users_api.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/glass_card.dart';
import 'user_form_screen.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  late Future<_UsersVm> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<_UsersVm> _load() async {
    final results = await Future.wait<dynamic>([
      UsersApi.list(),
      DepositsApi.list(),
    ]);
    final users = results[0] as List<AppUser>;
    final deposits = results[1] as List<Deposito>;
    final byId = <int, String>{
      for (final d in deposits) d.id: d.nome,
    };
    return _UsersVm(users: users, depositNameById: byId);
  }

  String _displayDeposito(_UsersVm vm, String raw) {
    final id = int.tryParse(raw.trim());
    if (id == null) return raw;
    return vm.depositNameById[id] ?? raw;
  }

  Future<void> _openCreate() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const UserFormScreen.create()),
    );
    if (ok == true) _refresh();
  }

  Future<void> _openEdit(int idUsuario) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => UserFormScreen.edit(idUsuario: idUsuario)),
    );
    if (ok == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_UsersVm>(
      future: _future,
      builder: (context, snap) {
        final loading = snap.connectionState != ConnectionState.done;
        final vm = snap.data;
        final data = vm?.users ?? const <AppUser>[];
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
                      'Usuários cadastrados (API).',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.darkTextMuted),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: loading ? null : _openCreate,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
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
                          'Erro ao carregar usuários: $err',
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
                    final useTable = c.maxWidth >= 720;
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
                          child: Text('Nenhum usuário encontrado.', style: TextStyle(color: AppColors.cream)),
                        );
                      }
                      return Column(
                        children: data.map((u) {
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
                                          u.nome,
                                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                color: AppColors.cream,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${u.email} · ${u.perfil}',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: AppColors.darkTextMuted,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'ID: ${u.idUsuario} · ${_displayDeposito(vm!, u.deposito)} · ${u.status}',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: AppColors.darkTextMuted,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Editar',
                                    onPressed: () => _openEdit(u.idUsuario),
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
                        DataColumn(label: Text('Email')),
                        DataColumn(label: Text('Telefone')),
                        DataColumn(label: Text('CPF')),
                        DataColumn(label: Text('Cidade')),
                        DataColumn(label: Text('Depósito')),
                        DataColumn(label: Text('Perfil')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('')),
                      ],
                      rows: [
                        if (loading)
                          const DataRow(
                            cells: [
                              DataCell(Text('…')),
                              DataCell(Text('Carregando')),
                              DataCell(Text('')),
                              DataCell(Text('')),
                              DataCell(Text('')),
                              DataCell(Text('')),
                              DataCell(Text('')),
                              DataCell(Text('')),
                              DataCell(Text('')),
                              DataCell(SizedBox.shrink()),
                            ],
                          )
                        else if (data.isEmpty)
                          const DataRow(
                            cells: [
                              DataCell(Text('-')),
                              DataCell(Text('Nenhum usuário encontrado')),
                              DataCell(Text('-')),
                              DataCell(Text('-')),
                              DataCell(Text('-')),
                              DataCell(Text('-')),
                              DataCell(Text('-')),
                              DataCell(Text('-')),
                              DataCell(Text('-')),
                              DataCell(SizedBox.shrink()),
                            ],
                          )
                        else
                          ...data.map((u) {
                            final statusColor = u.isAtivo ? AppColors.success : AppColors.warning;
                            return DataRow(
                              cells: [
                                DataCell(Text('${u.idUsuario}')),
                                DataCell(Text(u.nome)),
                                DataCell(Text(u.email)),
                                DataCell(Text(u.telefone)),
                                DataCell(Text(u.cpf)),
                                DataCell(Text(u.cidade)),
                                DataCell(Text(vm == null ? u.deposito : _displayDeposito(vm, u.deposito))),
                                DataCell(Text(u.perfil)),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      color: statusColor.withValues(alpha: 0.15),
                                    ),
                                    child: Text(
                                      u.status,
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
                                    onPressed: () => _openEdit(u.idUsuario),
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

class _UsersVm {
  const _UsersVm({required this.users, required this.depositNameById});

  final List<AppUser> users;
  final Map<int, String> depositNameById;
}
