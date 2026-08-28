import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Card "neo-brutalista" do design: borda 2px ink + sombra dura
/// `4px 4px 0 #141821`. Superfície dominante do app.
///
/// Lembre: a sombra ocupa 4px à direita/abaixo — deixe espaço no layout.
/// Use [clip] = true quando o conteúdo (ex: foto) precisa ser recortado
/// pelos cantos arredondados.
class BrutalCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color background;
  final double radius;
  final Color borderColor;
  final bool clip;
  final VoidCallback? onTap;

  const BrutalCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.background = Colors.white,
    this.radius = 16,
    this.borderColor = AppColors.ink,
    this.clip = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    // Estrutura em 2 camadas p/ os cantos ficarem perfeitos:
    // 1) DecoratedBox externo pinta SÓ a sombra dura (fora de qualquer clip —
    //    `clipBehavior` junto da sombra a recortava nos cantos);
    // 2) Container interno recorta o conteúdo no raio cheio e pinta a borda POR
    //    CIMA (`foregroundDecoration`), então a borda fica sempre nítida e o
    //    conteúdo colorido (foto, faixa) não vaza nem afina nos cantos.
    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: const [BoxShadow(color: AppColors.ink, offset: Offset(4, 4))],
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: background, borderRadius: r),
        foregroundDecoration: BoxDecoration(
          borderRadius: r,
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}
