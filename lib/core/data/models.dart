// Modelos de domínio do app (lado do cliente).
//
// Por ora populados pelo seed de demonstração do design (seed_data.dart);
// depois virão da API pública (/api/public/...).

class Establishment {
  final String id;
  final String? slug;
  final String name;
  final String location;
  final String cuisine;
  final int orders;
  final double rating;
  final bool open;

  const Establishment({
    required this.id,
    this.slug,
    required this.name,
    required this.location,
    required this.cuisine,
    required this.orders,
    required this.rating,
    required this.open,
  });

  factory Establishment.fromJson(Map<String, dynamic> j) => Establishment(
    id: j['id'] as String,
    slug: j['slug'] as String?,
    name: j['name'] as String,
    location: (j['location'] as String?) ?? '',
    cuisine: (j['cuisine'] as String?) ?? '',
    orders: (j['orders'] as int?) ?? 0,
    rating: (j['rating'] as num?)?.toDouble() ?? 0,
    open: (j['open'] as bool?) ?? true,
  );
}

class MenuItem {
  final int id;
  final String? dbId; // API (cuid do item no Neon) — usado ao criar pedido
  final String name;
  final String desc;
  final double price;
  final double? oldPrice;
  final String category;
  final String? photoId; // seed (Unsplash)
  final String? photo; // API (URL direta)

  const MenuItem({
    required this.id,
    this.dbId,
    required this.name,
    required this.desc,
    required this.price,
    this.oldPrice,
    this.photoId,
    this.photo,
    required this.category,
  });

  String get photoUrl =>
      photo ??
      (photoId == null
          ? ''
          : 'https://images.unsplash.com/$photoId?auto=format&fit=crop&w=400&q=70');

  bool get hasOffer => oldPrice != null && oldPrice! > price;

  factory MenuItem.fromJson(Map<String, dynamic> j) => MenuItem(
    id: j['id'] as int,
    dbId: j['dbId'] as String?,
    name: j['name'] as String,
    desc: (j['desc'] as String?) ?? '',
    price: (j['price'] as num).toDouble(),
    oldPrice: j['old'] == null ? null : (j['old'] as num).toDouble(),
    category: (j['cat'] as String?) ?? '',
    photo: j['photo'] as String?,
  );
}

/// Pedido do cliente (retorno de `/api/public/orders`). `dbId` = id do pedido no
/// Neon, guardado localmente para acompanhar o status.
class ClientOrderItem {
  final String name;
  final int qty;
  final double price;

  const ClientOrderItem({required this.name, required this.qty, required this.price});

  factory ClientOrderItem.fromJson(Map<String, dynamic> j) => ClientOrderItem(
    name: j['name'] as String,
    qty: (j['qty'] as num).toInt(),
    price: (j['price'] as num).toDouble(),
  );
}

class ClientOrder {
  final String? dbId;
  final String code;
  final int ts;
  final List<ClientOrderItem> items;
  final double total; // subtotal
  final double grand; // total com taxas
  final String status; // aguardando | producao | entregue
  final String name;
  final String note;

  const ClientOrder({
    this.dbId,
    required this.code,
    required this.ts,
    required this.items,
    required this.total,
    required this.grand,
    required this.status,
    required this.name,
    required this.note,
  });

  factory ClientOrder.fromJson(Map<String, dynamic> j) => ClientOrder(
    dbId: j['dbId'] as String?,
    code: (j['code'] as String?) ?? '',
    ts: (j['ts'] as num?)?.toInt() ?? 0,
    items: ((j['items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(ClientOrderItem.fromJson)
        .toList(),
    total: (j['total'] as num?)?.toDouble() ?? 0,
    grand: (j['grand'] as num?)?.toDouble() ?? 0,
    status: (j['status'] as String?) ?? 'aguardando',
    name: (j['name'] as String?) ?? '',
    note: (j['note'] as String?) ?? '',
  );
}

/// Pedido REAL no painel do estabelecimento (de `/establishment/orders`,
/// formato do `toPanelOrder` do web).
class PanelOrderLine {
  final int qty;
  final String name;
  final double price;
  const PanelOrderLine({required this.qty, required this.name, required this.price});
}

class PanelSplit {
  final int people;
  final int paid;
  const PanelSplit({required this.people, required this.paid});
}

class PanelOrder {
  final int id;
  final String dbId;
  final String code;
  final String status; // aguardando | producao | entregue
  final String loc;
  final String? cust;
  final int ts; // epoch ms
  final String? note;
  final List<PanelOrderLine> items;
  final PanelSplit? split;

  const PanelOrder({
    required this.id,
    required this.dbId,
    required this.code,
    required this.status,
    required this.loc,
    this.cust,
    required this.ts,
    this.note,
    required this.items,
    this.split,
  });

  double get total => items.fold(0.0, (s, i) => s + i.qty * i.price);
  int get minutesAgo =>
      DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts)).inMinutes;

  factory PanelOrder.fromJson(Map<String, dynamic> j) {
    final splits = j['splits'] as Map<String, dynamic>?;
    return PanelOrder(
      id: (j['id'] as num?)?.toInt() ?? 0,
      dbId: (j['dbId'] as String?) ?? '',
      code: (j['code'] as String?) ?? '',
      status: (j['st'] as String?) ?? 'aguardando',
      loc: (j['loc'] as String?) ?? '',
      cust: j['cust'] as String?,
      ts: (j['ts'] as num?)?.toInt() ?? 0,
      note: j['note'] as String?,
      items: ((j['items'] as List?) ?? const []).map((it) {
        final l = it as List;
        return PanelOrderLine(
          qty: (l[0] as num).toInt(),
          name: l[1] as String,
          price: (l[2] as num).toDouble(),
        );
      }).toList(),
      split: splits == null
          ? null
          : PanelSplit(
              people: (splits['people'] as num).toInt(),
              paid: (splits['paid'] as num).toInt(),
            ),
    );
  }
}

/// Pedido no painel do estabelecimento.
class EstabOrder {
  final int id;
  final String status; // aguardando | producao | entregue
  final String loc;
  final String? customer;
  final int minutesAgo;
  final String? method; // pix | credito | debito | usdc
  final String? note;
  final List<(int qty, String name, int price)> items;
  final (int people, int paid)? split;

  const EstabOrder({
    required this.id,
    required this.status,
    required this.loc,
    this.customer,
    required this.minutesAgo,
    this.method,
    this.note,
    required this.items,
    this.split,
  });

  int get total => items.fold(0, (s, i) => s + i.$1 * i.$3);
}

/// Compra no backlog da plataforma (Admin).
class BacklogPurchase {
  final String code;
  final String estab;
  final String city;
  final int minutesAgo;
  final String method;
  final String card; // vazio = sem cartão
  final double total;
  final String items;

  const BacklogPurchase({
    required this.code,
    required this.estab,
    required this.city,
    required this.minutesAgo,
    required this.method,
    required this.card,
    required this.total,
    required this.items,
  });
}
