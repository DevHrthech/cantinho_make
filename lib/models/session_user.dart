import 'user_role.dart';

class SessionUser {
  const SessionUser({
    required this.username,
    required this.displayName,
    required this.deposito,
    required this.telefone,
    required this.perfil,
    required this.role,
  });

  final String username;
  final String displayName;
  final String deposito;
  final String telefone;
  final String perfil;
  final UserRole role;

  bool get isAdmin => role == UserRole.admin;

  bool get isFeira => role == UserRole.feira;
}
