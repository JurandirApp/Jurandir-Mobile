import 'package:flutter/material.dart';

import 'skeleton.dart';

/// Imagem de rede com carregamento agradável, no lugar do `Image.network` cru
/// (que aparecia de repente com um "pop" seco sobre o cinza chapado):
///
/// - enquanto baixa/decodifica, mostra um [SkeletonBox] com shimmer preenchendo
///   o espaço do card;
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
                  key: ValueKey('img-skeleton'),
                  child: SkeletonBox(radius: 0),
                )
              : KeyedSubtree(key: const ValueKey('img-ready'), child: child),
        );
      },
      errorBuilder: (_, _, _) => errorWidget ?? const SizedBox.shrink(),
    );
  }
}
