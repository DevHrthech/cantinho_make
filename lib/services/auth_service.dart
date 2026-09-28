import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/session_user.dart';
import '../models/user_role.dart';
import 'api_client.dart';

abstract final class AuthService {
  static const _secure = FlutterSecureStorage();

  /// Logins já feitos online neste aparelho: telefone -> {salt, hash, token, usuario}.
  /// Permite entrar sem internet com a mesma senha (ex.: na feira).
  static const _keyOffline = 'cm_offline_logins';

  /// Retorna null para telefone/senha inválidos ou usuário inativo.
  static Future<SessionUser?> login({
    required String telefone,
    required String senha,
  }) async {
    final t = telefone.trim();
    if (t.isEmpty || senha.isEmpty) return null;

    try {
      final payload = await ApiClient.post('/login', {'telefone': t, 'senha': senha});
      final token = (payload as Map)['token'].toString();
      final usuario = (payload['usuario'] as Map).cast<String, dynamic>();
      ApiClient.token = token;
      await _saveOffline(t, senha, token, usuario);
      return _toSession(usuario);
    } on ApiException catch (e) {
      final status = e.statusCode;
      if (status == 401 || status == 403) {
        // Senha mudou ou usuário foi desativado: não vale mais offline.
        await _removeOffline(t);
        return null;
      }
      if (status == 429) rethrow;
      if (status != null && status < 500) rethrow;
      return _loginOffline(t, senha, e);
    } catch (e) {
      // Sem internet, timeout, servidor fora do ar.
      return _loginOffline(t, senha, e);
    }
  }

  static void logout() => ApiClient.token = null;

  static Future<SessionUser?> _loginOffline(String telefone, String senha, Object erroOnline) async {
    final rec = (await _readOffline())[telefone];
    if (rec is! Map) throw erroOnline;
    if (_hash(rec['salt'].toString(), senha) != rec['hash']) return null;
    ApiClient.token = rec['token']?.toString();
    return _toSession((rec['usuario'] as Map).cast<String, dynamic>());
  }

  static SessionUser _toSession(Map<String, dynamic> u) {
    final perfil = (u['perfil'] ?? '').toString();
    final telefone = (u['telefone'] ?? '').toString();
    return SessionUser(
      username: telefone,
      displayName: (u['nome'] ?? '').toString(),
      deposito: (u['deposito'] ?? '').toString(),
      telefone: telefone,
      perfil: perfil,
      role: _toRole(perfil),
    );
  }

  static UserRole _toRole(String perfil) {
    final p = perfil.trim().toLowerCase();
    if (p.contains('admin')) return UserRole.admin;
    if (p.contains('feira')) return UserRole.feira;
    return UserRole.standard;
  }

  static String _hash(String salt, String senha) =>
      sha256.convert(utf8.encode('$salt:$senha')).toString();

  static Future<Map<String, dynamic>> _readOffline() async {
    try {
      final raw = await _secure.read(key: _keyOffline);
      if (raw == null || raw.isEmpty) return {};
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveOffline(
    String telefone,
    String senha,
    String token,
    Map<String, dynamic> usuario,
  ) async {
    try {
      final rnd = Random.secure();
      final salt = base64Url.encode(List<int>.generate(16, (_) => rnd.nextInt(256)));
      final all = await _readOffline();
      all[telefone] = {
        'salt': salt,
        'hash': _hash(salt, senha),
        'token': token,
        'usuario': usuario,
      };
      await _secure.write(key: _keyOffline, value: jsonEncode(all));
    } catch (_) {
      // Sem armazenamento seguro: segue apenas com login online.
    }
  }

  static Future<void> _removeOffline(String telefone) async {
    try {
      final all = await _readOffline();
      if (all.remove(telefone) != null) {
        await _secure.write(key: _keyOffline, value: jsonEncode(all));
      }
    } catch (_) {
      /* ignore */
    }
  }
}
