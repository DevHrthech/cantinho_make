import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

abstract final class BiometricLoginService {
  static const _secure = FlutterSecureStorage();
  static final _auth = LocalAuthentication();

  static const _keyTelefone = 'cm_bio_telefone';
  static const _keySenha = 'cm_bio_senha';
  static const _keyFlag = 'cm_bio_enabled';

  static Future<bool> deviceHasBiometrics() async {
    if (kIsWeb) return false;
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      if (!await _auth.canCheckBiometrics) return false;
      final types = await _auth.getAvailableBiometrics();
      // Em alguns aparelhos a lista só reflete tipos “fortes”; ainda assim o leitor pode estar disponível.
      if (types.isNotEmpty) return true;
      return supported;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasStoredCredentials() async {
    try {
      final flag = await _secure.read(key: _keyFlag);
      if (flag != '1') return false;
      final t = await _secure.read(key: _keyTelefone);
      final s = await _secure.read(key: _keySenha);
      return t != null &&
          s != null &&
          t.trim().isNotEmpty &&
          s.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Salva login para entrada futura biométrica (apenas se o usuário optar por isso).
  static Future<void> saveCredentials({
    required String telefone,
    required String senha,
  }) async {
    await _secure.write(key: _keyTelefone, value: telefone.trim());
    await _secure.write(key: _keySenha, value: senha);
    await _secure.write(key: _keyFlag, value: '1');
  }

  static Future<(String telefone, String senha)?> readCredentials() async {
    try {
      final flag = await _secure.read(key: _keyFlag);
      if (flag != '1') return null;
      final t = await _secure.read(key: _keyTelefone);
      final s = await _secure.read(key: _keySenha);
      if (t == null || s == null) return null;
      if (t.trim().isEmpty || s.isEmpty) return null;
      return (t.trim(), s);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearStoredCredentials() async {
    try {
      await _secure.delete(key: _keyTelefone);
      await _secure.delete(key: _keySenha);
      await _secure.delete(key: _keyFlag);
    } catch (_) {
      /* ignore */
    }
  }

  static Future<bool> authenticateForLogin() async {
    return _authenticateWithFallback(
      localizedReason:
          'Autentique para acessar o Cantinho Make com suas credenciais salvas neste dispositivo.',
    );
  }

  /// Confirma com biometria (ou PIN/padrão do aparelho) antes de gravar credenciais.
  static Future<bool> authenticateToEnableSavedLogin() async {
    return _authenticateWithFallback(
      localizedReason:
          'Confirme com biometria ou bloqueio de tela para ativar o login rápido neste aparelho.',
    );
  }

  static Future<bool> _authenticateWithFallback({
    required String localizedReason,
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      try {
        return await _auth.authenticate(
          localizedReason: localizedReason,
          biometricOnly: false,
          persistAcrossBackgrounding: true,
        );
      } catch (_) {
        return false;
      }
    }
  }
}
