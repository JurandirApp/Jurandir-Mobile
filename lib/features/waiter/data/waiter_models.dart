/// Item na fila do garçom. `qtyReady` = pronto pra PEGAR; `qtyOutForDelivery` =
/// já em entrega (permite retomar a confirmação por código se o garçom saiu da
/// tela sem confirmar). Um item pode ter os dois > 0 ao mesmo tempo.
class ReadyItem {
  final String orderId, orderItemId, name, mesa, cliente;
  final int qtyReady;
  final int qtyOutForDelivery;
  const ReadyItem({required this.orderId, required this.orderItemId, required this.name,
    required this.mesa, required this.cliente, required this.qtyReady, this.qtyOutForDelivery = 0});
  factory ReadyItem.fromJson(Map<String, dynamic> j) => ReadyItem(
    orderId: (j['orderId'] as String?) ?? '', orderItemId: (j['orderItemId'] as String?) ?? '',
    name: (j['name'] as String?) ?? '', mesa: (j['mesa'] as String?) ?? '',
    cliente: (j['cliente'] as String?) ?? '', qtyReady: (j['qtyReady'] as num?)?.toInt() ?? 0,
    qtyOutForDelivery: (j['qtyOutForDelivery'] as num?)?.toInt() ?? 0);
}

/// Resultado de "pegar" um item: sucesso, já-pego-por-outro (409) ou falha de
/// rede/servidor — distinguidos pra não mostrar "outro garçom já pegou" quando
/// na verdade foi a conexão que caiu.
enum PickResult { ok, taken, error }
