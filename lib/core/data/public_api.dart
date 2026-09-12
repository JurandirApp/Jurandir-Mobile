import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/waiter/data/waiter_models.dart';
import '../api/api_client.dart';
import 'models.dart';

/// Camada de API pública — dados reais do Neon via backend Next.js
/// (`/api/public/...`).
class PublicApi {
  final Dio _dio;
  const PublicApi(this._dio);

  Future<List<Establishment>> establishments() async {
    final res = await _dio.get<Map<String, dynamic>>('/establishments');
    final list = (res.data!['establishments'] as List).cast<Map<String, dynamic>>();
    return list.map(Establishment.fromJson).toList();
  }

  Future<List<MenuItem>> menu(String slug) async {
    final res = await _dio.get<Map<String, dynamic>>('/$slug');
    final list = (res.data!['menu'] as List).cast<Map<String, dynamic>>();
    return list.map(MenuItem.fromJson).toList();
  }

  /// "Bairro, Cidade" a partir das coordenadas do GPS (pro header "Você está
  /// em…"). Null se o backend não conseguir resolver.
  Future<String?> reverseGeocode(double lat, double lng) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/geocode/reverse',
      queryParameters: {'lat': lat, 'lng': lng},
    );
    return res.data?['label'] as String?;
  }

  /// Ofertas do dia — itens com desconto real de vários bares (cada um traz
  /// slug/nome do bar). Alimenta o carrossel da Home.
  Future<List<Offer>> offers() async {
    final res = await _dio.get<Map<String, dynamic>>('/offers');
    return ((res.data!['offers'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(Offer.fromJson)
        .toList();
  }

  /// Cria um pedido real (POST /orders). Devolve o pedido já no formato do app.
  Future<ClientOrder> createOrder(Map<String, dynamic> payload) async {
    final res = await _dio.post<Map<String, dynamic>>('/orders', data: payload);
    return ClientOrder.fromJson(res.data!['order'] as Map<String, dynamic>);
  }

  /// Cancela um pedido ainda não pago (DELETE /orders?id=). Best-effort: usado
  /// ao editar (descarta o pedido antigo antes de recriar). Nunca lança.
  Future<bool> cancelOrder(String id) async {
    try {
      final res = await _dio.delete<Map<String, dynamic>>(
        '/orders',
        queryParameters: {'id': id},
      );
      return (res.data?['ok'] as bool?) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Cria o pedido + cobra na carteira nativa (Google/Apple Pay) via Pagar.me.
  /// `walletType` = 'google_pay' | 'apple_pay'; `token` = tokenizationData.token.
  Future<({bool ok, String status, ClientOrder? order, String? detail})> createWalletOrder(
    Map<String, dynamic> order,
    String walletType,
    String token,
  ) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/orders/wallet',
      data: {'order': order, 'walletType': walletType, 'token': token},
    );
    final d = res.data!;
    return (
      ok: (d['ok'] as bool?) ?? false,
      status: (d['status'] as String?) ?? 'failed',
      order: d['order'] == null ? null : ClientOrder.fromJson(d['order'] as Map<String, dynamic>),
      detail: d['detail'] as String?,
    );
  }

  /// Cria o pedido de cartão (crédito/débito) e devolve a URL do checkout
  /// hospedado da Pagar.me. O app abre a URL; a confirmação vem pelo polling.
  Future<({bool ok, String? checkoutUrl, ClientOrder? order})> createCardCheckout(
    Map<String, dynamic> order,
  ) async {
    final res = await _dio.post<Map<String, dynamic>>('/orders/checkout', data: order);
    final d = res.data!;
    return (
      ok: (d['ok'] as bool?) ?? false,
      checkoutUrl: d['checkoutUrl'] as String?,
      order: d['order'] == null ? null : ClientOrder.fromJson(d['order'] as Map<String, dynamic>),
    );
  }

  /// Login real (POST /login). Lança `DioException` (401) se as credenciais
  /// forem inválidas. Só existem usuários ESTABLISHMENT e ADMIN.
  Future<({String token, String role, String name, String email, String? establishmentId, bool waiterModule})> login(
    String email,
    String password,
  ) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/login',
      data: {'email': email, 'password': password},
    );
    final d = res.data!;
    final u = d['user'] as Map<String, dynamic>;
    return (
      token: d['token'] as String,
      role: u['role'] as String, // ADMIN | ESTABLISHMENT
      name: u['name'] as String,
      email: u['email'] as String,
      establishmentId: u['establishmentId'] as String?,
      waiterModule: (u['waiterModule'] as bool?) ?? false,
    );
  }

  /// Status dos pedidos guardados localmente (GET /orders?ids=...).
  Future<List<ClientOrder>> myOrders(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final res = await _dio.get<Map<String, dynamic>>(
      '/orders',
      queryParameters: {'ids': ids.join(',')},
    );
    return ((res.data!['orders'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(ClientOrder.fromJson)
        .toList();
  }

  /// Pedidos reais do estabelecimento logado (GET autenticado por token).
  Future<List<PanelOrder>> establishmentOrders(String token) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/establishment/orders',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return ((res.data!['orders'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(PanelOrder.fromJson)
        .toList();
  }

  /// Marca um pedido do estabelecimento como entregue.
  Future<void> deliverEstablishmentOrder(String token, String orderId) async {
    await _dio.post<Map<String, dynamic>>(
      '/establishment/orders',
      data: {'orderId': orderId},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  /// Marca `qty` unidades de um item do pedido como prontas (bar → cozinha
  /// concluiu). `false` em 409 (já marcado/qty inválida) ou erro de rede.
  Future<bool> markItemReady(String token, String orderItemId, int qty) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/panel/order-items/$orderItemId/ready',
        data: {'qty': qty},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return (res.data?['ok'] as bool?) ?? false;
    } on DioException {
      return false;
    }
  }

  /// Cardápio real do estabelecimento logado.
  Future<List<PanelMenuItem>> establishmentMenu(String token) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/establishment/menu',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return ((res.data!['items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(PanelMenuItem.fromJson)
        .toList();
  }

  /// Cria ou edita um item (id no payload = edição; sem id = novo).
  Future<PanelMenuItem> saveMenuItem(String token, Map<String, dynamic> payload) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/establishment/menu',
      data: payload,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return PanelMenuItem.fromJson(res.data!['item'] as Map<String, dynamic>);
  }

  /// Exclui um item do cardápio.
  Future<void> deleteMenuItem(String token, String id) async {
    await _dio.delete<Map<String, dynamic>>(
      '/establishment/menu',
      queryParameters: {'id': id},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  /// Envia a foto de um item pro Cloudinary e devolve a URL https.
  /// Fluxo seguro: pede a assinatura pro backend (o api_secret nunca vem pro
  /// app) e faz o upload do arquivo direto pra Cloudinary.
  Future<String> uploadMenuPhoto(String token, File file) async {
    final sig = await _dio.get<Map<String, dynamic>>(
      '/establishment/menu/photo-sign',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final s = sig.data!;
    final cloudName = s['cloudName'] as String;
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: file.uri.pathSegments.last),
      'api_key': s['apiKey'],
      'timestamp': '${s['timestamp']}',
      'folder': s['folder'],
      'signature': s['signature'],
    });
    // Dio separado: URL absoluta da Cloudinary, fora do baseUrl do backend.
    final res = await Dio().post<Map<String, dynamic>>(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      data: form,
    );
    final url = res.data?['secure_url'] as String?;
    if (url == null) throw Exception('no-url');
    return url;
  }

  /// Slug do estabelecimento (p/ a URL do QR) + pontos de QR (mesas/guarda-sóis).
  Future<({String slug, List<QrSpot> spots})> establishmentQr(String token) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/establishment/qr',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final d = res.data!;
    final spots = ((d['spots'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(QrSpot.fromJson)
        .toList();
    return (slug: (d['slug'] as String?) ?? '', spots: spots);
  }

  Future<QrSpot> addQrSpot(String token, String label) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/establishment/qr',
      data: {'label': label},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return QrSpot.fromJson(res.data!['spot'] as Map<String, dynamic>);
  }

  Future<void> deleteQrSpot(String token, String id) async {
    await _dio.delete<Map<String, dynamic>>(
      '/establishment/qr',
      queryParameters: {'id': id},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  /// Visão geral da plataforma (Admin) — alimenta Dashboard/Cadastros/Backlog.
  Future<AdminOverview> adminOverview(String token) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/admin/overview',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return AdminOverview.fromJson(res.data!);
  }

  /// Atualiza o fee (%) de um estabelecimento (Admin · Taxas).
  Future<void> saveFee(String token, String id, int pct) async {
    await _dio.post<Map<String, dynamic>>(
      '/admin/fee',
      data: {'id': id, 'pct': pct},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  /// Troca a senha do estabelecimento logado. `ok=false` + `error` em falha
  /// ('currentWrong' = senha atual errada; 'invalid' = nova < 6).
  Future<({bool ok, String? error})> changePassword(
    String token,
    String current,
    String next,
  ) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/establishment/password',
        data: {'current': current, 'next': next},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return (ok: (res.data?['ok'] as bool?) ?? false, error: res.data?['error'] as String?);
    } on DioException catch (e) {
      final data = e.response?.data;
      final err = data is Map ? data['error'] as String? : null;
      return (ok: false, error: err ?? 'network');
    }
  }

  /// Perfil atual do estabelecimento logado (Estab · Perfil). Inclui campos de
  /// texto E o `weeklyHours` estruturado (List de 7 dias × janelas {o,c}), por
  /// isso o retorno é dinâmico.
  Future<Map<String, dynamic>> establishmentProfile(String token) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/establishment/profile',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return res.data ?? const {};
  }

  /// Salva o perfil do estabelecimento.
  Future<void> saveEstablishmentProfile(String token, Map<String, dynamic> payload) async {
    await _dio.post<Map<String, dynamic>>(
      '/establishment/profile',
      data: payload,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  /// Cria (sem id) ou edita (com id) um estabelecimento (Admin · Cadastros).
  Future<void> saveEstablishment(String token, Map<String, dynamic> payload) async {
    await _dio.post<Map<String, dynamic>>(
      '/admin/establishments',
      data: payload,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  /// Buscas dos visitantes por dimensão (Admin · Buscas).
  Future<AdminSearches> adminSearches(String token) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/admin/searches',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return AdminSearches.fromJson(res.data!);
  }

  /// Fila do garçom agrupada por pedido (GET /waiter/orders).
  Future<List<WaiterOrder>> waiterOrders(String token) async {
    final res = await _dio.get<Map<String, dynamic>>('/waiter/orders',
        options: Options(headers: {'Authorization': 'Bearer $token'}));
    return ((res.data!['orders'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(WaiterOrder.fromJson)
        .toList();
  }

  /// Entrega em LOTE de um pedido (POST /waiter/orders/:orderId/deliver): vários
  /// itens de uma vez, com um código só (os 4 últimos do telefone do cliente).
  /// Retorna sucesso, erro específico (code/qty/notfound) e se o pedido fechou.
  Future<({bool ok, String? error, bool orderDone})> waiterDeliverOrder(
      String token, String orderId, List<({String orderItemId, int qty})> items, String code) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/waiter/orders/$orderId/deliver',
        data: {
          'code': code,
          'items': items.map((i) => {'orderItemId': i.orderItemId, 'qty': i.qty}).toList(),
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final d = res.data!;
      return (ok: (d['ok'] as bool?) ?? false, error: null, orderDone: (d['orderDone'] as bool?) ?? false);
    } on DioException catch (e) {
      final err = (e.response?.data is Map) ? (e.response!.data['error'] as String?) : null;
      return (ok: false, error: err ?? 'erro', orderDone: false);
    }
  }

  /// Garçons do estabelecimento (com stats de entrega). GET /panel/waiters.
  Future<List<PanelWaiter>> panelWaiters(String token) async {
    final res = await _dio.get<Map<String, dynamic>>('/panel/waiters',
        options: Options(headers: {'Authorization': 'Bearer $token'}));
    return ((res.data!['waiters'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(PanelWaiter.fromJson)
        .toList();
  }

  /// Cria/edita um garçom (POST /panel/waiters; com `id` = editar).
  Future<void> panelUpsertWaiter(String token, Map<String, dynamic> payload) async {
    await _dio.post<Map<String, dynamic>>('/panel/waiters',
        data: payload, options: Options(headers: {'Authorization': 'Bearer $token'}));
  }

  /// Remove um garçom (DELETE /panel/waiters?id=...).
  Future<void> panelDeleteWaiter(String token, String id) async {
    await _dio.delete<Map<String, dynamic>>('/panel/waiters',
        queryParameters: {'id': id}, options: Options(headers: {'Authorization': 'Bearer $token'}));
  }
}

final publicApiProvider = Provider((ref) => PublicApi(ref.watch(apiClientProvider)));

/// Garçom do estabelecimento (painel): identidade + total de entregas/produtos.
class PanelWaiter {
  final String id, name, user;
  final int deliveries, products;
  const PanelWaiter({
    required this.id,
    required this.name,
    required this.user,
    this.deliveries = 0,
    this.products = 0,
  });
  factory PanelWaiter.fromJson(Map<String, dynamic> j) => PanelWaiter(
        id: (j['id'] as String?) ?? '',
        name: (j['name'] as String?) ?? '',
        user: (j['user'] as String?) ?? '',
        deliveries: (j['deliveries'] as num?)?.toInt() ?? 0,
        products: (j['products'] as num?)?.toInt() ?? 0,
      );
}

/// Garçons do estabelecimento logado (com stats). autoDispose: refaz o fetch ao
/// reentrar; invalide após criar/editar/excluir.
final estabWaitersProvider = FutureProvider.autoDispose<List<PanelWaiter>>((ref) async {
  final token = ref.watch(authProvider).token;
  if (token == null) return const [];
  return ref.watch(publicApiProvider).panelWaiters(token);
});

/// Mesa/guarda-sol que veio do QR (`?local=...`). Null quando o cliente entrou
/// sem QR (home/busca) — nesse caso o checkout pergunta a mesa antes de fechar.
class SelectedLocal extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? local) => state = local;
}

final selectedLocalProvider = NotifierProvider<SelectedLocal, String?>(SelectedLocal.new);

/// Slug do estabelecimento que o cliente abriu (setado ao tocar num card).
/// O cardápio e o checkout usam este slug para carregar/atribuir ao bar certo.
class SelectedSlug extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? slug) {
    // Trocou de bar → some a mesa antiga (evita usar a mesa de outro bar).
    if (slug != state) ref.read(selectedLocalProvider.notifier).set(null);
    state = slug;
  }
}

final selectedSlugProvider = NotifierProvider<SelectedSlug, String?>(SelectedSlug.new);

/// Estabelecimentos — dados reais da API. Erros propagam pra tela mostrar
/// carregamento/estado de erro (nunca caímos em dados falsos).
final establishmentsProvider = FutureProvider<List<Establishment>>((ref) async {
  return ref.watch(publicApiProvider).establishments();
});

/// Cardápio de um estabelecimento — dados reais da API. Erros propagam.
final menuProvider = FutureProvider.family<List<MenuItem>, String>((ref, slug) async {
  return ref.watch(publicApiProvider).menu(slug);
});

/// Ofertas do dia — itens com desconto real de vários bares. Erros propagam.
final offersProvider = FutureProvider<List<Offer>>((ref) async {
  return ref.watch(publicApiProvider).offers();
});

/// Pedidos reais do estabelecimento logado (usa o token do login). Sem token,
/// lista vazia. Erros propagam para a tela mostrar estado de erro/retry.
final establishmentOrdersProvider = FutureProvider<List<PanelOrder>>((ref) async {
  final token = ref.watch(authProvider).token;
  if (token == null) return const <PanelOrder>[];
  return ref.watch(publicApiProvider).establishmentOrders(token);
});

/// Cardápio real do estabelecimento logado.
final establishmentMenuProvider = FutureProvider<List<PanelMenuItem>>((ref) async {
  final token = ref.watch(authProvider).token;
  if (token == null) return const <PanelMenuItem>[];
  return ref.watch(publicApiProvider).establishmentMenu(token);
});

/// Pontos de QR (+ slug) do estabelecimento logado.
final establishmentQrProvider =
    FutureProvider<({String slug, List<QrSpot> spots})>((ref) async {
  final token = ref.watch(authProvider).token;
  if (token == null) return (slug: '', spots: const <QrSpot>[]);
  return ref.watch(publicApiProvider).establishmentQr(token);
});

/// Visão geral da plataforma (Admin). Null sem token.
final adminOverviewProvider = FutureProvider<AdminOverview?>((ref) async {
  final token = ref.watch(authProvider).token;
  if (token == null) return null;
  return ref.watch(publicApiProvider).adminOverview(token);
});

/// Buscas dos visitantes por dimensão (Admin). Null sem token.
final adminSearchesProvider = FutureProvider<AdminSearches?>((ref) async {
  final token = ref.watch(authProvider).token;
  if (token == null) return null;
  return ref.watch(publicApiProvider).adminSearches(token);
});

/// Perfil do estabelecimento logado (Estab · Perfil).
final establishmentProfileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final token = ref.watch(authProvider).token;
  if (token == null) return const {};
  return ref.watch(publicApiProvider).establishmentProfile(token);
});
