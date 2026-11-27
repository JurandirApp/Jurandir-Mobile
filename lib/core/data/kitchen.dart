// Horário da cozinha — regras puras (testáveis) do lado do app.
//
// Decisão do produto: fora do horário da cozinha, itens de COMIDA (marcados
// `kitchen` pelo servidor) ficam indisponíveis ("Cozinha fechada"); bebidas e o
// resto do cardápio seguem normais. O servidor é a autoridade: calcula
// `kitchenOpenNow` e rejeita o pedido com `error: 'kitchenClosed'` se mesmo
// assim chegar item de cozinha fora do horário.
//
// Compatibilidade: servidor antigo não manda os campos → cozinha sempre aberta
// e nenhum item é de cozinha (comportamento de antes).

import 'package:dio/dio.dart';

import 'models.dart';
import 'open_status.dart';

/// Mensagem amigável (checkout/erro do servidor) quando a cozinha fechou.
const kKitchenClosedMsg =
    'A cozinha está fechada agora. Tire os itens de comida do pedido para continuar.';

/// Situação da cozinha de um bar, de `est` em `GET /api/public/{slug}`.
class KitchenStatus {
  final bool openNow;

  /// Rótulo de quando reabre (ex.: "abre às 18:00"), já formatado pelo servidor.
  final String? nextOpenLabel;

  const KitchenStatus({this.openNow = true, this.nextOpenLabel});

  /// Sem info (servidor antigo / ainda carregando): cozinha aberta.
  static const open = KitchenStatus();

  factory KitchenStatus.fromEst(Object? est) {
    if (est is! Map) return open;
    final label = est['kitchenNextOpenLabel'];
    return KitchenStatus(
      // Só `false` explícito fecha; ausente/nulo/outro tipo = aberta.
      openNow: est['kitchenOpenNow'] != false,
      nextOpenLabel: label is String && label.trim().isNotEmpty ? label.trim() : null,
    );
  }

  /// "Cozinha fechada · abre às 18:00" (ou só "Cozinha fechada").
  String get closedLabel =>
      nextOpenLabel == null ? 'Cozinha fechada' : 'Cozinha fechada · $nextOpenLabel';
}

/// Cardápio + situação da cozinha + bar aberto agora (tudo da MESMA resposta
/// de `GET /api/public/{slug}` — uma requisição só alimenta os dois avisos).
class MenuData {
  final List<MenuItem> items;
  final KitchenStatus kitchen;

  /// Bar aberto agora (`est.openNow`/`nextOpenLabel`). Sem campos = aberto.
  final BarOpenStatus open;

  const MenuData({
    required this.items,
    this.kitchen = KitchenStatus.open,
    this.open = const BarOpenStatus(),
  });

  factory MenuData.fromJson(Map<String, dynamic> j) {
    final est = j['est'];
    return MenuData(
      items: ((j['menu'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(MenuItem.fromJson)
          .toList(),
      kitchen: KitchenStatus.fromEst(est),
      open: BarOpenStatus.fromJson(est is Map<String, dynamic> ? est : null),
    );
  }
}

/// O item não pode ser pedido agora? (é de cozinha e a cozinha está fechada).
bool itemBlockedByKitchen(MenuItem item, KitchenStatus kitchen) =>
    item.kitchen && !kitchen.openNow;

/// Itens do carrinho que a cozinha fechada impede (vazio = pode seguir).
List<MenuItem> kitchenBlockedItems(Iterable<MenuItem> items, KitchenStatus kitchen) =>
    kitchen.openNow ? const [] : items.where((i) => i.kitchen).toList();

/// O erro (do Dio ou o corpo já decodificado) é o `kitchenClosed` do servidor?
bool isKitchenClosedError(Object? e) {
  Object? data = e;
  if (e is DioException) data = e.response?.data;
  return data is Map && data['error'] == 'kitchenClosed';
}

// ---------------------------------------------------------------------------
// Lado do estabelecimento: configuração (GET/POST /establishment/kitchen).
// ---------------------------------------------------------------------------

/// Uma semana de horários: 7 dias (índice 0 = domingo, igual ao horário do bar
/// em `weeklyHours`), cada dia com 0..2 janelas `{o: "HH:MM", c: "HH:MM"}`.
/// Dia sem janela = cozinha fechada o dia todo.
typedef WeeklyHours = List<List<Map<String, String>>>;

final _hhmm = RegExp(r'^\d{2}:\d{2}$');

/// Lê `kitchenHours` no MESMO formato do horário do bar. Devolve null quando o
/// formato é desconhecido (o app não sabe editar → não sobrescreve).
/// `null`/ausente = ainda não configurado → semana vazia (editável).
WeeklyHours? parseKitchenHours(Object? raw) {
  if (raw == null) return List.generate(7, (_) => <Map<String, String>>[]);
  if (raw is! List || raw.length != 7) return null;
  final week = <List<Map<String, String>>>[];
  for (final day in raw) {
    if (day is! List || day.length > 2) return null;
    final windows = <Map<String, String>>[];
    for (final w in day) {
      if (w is! Map) return null;
      final o = w['o'], c = w['c'];
      if (o is! String || c is! String || !_hhmm.hasMatch(o) || !_hhmm.hasMatch(c)) return null;
      windows.add({'o': o, 'c': c});
    }
    week.add(windows);
  }
  return week;
}

/// Configuração da cozinha do bar logado.
class KitchenConfig {
  /// Horário editável; null = formato desconhecido (configurar no painel web).
  final WeeklyHours? hours;

  /// `kitchenHours` cru como veio do servidor — devolvido intacto ao salvar
  /// quando o app não entende o formato (nunca sobrescreve o que não conhece).
  final Object? rawHours;

  /// Categorias do cardápio que são "cozinha" (comida).
  final List<String> categories;

  const KitchenConfig({required this.hours, required this.rawHours, required this.categories});

  bool get hoursEditable => hours != null;

  factory KitchenConfig.fromJson(Map<String, dynamic> j) {
    final raw = j['kitchenHours'];
    return KitchenConfig(
      hours: parseKitchenHours(raw),
      rawHours: raw,
      categories: ((j['kitchenCategories'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
    );
  }

  /// Corpo do POST. Horário em formato desconhecido volta exatamente como veio.
  Map<String, dynamic> toJson() => {
        'kitchenHours': hours ?? rawHours,
        'kitchenCategories': categories,
      };

  KitchenConfig copyWith({WeeklyHours? hours, List<String>? categories}) => KitchenConfig(
        hours: hours ?? this.hours,
        rawHours: rawHours,
        categories: categories ?? this.categories,
      );
}

/// Cópia profunda da semana (o editor mexe na cópia; o original serve pro
/// rollback se o POST falhar).
WeeklyHours copyWeek(WeeklyHours w) =>
    [for (final d in w) [for (final x in d) Map<String, String>.from(x)]];
