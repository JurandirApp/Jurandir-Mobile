// Geração dos nomes de mesas/pontos pro cadastro em lote ("Adicionar várias").
// Funções puras (testadas em test/spot_labels_test.dart).

/// Máximo de mesas por lote (o servidor também limita).
const maxSpotBatch = 200;

/// Chave de comparação: sem espaços nas pontas/repetidos e sem caixa.
String _key(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// Limpa uma lista de nomes: tira espaços (pontas e repetidos), descarta vazios
/// e remove duplicados sem diferenciar maiúsculas (mantém a 1ª grafia/ordem).
List<String> dedupeLabels(Iterable<String> labels) {
  final seen = <String>{};
  final out = <String>[];
  for (final raw in labels) {
    final l = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (l.isEmpty) continue;
    if (seen.add(_key(l))) out.add(l);
  }
  return out;
}

/// Lista colada: um nome por linha (aceita \r\n). Trim + sem vazios + sem duplicados.
List<String> parseSpotList(String text) => dedupeLabels(text.split(RegExp(r'\r?\n')));

/// Faixa: [prefix] + números de [from] a [to] (inclusive; aceita invertido).
/// [zeroPad] completa com zeros até a largura do maior número, com no mínimo
/// 2 dígitos ("Mesa 01" … "Mesa 30"; 1→120 vira "001"…"120").
/// Prefixo vazio gera só os números. Números negativos → lista vazia.
List<String> rangeSpotLabels({
  required String prefix,
  required int from,
  required int to,
  bool zeroPad = false,
}) {
  if (from < 0 || to < 0) return const [];
  final lo = from <= to ? from : to;
  final hi = from <= to ? to : from;
  final width = zeroPad ? '$hi'.length.clamp(2, 9) : 0;
  final p = prefix.trim().replaceAll(RegExp(r'\s+'), ' ');
  return dedupeLabels([
    for (var n = lo; n <= hi; n++) p.isEmpty ? '$n'.padLeft(width, '0') : '$p ${'$n'.padLeft(width, '0')}',
  ]);
}

/// Resumo do lote pro aviso: "X mesas criadas, Y já existiam" (com singular).
String spotsBatchSummary(int created, int skipped) {
  final c = created == 1 ? '1 mesa criada' : '$created mesas criadas';
  if (skipped <= 0) return c;
  final s = skipped == 1 ? '1 já existia' : '$skipped já existiam';
  return '$c, $s';
}

/// Quantos nomes a faixa geraria (sem montar a lista — evita alocar milhões).
int rangeCount(int from, int to) => (from < 0 || to < 0) ? 0 : (to - from).abs() + 1;
