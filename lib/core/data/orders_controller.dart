import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';
import 'onboarding_controller.dart' show sharedPrefsProvider;
import 'public_api.dart';

/// Ids dos pedidos que ESTE aparelho criou (cliente anônimo do QR). Ficam
/// guardados em `shared_preferences` para a aba Pedidos consultar o status real.
class MyOrderIds extends Notifier<List<String>> {
  static const _key = 'my_order_ids';

  @override
  List<String> build() {
    return ref.watch(sharedPrefsProvider).getStringList(_key) ?? const [];
  }

  Future<void> add(String id) async {
    final prefs = ref.read(sharedPrefsProvider);
    final next = [id, ...state.where((x) => x != id)];
    await prefs.setStringList(_key, next);
    state = next;
  }
}

final myOrderIdsProvider =
    NotifierProvider<MyOrderIds, List<String>>(MyOrderIds.new);

/// Status real dos pedidos do cliente. `ref.invalidate(myOrdersProvider)`
/// (pull-to-refresh) refaz a consulta.
final myOrdersProvider = FutureProvider<List<ClientOrder>>((ref) async {
  final ids = ref.watch(myOrderIdsProvider);
  if (ids.isEmpty) return const [];
  try {
    return await ref.watch(publicApiProvider).myOrders(ids);
  } catch (_) {
    return const [];
  }
});
