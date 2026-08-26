import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Indicador padrão de carregamento do app (logo rotativo, sentido horário).
///
/// Use **sempre** este widget para estados de espera (telas, botões, diálogos),
/// em vez de [CircularProgressIndicator], para manter a identidade visual.
class AppLoadingIndicator extends StatefulWidget {
  const AppLoadingIndicator({
    super.key,
    this.size = 40,
    this.duration = const Duration(milliseconds: 1400),
  });

  final double size;
  final Duration duration;

  @override
  State<AppLoadingIndicator> createState() => _AppLoadingIndicatorState();
}

class _AppLoadingIndicatorState extends State<AppLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _ctrl,
      child: Image.asset(
        'assets/branding/espelho_logo.png',
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => SizedBox(
          width: widget.size,
          height: widget.size,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: AppColors.cream,
          ),
        ),
      ),
    );
  }
}
