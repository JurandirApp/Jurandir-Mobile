/// Um pedido no rastreio por mesa (backlog do estabelecimento).
class TrackedOrder {
  final String code;
  final String customerName;
  final String customerPhone;
  final List<({String name, int qty})> items;
  final DateTime placedAt;
  final DateTime? deliveredAt;
  final String? waiter;

  const TrackedOrder({
    required this.code,
    required this.customerName,
    required this.customerPhone,
    required this.items,
    required this.placedAt,
    required this.deliveredAt,
    required this.waiter,
  });

  factory TrackedOrder.fromJson(Map<String, dynamic> j) => TrackedOrder(
        code: (j['code'] as String?) ?? '',
        customerName: (j['customerName'] as String?) ?? '',
        customerPhone: (j['customerPhone'] as String?) ?? '',
        items: ((j['items'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map((i) => (name: (i['name'] as String?) ?? '', qty: (i['qty'] as num?)?.toInt() ?? 0))
            .toList(),
        placedAt: DateTime.tryParse((j['placedAt'] as String?) ?? '') ?? DateTime.now(),
        deliveredAt: j['deliveredAt'] == null ? null : DateTime.tryParse(j['deliveredAt'] as String),
        waiter: j['waiter'] as String?,
      );
}

/// Uma mesa (ou label avulso) no rastreio do dia.
class TrackedTable {
  final String label;
  final bool registered; // mesa/QR cadastrada vs label avulso (app/mesa digitada)
  final int customers; // clientes distintos no dia
  final int orderCount;
  final List<TrackedOrder> orders;

  const TrackedTable({
    required this.label,
    required this.registered,
    required this.customers,
    required this.orderCount,
    required this.orders,
  });

  factory TrackedTable.fromJson(Map<String, dynamic> j) => TrackedTable(
        label: (j['label'] as String?) ?? '',
        registered: (j['registered'] as bool?) ?? false,
        customers: (j['customers'] as num?)?.toInt() ?? 0,
        orderCount: (j['orderCount'] as num?)?.toInt() ?? 0,
        orders: ((j['orders'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(TrackedOrder.fromJson)
            .toList(),
      );
}
