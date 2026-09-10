import 'package:flutter/material.dart';

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
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      // Evita piscar de volta pro placeholder num rebuild depois de já ter carregado.
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        // Veio do cache → já está pronta, sem transição.
        if (wasSynchronouslyLoaded) return child;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOut,
          child: frame == null
              ? const SizedBox.expand(
                  key: ValueKey('img-shimmer'),
                  child: _ImageShimmer(),
                )
              : KeyedSubtree(key: const ValueKey('img-ready'), child: child),
        );
      },
      errorBuilder: (_, _, _) => errorWidget ?? const SizedBox.shrink(),
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

  // Cinza-ardósia (combina com o fundo dos cards) + um brilho bem mais claro.
  static const _base = Color(0xFFDCE1E8);
  static const _glint = Color(0xFFF2F5F9);

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
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(dx - 1, -0.2),
                end: Alignment(dx + 1, 0.2),
                colors: const [_base, _glint, _base],
                stops: const [0.35, 0.5, 0.65],
              ),
            ),
          );
        },
      ),
    );
  }
}
