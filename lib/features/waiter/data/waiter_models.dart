/// Um pedido na fila do garçom (novo fluxo agrupado por pedido). Traz TODAS as
/// linhas ainda não 100% entregues — as prontas (entregáveis agora) e as que
/// ainda estão preparando (só informativas). O garçom abre o pedido, marca os
/// itens prontos que está levando e confirma tudo com o código do cliente.
class WaiterOrder {
  final String orderId;
  final String mesa;
  final String cliente;
  final List<WaiterOrderItem> items;

  const WaiterOrder({
    required this.orderId,
    required this.mesa,
    required this.cliente,
    required this.items,
  });

  factory WaiterOrder.fromJson(Map<String, dynamic> j) => WaiterOrder(
        orderId: (j['orderId'] as String?) ?? '',
        mesa: (j['mesa'] as String?) ?? '',
        cliente: (j['cliente'] as String?) ?? '',
        items: ((j['items'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(WaiterOrderItem.fromJson)
            .toList(),
      );

  /// Linhas com ao menos 1 unidade pronta pra entregar agora.
  int get readyLines => items.where((i) => i.qtyReady > 0).length;
}

/// Uma linha do pedido na visão do garçom, com os contadores por estado.
class WaiterOrderItem {
  final String orderItemId;
  final String name;
  final int qtyReady; // pronto pra entregar agora
  final int qtyPreparing; // ainda na cozinha/bar (informativo)
  final int qtyOutForDelivery; // legado: pego mas não confirmado
  final int qtyDelivered; // já entregue

  const WaiterOrderItem({
    required this.orderItemId,
    required this.name,
    required this.qtyReady,
    required this.qtyPreparing,
    required this.qtyOutForDelivery,
    required this.qtyDelivered,
  });

  factory WaiterOrderItem.fromJson(Map<String, dynamic> j) => WaiterOrderItem(
        orderItemId: (j['orderItemId'] as String?) ?? '',
        name: (j['name'] as String?) ?? '',
        qtyReady: (j['qtyReady'] as num?)?.toInt() ?? 0,
        qtyPreparing: (j['qtyPreparing'] as num?)?.toInt() ?? 0,
        qtyOutForDelivery: (j['qtyOutForDelivery'] as num?)?.toInt() ?? 0,
        qtyDelivered: (j['qtyDelivered'] as num?)?.toInt() ?? 0,
      );

  bool get isReady => qtyReady > 0;
}
