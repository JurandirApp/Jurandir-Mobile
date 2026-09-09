import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/models.dart';

/// Uma opção escolhida de um adicional (snapshot pro carrinho e pro pedido).
class SelectedOption {
  final String groupId;
  final String groupName;
  final String optionId;
  final String name;
  final double priceDelta;

  const SelectedOption({
    required this.groupId,
    required this.groupName,
    required this.optionId,
    required this.name,
    required this.priceDelta,
  });
}

/// Uma linha do carrinho: um item + as opções escolhidas + quantidade. O mesmo
/// item com opções diferentes vira linhas separadas (chave = item + opções).
class CartLine {
  final String lineId; // assinatura: itemId + ids das opções ordenados
  final MenuItem item;
  final List<SelectedOption> options;
  final int qty;

  const CartLine({
    required this.lineId,
    required this.item,
    required this.options,
    required this.qty,
  });

  double get unitPrice =>
      item.price + options.fold(0.0, (s, o) => s + o.priceDelta);
  double get lineTotal => unitPrice * qty;

  /// "Grande, Bacon" — resumo das opções pra mostrar embaixo do nome.
  String get optionsLabel => options.map((o) => o.name).join(', ');

  CartLine copyWith({int? qty}) => CartLine(
        lineId: lineId,
        item: item,
        options: options,
        qty: qty ?? this.qty,
      );
}

/// Carrinho do cliente, indexado pela assinatura de (item + opções). Somar e
/// contar percorre as linhas; não depende de um catálogo global.
class CartController extends Notifier<Map<String, CartLine>> {
  @override
  Map<String, CartLine> build() => {};

  String _sig(int itemId, List<SelectedOption> opts) {
    final ids = opts.map((o) => o.optionId).toList()..sort();
    return '$itemId|${ids.join(',')}';
  }

  String _simpleSig(int itemId) => _sig(itemId, const []);

  /// Adiciona uma linha (com opções). Linhas idênticas somam quantidade.
  void addLine(MenuItem m, List<SelectedOption> opts, {int qty = 1}) {
    if (qty <= 0) return;
    final sig = _sig(m.id, opts);
    final existing = state[sig];
    state = {
      ...state,
      sig: CartLine(
        lineId: sig,
        item: m,
        options: List.unmodifiable(opts),
        qty: (existing?.qty ?? 0) + qty,
      ),
    };
  }

  /// Atalho pra item sem adicionais (botão "+" direto no cardápio).
  void addSimple(MenuItem m) => addLine(m, const []);

  /// Substitui a linha `lineId` pela nova seleção (Editar item no carrinho).
  void updateLine(String lineId, MenuItem m, List<SelectedOption> opts, int qty) {
    final next = Map<String, CartLine>.from(state)..remove(lineId);
    if (qty > 0) {
      final sig = _sig(m.id, opts);
      final existing = next[sig];
      next[sig] = CartLine(
        lineId: sig,
        item: m,
        options: List.unmodifiable(opts),
        qty: (existing?.qty ?? 0) + qty,
      );
    }
    state = next;
  }

  void incLine(String lineId) {
    final l = state[lineId];
    if (l == null) return;
    state = {...state, lineId: l.copyWith(qty: l.qty + 1)};
  }

  void decLine(String lineId) {
    final l = state[lineId];
    if (l == null) return;
    final q = l.qty - 1;
    final next = Map<String, CartLine>.from(state);
    if (q <= 0) {
      next.remove(lineId);
    } else {
      next[lineId] = l.copyWith(qty: q);
    }
    state = next;
  }

  void removeLine(String lineId) {
    if (!state.containsKey(lineId)) return;
    state = Map<String, CartLine>.from(state)..remove(lineId);
  }

  // Atalhos pra itens sem adicionais (stepper no cardápio).
  void decSimple(MenuItem m) => decLine(_simpleSig(m.id));

  void clear() => state = {};

  /// Quantidade total de um item somando todas as variações de opções.
  int qtyOfItem(int itemId) =>
      state.values.where((l) => l.item.id == itemId).fold(0, (a, l) => a + l.qty);

  List<CartLine> get lines => state.values.toList();

  double get total => state.values.fold(0.0, (t, l) => t + l.lineTotal);
}

final cartProvider =
    NotifierProvider<CartController, Map<String, CartLine>>(CartController.new);

int cartCount(Map<String, CartLine> cart) =>
    cart.values.fold(0, (a, l) => a + l.qty);

/// Id do pedido AWAITING_PAYMENT que o carrinho atual representa (Pix/cartão
/// gerado mas ainda não pago). Editar = voltar ao carrinho, mudar, e pagar de
/// novo — o pedido antigo é cancelado e um novo criado no lugar. Null = sem
/// pendência (fluxo normal de um pedido novo).
class PendingOrder extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? id) => state = id;
}

final pendingOrderProvider =
    NotifierProvider<PendingOrder, String?>(PendingOrder.new);
