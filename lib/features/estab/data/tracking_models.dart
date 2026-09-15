/// Uma mesa (ou label avulso) no RESUMO do rastreio do dia — só os números,
/// pra tela principal ficar leve mesmo num dia lotado.
class TrackedTable {
  final String label;
  final bool registered; // mesa/QR cadastrada vs label avulso (app/mesa digitada)
  final int customers; // clientes distintos no dia
  final int orderCount;
  final double revenue; // faturamento do dia nessa mesa (R$)

  const TrackedTable({
    required this.label,
    required this.registered,
    required this.customers,
    required this.orderCount,
    required this.revenue,
  });

  factory TrackedTable.fromJson(Map<String, dynamic> j) => TrackedTable(
        label: (j['label'] as String?) ?? '',
        registered: (j['registered'] as bool?) ?? false,
        customers: (j['customers'] as num?)?.toInt() ?? 0,
        orderCount: (j['orderCount'] as num?)?.toInt() ?? 0,
        revenue: (j['revenue'] as num?)?.toDouble() ?? 0,
      );
}

/// Um pedido dentro do detalhe de uma mesa.
class TrackedClientOrder {
  final int number; // nº exibível (#161)
  final String code;
  final List<({String name, int qty})> items;
  final DateTime placedAt;
  final DateTime? deliveredAt;
  final String? waiter;
  final double total;

  const TrackedClientOrder({
    required this.number,
    required this.code,
    required this.items,
    required this.placedAt,
    required this.deliveredAt,
    required this.waiter,
    required this.total,
  });

  factory TrackedClientOrder.fromJson(Map<String, dynamic> j) => TrackedClientOrder(
        number: (j['number'] as num?)?.toInt() ?? 0,
        code: (j['code'] as String?) ?? '',
        items: ((j['items'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map((i) => (name: (i['name'] as String?) ?? '', qty: (i['qty'] as num?)?.toInt() ?? 0))
            .toList(),
        placedAt: DateTime.tryParse((j['placedAt'] as String?) ?? '') ?? DateTime.now(),
        deliveredAt: j['deliveredAt'] == null ? null : DateTime.tryParse(j['deliveredAt'] as String),
        waiter: j['waiter'] as String?,
        total: (j['total'] as num?)?.toDouble() ?? 0,
      );
}

/// Um cliente (pessoa) de uma mesa, com todos os pedidos dele no dia.
class TrackedClient {
  final String key;
  final String name;
  final String phone;
  final int orderCount;
  final double total;
  final List<TrackedClientOrder> orders;

  const TrackedClient({
    required this.key,
    required this.name,
    required this.phone,
    required this.orderCount,
    required this.total,
    required this.orders,
  });

  factory TrackedClient.fromJson(Map<String, dynamic> j) => TrackedClient(
        key: (j['key'] as String?) ?? '',
        name: (j['name'] as String?) ?? '',
        phone: (j['phone'] as String?) ?? '',
        orderCount: (j['orderCount'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toDouble() ?? 0,
        orders: ((j['orders'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(TrackedClientOrder.fromJson)
            .toList(),
      );
}

/// Detalhe de UMA mesa num dia: clientes (agrupados) e seus pedidos.
class TableDetail {
  final String label;
  final bool registered;
  final int customers;
  final int orderCount;
  final double total;
  final List<TrackedClient> clients;

  const TableDetail({
    required this.label,
    required this.registered,
    required this.customers,
    required this.orderCount,
    required this.total,
    required this.clients,
  });

  factory TableDetail.fromJson(Map<String, dynamic> j) => TableDetail(
        label: (j['label'] as String?) ?? '',
        registered: (j['registered'] as bool?) ?? false,
        customers: (j['customers'] as num?)?.toInt() ?? 0,
        orderCount: (j['orderCount'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toDouble() ?? 0,
        clients: ((j['clients'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(TrackedClient.fromJson)
            .toList(),
      );
}
