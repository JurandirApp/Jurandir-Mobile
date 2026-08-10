import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Header das sub-telas do estabelecimento (Auditoria/Perfil/Config):
/// back "← Conta" + eyebrow + título.
class EstabSubHeader extends StatelessWidget {
  final String title;

  const EstabSubHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 18, 20, 18),
      decoration: const BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => context.go('/estab/conta'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Symbols.arrow_back, size: 16, color: AppColors.duneA(0.7)),
                const SizedBox(width: 6),
                Text('Conta', style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.duneA(0.7))),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text('Quiosque do Mar'.toUpperCase(), style: AppText.eyebrow),
          const SizedBox(height: 3),
          Text(title.toUpperCase(), style: AppText.pageTitle.copyWith(color: AppColors.dune)),
        ],
      ),
    );
  }
}
