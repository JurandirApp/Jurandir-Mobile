import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Tom do badge de status (do design).
enum BadgeTone { pending, production, done, neutral }

/// Badge de status (pílula pequena colorida): aguardando (rose), produção
/// (amber), entregue/ativo/aberto (emerald), neutro/fechado.
class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeTone tone;

  const StatusBadge(this.label, {super.key, this.tone = BadgeTone.neutral});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    switch (tone) {
      case BadgeTone.pending:
        bg = AppColors.dangerBg;
        fg = AppColors.dangerText;
      case BadgeTone.production:
        bg = AppColors.warningBg;
        fg = AppColors.warningText;
      case BadgeTone.done:
        bg = AppColors.successBg;
        fg = AppColors.successText;
      case BadgeTone.neutral:
        bg = AppColors.inkA(0.1);
        fg = AppColors.inkA(0.5);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppText.body(size: 11, weight: FontWeight.w700, color: fg),
      ),
    );
  }
}
