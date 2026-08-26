import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Cartão estilo vidro / painel do mockup.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.accentBorder = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool accentBorder;

  @override
  Widget build(BuildContext context) {
    final border = Border.all(
      color: accentBorder
          ? AppColors.cream.withValues(alpha: 0.45)
          : Colors.white.withValues(alpha: 0.08),
      width: accentBorder ? 1.2 : 1,
    );
    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      border: border,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.darkCard.withValues(alpha: 0.92),
          AppColors.darkCardElevated.withValues(alpha: 0.88),
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ],
    );

    final content = Padding(padding: padding, child: child);

    if (onTap == null) {
      return DecoratedBox(decoration: decoration, child: content);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(decoration: decoration, child: content),
      ),
    );
  }
}
