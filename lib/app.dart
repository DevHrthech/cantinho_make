import 'dart:async';

import 'package:flutter/material.dart';

import 'models/session_user.dart';
import 'services/auth_service.dart';
import 'services/biometric_login_service.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/login_screen.dart';
import 'screens/user_operator_home.dart';
import 'theme/app_theme.dart';

class CantinhoApp extends StatefulWidget {
  const CantinhoApp({super.key});

  @override
  State<CantinhoApp> createState() => _CantinhoAppState();
}

class _CantinhoAppState extends State<CantinhoApp> {
  SessionUser? _user;

  void _logout() {
    AuthService.logout();
    unawaited(BiometricLoginService.clearStoredCredentials());
    setState(() => _user = null);
  }

  void _login(SessionUser user) => setState(() => _user = user);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cantinho Make',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 420),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _user == null
            ? LoginScreen(
                key: const ValueKey('login'),
                onSuccess: _login,
              )
            : _user!.isAdmin
                ? AdminShell(
                    key: ValueKey('admin-${_user!.username}'),
                    user: _user!,
                    onLogout: _logout,
                  )
                : UserOperatorHome(
                    key: ValueKey('op-${_user!.username}'),
                    user: _user!,
                    onLogout: _logout,
                  ),
      ),
    );
  }
}
