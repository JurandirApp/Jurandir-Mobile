import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum _ButtonVariant { primary, dark, ghost }

/// Botão do design: primário (coral), escuro (ink) ou ghost (areia apagada).
/// Pílula (radius 999), full-width por padrão, com ícone opcional.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final _ButtonVariant _variant;

  const AppButton.primary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = true,
  }) : _variant = _ButtonVariant.primary;

  const AppButton.dark({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = true,
  }) : _variant = _ButtonVariant.dark;

  const AppButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = true,
  }) : _variant = _ButtonVariant.ghost;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final double padV;
    switch (_variant) {
      case _ButtonVariant.primary:
        bg = AppColors.coral;
        fg = Colors.white;
        padV = 15;
      case _ButtonVariant.dark:
        bg = AppColors.ink;
        fg = AppColors.dune;
        padV = 15;
      case _ButtonVariant.ghost:
        bg = AppColors.duneA(0.5);
        fg = AppColors.inkA(0.7);
        padV = 13;
    }

    Widget btn = Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: padV, horizontal: 20),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 8),
              ],
              Text(label, style: AppText.button.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
    if (expand) btn = SizedBox(width: double.infinity, child: btn);
    return btn;
  }
}
