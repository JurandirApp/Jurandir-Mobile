/// Status "aberto agora" de um bar, pelo horário de funcionamento calculado no
/// servidor (`openNow` + `nextOpenLabel` do payload público). Servidor antigo
/// não manda os campos → assume aberto (comportamento anterior do app).
class BarOpenStatus {
  final bool openNow;
  final String? nextOpenLabel;

  const BarOpenStatus({this.openNow = true, this.nextOpenLabel});

  /// Lê de um JSON de estabelecimento (`est` do GET /{slug} ou item da lista).
  factory BarOpenStatus.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const BarOpenStatus();
    // `open` (status ACTIVE) false também conta como fechado.
    final active = (j['open'] as bool?) ?? true;
    final label = j['nextOpenLabel'];
    return BarOpenStatus(
      openNow: active && ((j['openNow'] as bool?) ?? true),
      nextOpenLabel: label is String && label.trim().isNotEmpty ? label.trim() : null,
    );
  }

  /// "Fechado agora · Abre hoje às 18:00" (ou só "Fechado agora"). Null se aberto.
  String? get closedLabel => closedLabelFor(openNow: openNow, nextOpenLabel: nextOpenLabel);
}

/// Texto do aviso de fechado. Null quando aberto.
String? closedLabelFor({required bool openNow, String? nextOpenLabel}) {
  if (openNow) return null;
  final next = nextOpenLabel?.trim();
  return (next == null || next.isEmpty) ? 'Fechado agora' : 'Fechado agora · $next';
}

/// Mensagem amigável de "bar fechado" no checkout (também usada quando o
/// servidor recusa a criação do pedido com o erro `closed`).
String closedCheckoutMessage(String? nextOpenLabel) {
  final next = nextOpenLabel?.trim();
  final tail = (next == null || next.isEmpty) ? '' : ' $next.';
  return 'Este estabelecimento está fechado agora (fora do horário). Se continuar, o pedido pode não ser atendido agora.$tail';
}

/// True se o corpo de erro do servidor indica bar fechado (`{error: "closed"}`).
bool isClosedError(Object? body) {
  if (body is Map) return body['error'] == 'closed' || body['code'] == 'closed';
  if (body is String) return body.trim() == 'closed';
  return false;
}

/// Servidor recusou o pedido porque o bar está fechado (erro `closed`).
class BarClosedException implements Exception {
  final String? nextOpenLabel;
  const BarClosedException([this.nextOpenLabel]);
  String get message => closedCheckoutMessage(nextOpenLabel);
  @override
  String toString() => 'BarClosedException($nextOpenLabel)';
}
