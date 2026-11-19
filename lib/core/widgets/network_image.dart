import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Imagem de rede com carregamento agradável, no lugar do `Image.network` cru
/// (que aparecia de repente com um "pop" seco sobre o cinza chapado):
///
/// - enquanto baixa/decodifica, mostra um shimmer OPACO e visível (base cinza
///   + brilho claro deslizando) que preenche o tile — legível até num thumb
///   de 58px, onde o skeleton translúcido de texto some;
/// - quando a imagem fica pronta, faz um fade-in suave (350ms);
/// - se já estava no cache do app, aparece na hora (sem shimmer nem flash);
/// - em erro cai no [errorWidget] (ou some, como antes).
///
/// O tamanho vem sempre do container que envolve o widget (o mesmo de antes),
/// então é um drop-in: basta trocar `Image.network(...)` por `AppNetworkImage(...)`.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorWidget,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    // CachedNetworkImage guarda a imagem em DISCO (persiste entre aberturas) e
    // em memória. Já veio do cache → aparece na hora; senão, shimmer + fade-in.
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 350),
      fadeInCurve: Curves.easeOut,
      placeholder: (_, _) => const SizedBox.expand(child: _ImageShimmer()),
      // Sem foto (erro): o mesmo tile da marca, parado — nunca um buraco vazio.
      errorWidget: (_, _, _) => errorWidget ?? const SizedBox.expand(child: _BrandTile()),
    );
  }
}

/// Tile da marca: fundo areia + o boneco do Jurandir clarinho no centro (o
/// `mascot.png` já tem exatamente esse fundo areia, então não aparece emenda).
/// Em tiles pequenos (thumbs < 80px) fica só o fundo, sem o boneco.
class _BrandTile extends StatelessWidget {
  const _BrandTile();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.dune,
      child: LayoutBuilder(
        builder: (context, c) {
          final side = c.biggest.shortestSide;
          if (!side.isFinite || side < 80) return const SizedBox.expand();
          final size = (side * 0.42).clamp(48.0, 150.0);
          return Center(
            child: Opacity(
              opacity: 0.45,
              child: Image.asset('assets/images/mascot.png', width: size, height: size),
            ),
          );
        },
      ),
    );
  }
}

/// Shimmer dedicado aos placeholders de imagem: um bloco cinza OPACO com um
/// brilho claro que varre da esquerda pra direita. Diferente do SkeletonBox de
/// texto (translúcido, pensado pra blocos grandes), este tem contraste próprio
/// pra continuar legível como "carregando" mesmo num thumb minúsculo.
class _ImageShimmer extends StatefulWidget {
  const _ImageShimmer();

  @override
  State<_ImageShimmer> createState() => _ImageShimmerState();
}

class _ImageShimmerState extends State<_ImageShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  // Brilho creme quente (antes cinza-azulado metálico) varrendo o tile da marca.
  static const _glint = Color(0xFFF8EFDA); // AppColors.canvas

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
          // dx varre de -1.5 → 1.5: o brilho entra pela esquerda e sai pela direita.
          final dx = _c.value * 3 - 1.5;
          // Tile da marca (areia + boneco) com um brilho creme suave por cima.
          return Stack(
            fit: StackFit.expand,
            children: [
              const _BrandTile(),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(dx - 1, -0.2),
                    end: Alignment(dx + 1, 0.2),
                    colors: [
                      _glint.withValues(alpha: 0),
                      _glint.withValues(alpha: 0.55),
                      _glint.withValues(alpha: 0),
                    ],
                    stops: const [0.35, 0.5, 0.65],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
