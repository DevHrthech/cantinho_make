import '../../models/session_user.dart';

abstract final class AuthService {
  static Future<SessionUser?> login({
    required String telefone,
    required String senha,
  }) {
    throw UnsupportedError('Login não suportado nesta plataforma.');
  }
}

