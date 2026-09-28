import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import '../models/session_user.dart';
import '../services/auth_service.dart';
import '../services/biometric_login_service.dart';
import '../theme/app_colors.dart';
import '../utils/friendly_error_message.dart';
import '../widgets/app_shell_background.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/glass_card.dart';

typedef LoginSuccessCallback = void Function(SessionUser user);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onSuccess});

  final LoginSuccessCallback onSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _error;
  bool _busy = false;
  bool _bioDeviceOk = false;
  bool _bioHasStoredCred = false;
  bool _saveCredForBio = false;
  bool _bioBusy = false;

  final _phoneMask = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {'#': RegExp(r'[0-9]')},
  );
  late final AnimationController _pulse;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshBiometricState());
  }

  Future<void> _refreshBiometricState() async {
    final ok = await BiometricLoginService.deviceHasBiometrics();
    final stored = await BiometricLoginService.hasStoredCredentials();
    if (!mounted) return;
    setState(() {
      _bioDeviceOk = ok;
      _bioHasStoredCred = stored;
    });
  }

  Future<void> _submitBiometric() async {
    setState(() => _error = null);
    if (_busy || _bioBusy) return;
    final cred = await BiometricLoginService.readCredentials();
    if (cred == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Credenciais não encontradas. Entre uma vez com telefone e senha.')),
      );
      await _refreshBiometricState();
      return;
    }
    final (telefone, senha) = cred;
    final authed = await BiometricLoginService.authenticateForLogin();
    if (!authed || !mounted) return;

    setState(() => _bioBusy = true);
    try {
      final session = await AuthService.login(telefone: telefone, senha: senha);
      if (!mounted) return;
      if (session != null) {
        widget.onSuccess(session);
      } else {
        setState(() => _error = 'Falha no login biométrico. Use telefone e senha.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _bioBusy = false);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _phone.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final session = await AuthService.login(
        telefone: _phone.text.trim(),
        senha: _pass.text,
      );
      if (!mounted) return;
      if (session != null) {
        if (_bioDeviceOk && _saveCredForBio) {
          final confirmed =
              await BiometricLoginService.authenticateToEnableSavedLogin();
          if (!mounted) return;
          if (confirmed) {
            await BiometricLoginService.saveCredentials(
              telefone: _phone.text.trim(),
              senha: _pass.text,
            );
            await _refreshBiometricState();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Login rápido com biometria não foi ativado (confirmação cancelada).',
                ),
              ),
            );
          }
        }
        widget.onSuccess(session);
      } else {
        setState(() => _error = 'Telefone ou senha incorretos, ou usuário inativo.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppShellBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, topInset + 12, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: ScaleTransition(
                      scale: _pulseAnim,
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.cream.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.cream.withValues(alpha: 0.28)),
                        ),
                        child: const Icon(
                          Icons.inventory_2_rounded,
                          size: 52,
                          color: AppColors.cream,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Cantinho Make',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.cream,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Controle de estoque entre filiais',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.darkTextMuted,
                    ),
                  ),
                  const SizedBox(height: 32),
                  GlassCard(
                    padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Entrar',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.cream,
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: _phone,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(color: AppColors.cream),
                            keyboardType: TextInputType.phone,
                            inputFormatters: [_phoneMask],
                            decoration: const InputDecoration(
                              labelText: 'Telefone',
                              prefixIcon: Icon(Icons.phone_rounded),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Informe o telefone';
                              if (v.trim().length < 14) return 'Telefone incompleto';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _pass,
                            obscureText: true,
                            style: const TextStyle(color: AppColors.cream),
                            onFieldSubmitted: (_) => _submit(),
                            decoration: const InputDecoration(
                              labelText: 'Senha',
                              prefixIcon: Icon(Icons.lock_outline_rounded),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Informe a senha';
                              return null;
                            },
                          ),
                          if (_bioDeviceOk) ...[
                            const SizedBox(height: 8),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _saveCredForBio,
                              onChanged: (v) =>
                                  setState(() => _saveCredForBio = v ?? false),
                              title: Text(
                                'Permitir entrar com biometria neste aparelho',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppColors.darkTextMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          if (_bioDeviceOk && _bioHasStoredCred)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: OutlinedButton.icon(
                                onPressed: (_busy || _bioBusy) ? null : _submitBiometric,
                                icon: _bioBusy
                                    ? const AppLoadingIndicator(size: 22)
                                    : const Icon(Icons.fingerprint_rounded),
                                label: Text(_bioBusy ? 'Biometria…' : 'Entrar com biometria'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.cream,
                                  side: BorderSide(color: AppColors.cream.withValues(alpha: 0.45)),
                                  minimumSize: const Size.fromHeight(48),
                                ),
                              ),
                            ),
                          FilledButton(
                            onPressed: (_busy || _bioBusy) ? null : _submit,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                            ),
                            child: _busy
                                ? const AppLoadingIndicator(size: 24)
                                : const Text('Acessar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
