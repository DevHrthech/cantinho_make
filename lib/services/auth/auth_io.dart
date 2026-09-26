import 'package:sqflite/sqflite.dart';

import '../../models/session_user.dart';
import '../../models/user_role.dart';
import '../local_db.dart';
import '../users_sync.dart';

abstract final class AuthService {
  static Future<SessionUser?> login({
    required String telefone,
    required String senha,
  }) async {
    final t = telefone.trim();
    final s = senha;
    if (t.isEmpty || s.isEmpty) return null;

    var r = await _findUsuario(t, s);
    if (r == null || !_isAtivo((r['status'] ?? '').toString())) {
      // A sincronização de usuários pode ainda estar rodando desde a abertura do app.
      await UsersSyncService.waitForPending();
      r = await _findUsuario(t, s);
    }
    if (r == null) return null;

    final status = (r['status'] ?? '').toString();
    if (!_isAtivo(status)) return null;

    final perfil = (r['perfil'] ?? '').toString();
    final role = _toRole(perfil);

    final nome = (r['nome'] ?? '').toString();
    final deposito = (r['deposito'] ?? '').toString();
    final phone = (r['telefone'] ?? '').toString();

    return SessionUser(
      username: phone,
      displayName: nome,
      deposito: deposito,
      telefone: phone,
      perfil: perfil,
      role: role,
    );
  }

  static Future<Map<String, Object?>?> _findUsuario(String telefone, String senha) async {
    final db = (await LocalDb.instance.database) as Database;
    final rows = await db.query(
      'usuarios',
      columns: const ['nome', 'deposito', 'perfil', 'status', 'telefone'],
      where: 'telefone = ? AND senha = ?',
      whereArgs: [telefone, senha],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  static bool _isAtivo(String status) {
    final s = status.trim().toLowerCase();
    return s == 'ativo' || s == 'ativos' || s == 'sim' || s == '1' || s == 'true';
  }

  static UserRole _toRole(String perfil) {
    final p = perfil.trim().toLowerCase();
    if (p.contains('admin')) return UserRole.admin;
    if (p.contains('feira')) return UserRole.feira;
    return UserRole.standard;
  }
}

