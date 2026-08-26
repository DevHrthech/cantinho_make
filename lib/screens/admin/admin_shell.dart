import 'package:flutter/material.dart';

import '../../models/session_user.dart';
import '../../models/user_role.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_shell_background.dart';
import '../../widgets/nav_pill.dart';
import '../stock_operation_screen.dart';
import 'dashboard_screen.dart';
import 'deposits_screen.dart';
import 'products_screen.dart';
import 'reports_screen.dart';
import 'users_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.user, required this.onLogout});

  final SessionUser user;
  final VoidCallback onLogout;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _tab = 0;

  void _openStock(bool saida) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StockOperationScreen(
          mode: saida ? StockOperationMode.saida : StockOperationMode.entrada,
          user: widget.user,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardScreen(
        onOpenSaida: () => _openStock(true),
        onOpenEntrada: () => _openStock(false),
      ),
      const DepositsScreen(),
      const UsersScreen(),
      const ProductsScreen(),
      ReportsScreen(user: widget.user),
    ];

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppShellBackground(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AdminHeader(
                  user: widget.user,
                  selectedIndex: _tab,
                  onSelect: (i) => setState(() => _tab = i),
                  onLogout: widget.onLogout,
                ),
                Expanded(child: pages[_tab]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminHeader extends StatelessWidget {
  const _AdminHeader({
    required this.user,
    required this.selectedIndex,
    required this.onSelect,
    required this.onLogout,
  });

  final SessionUser user;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Cantinho Make',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.cream,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.cream.withValues(alpha: 0.25)),
                  color: Colors.white.withValues(alpha: 0.06),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.storefront_rounded, size: 16, color: AppColors.creamDeep),
                    const SizedBox(width: 6),
                    Text(
                      'Loja',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.cream,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Sair',
                onPressed: onLogout,
                icon: const Icon(Icons.logout_rounded, color: AppColors.cream),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${user.displayName} · ${user.role.label}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.darkTextMuted,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                NavPill(
                  label: 'Dashboard',
                  icon: Icons.dashboard_rounded,
                  selected: selectedIndex == 0,
                  onTap: () => onSelect(0),
                ),
                NavPill(
                  label: 'Depósitos',
                  icon: Icons.warehouse_rounded,
                  selected: selectedIndex == 1,
                  onTap: () => onSelect(1),
                ),
                NavPill(
                  label: 'Usuários',
                  icon: Icons.group_rounded,
                  selected: selectedIndex == 2,
                  onTap: () => onSelect(2),
                ),
                NavPill(
                  label: 'Produtos',
                  icon: Icons.inventory_2_rounded,
                  selected: selectedIndex == 3,
                  onTap: () => onSelect(3),
                ),
                NavPill(
                  label: 'Relatórios',
                  icon: Icons.analytics_rounded,
                  selected: selectedIndex == 4,
                  onTap: () => onSelect(4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
