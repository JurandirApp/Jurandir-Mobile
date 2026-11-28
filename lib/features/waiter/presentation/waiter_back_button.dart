import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/i18n.dart';

/// Seta de voltar do header escuro das telas do garçom (mesmo visual do
/// botão de sair: quadrado areia translúcido 40×40).
Widget waiterBackButton(VoidCallback onTap) {
  return Semantics(
    button: true,
    label: tr('waiter.back'),
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.duneA(0.12), borderRadius: BorderRadius.circular(12)),
        child: const Icon(Symbols.arrow_back, size: 20, color: AppColors.dune),
      ),
    ),
  );
}
