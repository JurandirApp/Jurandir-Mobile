/// Normaliza a URL de um logo/thumbnail do Cloudinary pra um QUADRADO consistente:
/// recorte com foco no conteúdo (`c_fill,g_auto`) + tamanho fixo + formato/qualidade
/// automáticos. Assim todo logo preenche o tile do mesmo jeito, independente do
/// tamanho ou da margem interna do arquivo que o estabelecimento enviou.
///
/// URLs que não são do Cloudinary (ou nulas/vazias) voltam inalteradas — o widget
/// que chama continua com o mesmo fallback de sempre.
String? squareThumbUrl(String? url, {int size = 174}) {
  if (url == null || url.isEmpty) return url;
  const marker = '/upload/';
  if (!url.contains('res.cloudinary.com') || !url.contains(marker)) return url;
  // Já transformada? (transform vem logo após /upload/) → não empilha de novo.
  if (url.contains('${marker}c_') ||
      url.contains('${marker}e_') ||
      url.contains('${marker}w_')) {
    return url;
  }
  final t = 'c_fill,g_auto,w_$size,h_$size,f_auto,q_auto';
  return url.replaceFirst(marker, '$marker$t/');
}
