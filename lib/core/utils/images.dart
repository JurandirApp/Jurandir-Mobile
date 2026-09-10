/// Normaliza a URL de um logo/thumbnail do Cloudinary pra um QUADRADO consistente:
/// recorte com foco no conteúdo (`c_fill,g_auto`) + tamanho fixo + formato/qualidade
/// automáticos. Assim todo logo preenche o tile do mesmo jeito, independente do
/// tamanho ou da margem interna do arquivo que o estabelecimento enviou.
///
/// URLs que não são do Cloudinary (ou nulas/vazias) voltam inalteradas — o widget
/// que chama continua com o mesmo fallback de sempre.
String? squareThumbUrl(String? url, {int size = 174}) =>
    _cloudinary(url, 'c_fill,g_auto,w_$size,h_$size,f_auto,q_auto');

/// Versão LEVE de uma imagem pra caber num card sem baixar o arquivo original
/// inteiro — grande parte da lentidão ("porco") vinha de puxar imagens enormes.
/// `c_limit` só REDUZ pra caber na largura pedida (nunca amplia) e mantém a
/// proporção; o recorte visual fica por conta do `BoxFit.cover` do widget.
/// `f_auto,q_auto` entregam WebP/AVIF na qualidade certa pro dispositivo.
String? cardImageUrl(String? url, {int width = 640}) =>
    _cloudinary(url, 'c_limit,w_$width,f_auto,q_auto');

/// Insere uma transformação logo após `/upload/` numa URL do Cloudinary.
/// URLs não-Cloudinary — ou já transformadas, nulas ou vazias — voltam iguais,
/// então é seguro chamar em qualquer `imageUrl`/`photoUrl`.
String? _cloudinary(String? url, String transform) {
  if (url == null || url.isEmpty) return url;
  const marker = '/upload/';
  if (!url.contains('res.cloudinary.com') || !url.contains(marker)) return url;
  // Já transformada? (transform vem logo após /upload/) → não empilha de novo.
  if (url.contains('${marker}c_') ||
      url.contains('${marker}e_') ||
      url.contains('${marker}w_')) {
    return url;
  }
  return url.replaceFirst(marker, '$marker$transform/');
}
