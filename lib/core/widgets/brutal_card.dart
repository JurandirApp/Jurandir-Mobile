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
    // O clip fica SÓ no conteúdo: `clipBehavior` no mesmo Container que pinta a
    // sombra dura recortava a sombra/borda nos cantos (aparecia "cortado" na UI).
    // Raio interno = raio externo − largura da borda, para o conteúdo (foto)
    // acompanhar a curva por dentro da borda sem vazar 1px.
    final content = clip
        ? ClipRRect(
            borderRadius: BorderRadius.circular((radius - 2).clamp(0.0, radius)),
            child: child,
          )
        : child;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: const [
          BoxShadow(color: AppColors.ink, offset: Offset(4, 4)),
        ],
      ),
      child: content,
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}
