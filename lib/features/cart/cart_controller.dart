import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/models.dart';

/// Carrinho do cliente: quantidade por item + os próprios itens, para somar sem
/// depender de um catálogo global (o cardápio vem da API, com ids próprios).
class CartController extends Notifier<Map<int, int>> {
  final Map<int, MenuItem> _items = {};

  @override
  Map<int, int> build() => {};

  void add(MenuItem m) {
    _items[m.id] = m;
    state = {...state, m.id: (state[m.id] ?? 0) + 1};
  }

  void dec(int id) {
    final q = (state[id] ?? 0) - 1;
    final next = Map<int, int>.from(state);
    if (q <= 0) {
      next.remove(id);
      _items.remove(id);
    } else {
      next[id] = q;
    }
    state = next;
  }

  void clear() {
    _items.clear();
    state = {};
  }

  MenuItem? itemOf(int id) => _items[id];

  List<(MenuItem, int)> get lines =>
      [for (final e in state.entries) if (_items[e.key] != null) (_items[e.key]!, e.value)];

  double get total {
    var t = 0.0;
    for (final e in state.entries) {
      t += (_items[e.key]?.price ?? 0) * e.value;
    }
    return t;
  }
}

final cartProvider = NotifierProvider<CartController, Map<int, int>>(CartController.new);

int cartCount(Map<int, int> cart) => cart.values.fold(0, (a, b) => a + b);
