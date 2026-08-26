import '../../models/session_user.dart';
import '../../models/user_role.dart';
import '../query_api.dart';

abstract final class AuthService {
  static Future<SessionUser?> login({
    required String telefone,
    required String senha,
  }) async {
    final t = telefone.trim();
    final s = senha;
    if (t.isEmpty || s.isEmpty) return null;

    final te = QueryApi.sqlEscape(t);
    final se = QueryApi.sqlEscape(s);

    final sql =
        "SELECT nome, deposito, perfil FROM usuarios WHERE telefone = '$te' AND senha = '$se'";

    final payload = await QueryApi.postSql(sql);
    final rows = QueryApi.coerceRows(payload);
    if (rows.isEmpty) return null;
    final r = rows.first;

    final nome = (r['nome'] ?? '').toString();
    final deposito = (r['deposito'] ?? '').toString();
    final perfil = (r['perfil'] ?? '').toString();
    final role = _toRole(perfil);

    return SessionUser(
      username: t,
      displayName: nome,
      deposito: deposito,
      telefone: t,
      perfil: perfil,
      role: role,
    );
  }

  static UserRole _toRole(String perfil) {
    final p = perfil.trim().toLowerCase();
    if (p.contains('admin')) return UserRole.admin;
    if (p.contains('feira')) return UserRole.feira;
    return UserRole.standard;
  }
}

