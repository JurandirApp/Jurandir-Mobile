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
  final double platformFeePct; // comissão da plataforma (%)
  final double serviceFeePct; // taxa de serviço do bar (%)
  final double? lat; // coordenadas geocodificadas (null = sem geocode)
  final double? lng;
  final String? logo; // imagem quadrada do bar
  final String? cover; // capa (paisagem)

  const Establishment({
    required this.id,
    this.slug,
    required this.name,
    required this.location,
    required this.cuisine,
    required this.orders,
    required this.rating,
    required this.open,
    this.platformFeePct = 8,
    this.serviceFeePct = 10,
    this.lat,
    this.lng,
    this.logo,
    this.cover,
  });

  /// Melhor imagem pro thumb do card: logo (quadrada) → capa → nada.
  String? get imageUrl {
    if (logo != null && logo!.isNotEmpty) return logo;
    if (cover != null && cover!.isNotEmpty) return cover;
    return null;
  }

  factory Establishment.fromJson(Map<String, dynamic> j) => Establishment(
    id: j['id'] as String,
    slug: j['slug'] as String?,
    name: j['name'] as String,
    location: (j['location'] as String?) ?? '',
    cuisine: (j['cuisine'] as String?) ?? '',
    orders: (j['orders'] as int?) ?? 0,
    rating: (j['rating'] as num?)?.toDouble() ?? 0,
    open: (j['open'] as bool?) ?? true,
    platformFeePct: (j['platformFeePct'] as num?)?.toDouble() ?? 8,
    serviceFeePct: (j['serviceFeePct'] as num?)?.toDouble() ?? 10,
    lat: (j['lat'] as num?)?.toDouble(),
    lng: (j['lng'] as num?)?.toDouble(),
    logo: j['logo'] as String?,
    cover: j['cover'] as String?,
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

/// Uma oferta da Home ("Ofertas do dia"): o item em promoção + o bar dele
/// (slug/nome), pra abrir o cardápio certo ao tocar.
class Offer {
  final MenuItem item;
  final String estSlug;
  final String estName;

  const Offer({required this.item, required this.estSlug, required this.estName});

  factory Offer.fromJson(Map<String, dynamic> j) => Offer(
        item: MenuItem.fromJson(j),
        estSlug: (j['estSlug'] as String?) ?? '',
        estName: (j['estName'] as String?) ?? '',
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

/// Uma parte da conta dividida: valor, se já foi paga, e o Pix daquela pessoa.
class ClientShare {
  final double amount;
  final bool paid;
  final String? pixPayload;
  final String? pixQrImage;

  const ClientShare({
    required this.amount,
    required this.paid,
    this.pixPayload,
    this.pixQrImage,
  });

  factory ClientShare.fromJson(Map<String, dynamic> j) => ClientShare(
    amount: (j['amount'] as num?)?.toDouble() ?? 0,
    paid: (j['paid'] as bool?) ?? false,
    pixPayload: (j['pixPayload'] as String?)?.isNotEmpty == true ? j['pixPayload'] as String : null,
    pixQrImage: (j['pixQrImage'] as String?)?.isNotEmpty == true ? j['pixQrImage'] as String : null,
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
  final String? pixPayload; // copia-e-cola (só em pedido Pix aguardando)
  final String? pixQrImage; // PNG base64 (sem prefixo data:)
  final List<ClientShare>? splits; // partes da divisão (split real por Pix)

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
    this.pixPayload,
    this.pixQrImage,
    this.splits,
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
    pixPayload: (j['pixPayload'] as String?)?.isNotEmpty == true ? j['pixPayload'] as String : null,
    pixQrImage: (j['pixQrImage'] as String?)?.isNotEmpty == true ? j['pixQrImage'] as String : null,
    splits: (j['splits'] as List?)
        ?.cast<Map<String, dynamic>>()
        .map(ClientShare.fromJson)
        .toList(),
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
  final String pay; // pix | credito | debito | usdc
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
    this.pay = 'pix',
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
      pay: (j['pay'] as String?) ?? 'pix',
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

/// Item do cardápio no painel do estabelecimento (de `/establishment/menu`).
class PanelMenuItem {
  final String dbId;
  final String name;
  final String desc;
  final double price;
  final double? oldPrice;
  final String photo;
  final String cat;
  final String sub;
  final bool active;

  const PanelMenuItem({
    required this.dbId,
    required this.name,
    required this.desc,
    required this.price,
    this.oldPrice,
    required this.photo,
    required this.cat,
    required this.sub,
    required this.active,
  });

  factory PanelMenuItem.fromJson(Map<String, dynamic> j) => PanelMenuItem(
        dbId: (j['dbId'] as String?) ?? '',
        name: (j['name'] as String?) ?? '',
        desc: (j['desc'] as String?) ?? '',
        price: (j['price'] as num?)?.toDouble() ?? 0,
        oldPrice: j['old'] == null ? null : (j['old'] as num).toDouble(),
        photo: (j['photo'] as String?) ?? '',
        cat: (j['cat'] as String?) ?? '',
        sub: (j['sub'] as String?) ?? '',
        active: (j['active'] as bool?) ?? true,
      );
}

/// Ponto de QR (mesa/guarda-sol) no painel do estabelecimento.
class QrSpot {
  final String id;
  final String label;
  const QrSpot({required this.id, required this.label});

  factory QrSpot.fromJson(Map<String, dynamic> j) =>
      QrSpot(id: (j['id'] as String?) ?? '', label: (j['label'] as String?) ?? '');
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

/// Visão geral da plataforma (Admin) — de `/api/public/admin/overview`.
class AdminEstablishment {
  final String id;
  final String name;
  final String owner;
  final String type;
  final String city;
  final String plan;
  final String ownerEmail;
  final int feePct;
  final int orders;
  final double gmv;
  final double fees;
  final bool active;

  const AdminEstablishment({
    required this.id,
    required this.name,
    required this.owner,
    required this.type,
    required this.city,
    required this.plan,
    required this.ownerEmail,
    required this.feePct,
    required this.orders,
    required this.gmv,
    required this.fees,
    required this.active,
  });

  factory AdminEstablishment.fromJson(Map<String, dynamic> j) => AdminEstablishment(
        id: (j['id'] as String?) ?? '',
        name: (j['name'] as String?) ?? '',
        owner: (j['owner'] as String?) ?? '',
        type: (j['type'] as String?) ?? 'Bar',
        city: (j['city'] as String?) ?? '—',
        plan: (j['plan'] as String?) ?? '',
        ownerEmail: (j['ownerEmail'] as String?) ?? '',
        feePct: (j['feePct'] as num?)?.toInt() ?? 0,
        orders: (j['orders'] as num?)?.toInt() ?? 0,
        gmv: (j['gmv'] as num?)?.toDouble() ?? 0,
        fees: (j['fees'] as num?)?.toDouble() ?? 0,
        active: (j['active'] as bool?) ?? true,
      );
}

class AdminBacklogOrder {
  final String code;
  final String estab;
  final String city;
  final String method;
  final String card;
  final String items;
  final double total;
  final int ts;

  const AdminBacklogOrder({
    required this.code,
    required this.estab,
    required this.city,
    required this.method,
    required this.card,
    required this.items,
    required this.total,
    required this.ts,
  });

  factory AdminBacklogOrder.fromJson(Map<String, dynamic> j) => AdminBacklogOrder(
        code: (j['code'] as String?) ?? '',
        estab: (j['estab'] as String?) ?? '—',
        city: (j['city'] as String?) ?? '—',
        method: (j['method'] as String?) ?? 'pix',
        card: (j['card'] as String?) ?? '',
        items: (j['items'] as String?) ?? '',
        total: (j['total'] as num?)?.toDouble() ?? 0,
        ts: (j['ts'] as num?)?.toInt() ?? 0,
      );
}

class AdminOverview {
  final List<AdminEstablishment> establishments;
  final Map<String, double> byPayment;
  final double gmv;
  final double fees;
  final int orders;
  final int count;
  final List<AdminBacklogOrder> backlog;

  const AdminOverview({
    required this.establishments,
    required this.byPayment,
    required this.gmv,
    required this.fees,
    required this.orders,
    required this.count,
    required this.backlog,
  });

  factory AdminOverview.fromJson(Map<String, dynamic> j) {
    final pay = (j['byPayment'] as Map<String, dynamic>? ?? const {});
    final totals = (j['totals'] as Map<String, dynamic>? ?? const {});
    return AdminOverview(
      establishments: ((j['establishments'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(AdminEstablishment.fromJson)
          .toList(),
      byPayment: {for (final e in pay.entries) e.key: (e.value as num?)?.toDouble() ?? 0},
      gmv: (totals['gmv'] as num?)?.toDouble() ?? 0,
      fees: (totals['fees'] as num?)?.toDouble() ?? 0,
      orders: (totals['orders'] as num?)?.toInt() ?? 0,
      count: (totals['count'] as num?)?.toInt() ?? 0,
      backlog: ((j['backlog'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(AdminBacklogOrder.fromJson)
          .toList(),
    );
  }
}

/// Buscas dos visitantes por dimensão (Admin) — de `/api/public/admin/searches`.
class AdminSearchRow {
  final String label;
  final int count;
  const AdminSearchRow({required this.label, required this.count});
  factory AdminSearchRow.fromJson(Map<String, dynamic> j) =>
      AdminSearchRow(label: (j['label'] as String?) ?? '', count: (j['count'] as num?)?.toInt() ?? 0);
}

class AdminSearches {
  final int total;
  final Map<String, List<AdminSearchRow>> dims; // city | bairro | culinaria | tipo
  const AdminSearches({required this.total, required this.dims});

  factory AdminSearches.fromJson(Map<String, dynamic> j) {
    final d = (j['dims'] as Map<String, dynamic>? ?? const {});
    return AdminSearches(
      total: (j['total'] as num?)?.toInt() ?? 0,
      dims: {
        for (final e in d.entries)
          e.key: ((e.value as List?) ?? const [])
              .cast<Map<String, dynamic>>()
              .map(AdminSearchRow.fromJson)
              .toList(),
      },
    );
  }
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
