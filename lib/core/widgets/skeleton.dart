import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Bloco de skeleton com SHIMMER (um brilho que desliza da esquerda pra direita)
/// — peça base de todos os estados de carregamento. Usado enquanto os dados reais
/// da API chegam (nunca mostramos mock).
///
/// Como todos os `SkeletonBox` de uma tela nascem no mesmo frame e têm o mesmo
/// período, o brilho passa praticamente sincronizado por todos — dá a sensação
/// de uma varredura única sobre o card, em vez de blocos cinza "mortos".
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.width, this.height = 12, this.radius = 6});

  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          // dx varre de -1.5 → 1.5: o brilho entra pela esquerda e sai pela
          // direita, fora dos limites da caixa.
          final dx = _c.value * 3 - 1.5;
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              gradient: LinearGradient(
                begin: Alignment(dx - 1, 0),
                end: Alignment(dx + 1, 0),
                colors: [
                  AppColors.inkA(0.11),
                  AppColors.inkA(0.035),
                  AppColors.inkA(0.11),
                ],
                stops: const [0.35, 0.5, 0.65],
              ),
            ),
          );
        },
      ),
    );
  }
}
