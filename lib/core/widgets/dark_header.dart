import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Header escuro arredondado do design: fundo ink, texto areia, cantos
/// inferiores arredondados. Reserva a área da status bar (safe area).
class DarkHeader extends StatelessWidget {
  final String title;
  final String? eyebrow;
  final Widget? leading;
  final Widget? trailing;

  /// Conteúdo extra abaixo do título (ex: barra de busca).
  final Widget? bottom;
  final double radius;

  const DarkHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.leading,
    this.trailing,
    this.bottom,
    this.radius = 26,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top + 18;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPad, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(radius)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (eyebrow != null) ...[
                      Text(eyebrow!.toUpperCase(), style: AppText.eyebrow),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      title.toUpperCase(),
                      style: AppText.pageTitle.copyWith(color: AppColors.dune),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          if (bottom != null) ...[const SizedBox(height: 16), bottom!],
        ],
      ),
    );
  }
}
