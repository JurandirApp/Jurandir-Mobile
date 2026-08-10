/// Formata um valor em Reais no padrão pt-BR: `R$ 22,00`.
String money(num v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

/// Agrupa milhares com ponto (pt-BR): 1234 -> "1.234".
String groupThousands(int n) {
  final s = n.abs().toString();
  final buf = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}
