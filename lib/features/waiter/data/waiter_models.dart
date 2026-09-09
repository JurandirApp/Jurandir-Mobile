class ReadyItem {
  final String orderId, orderItemId, name, mesa, cliente;
  final int qtyReady;
  const ReadyItem({required this.orderId, required this.orderItemId, required this.name,
    required this.mesa, required this.cliente, required this.qtyReady});
  factory ReadyItem.fromJson(Map<String, dynamic> j) => ReadyItem(
    orderId: (j['orderId'] as String?) ?? '', orderItemId: (j['orderItemId'] as String?) ?? '',
    name: (j['name'] as String?) ?? '', mesa: (j['mesa'] as String?) ?? '',
    cliente: (j['cliente'] as String?) ?? '', qtyReady: (j['qtyReady'] as num?)?.toInt() ?? 0);
}
