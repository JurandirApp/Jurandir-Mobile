import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_controller.dart';
import '../api/api_client.dart';
import 'models.dart';
import 'seed_data.dart';

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

  /// Cria um pedido real (POST /orders). Devolve o pedido já no formato do app.
  Future<ClientOrder> createOrder(Map<String, dynamic> payload) async {
    final res = await _dio.post<Map<String, dynamic>>('/orders', data: payload);
    return ClientOrder.fromJson(res.data!['order'] as Map<String, dynamic>);
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
  Future<({String token, String role, String name, String email, String? establishmentId})> login(
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

  /// Perfil atual do estabelecimento logado (Estab · Perfil).
  Future<Map<String, String>> establishmentProfile(String token) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/establishment/profile',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final d = res.data!;
    return {for (final e in d.entries) e.key: (e.value as String?) ?? ''};
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
}

final publicApiProvider = Provider((ref) => PublicApi(ref.watch(apiClientProvider)));

/// Slug do estabelecimento que o cliente abriu (setado ao tocar num card).
/// O cardápio e o checkout usam este slug para carregar/atribuir ao bar certo.
class SelectedSlug extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? slug) => state = slug;
}

final selectedSlugProvider = NotifierProvider<SelectedSlug, String?>(SelectedSlug.new);

/// Estabelecimentos — API real com fallback pro seed (o app roda sem backend).
final establishmentsProvider = FutureProvider<List<Establishment>>((ref) async {
  try {
    return await ref.watch(publicApiProvider).establishments();
  } catch (_) {
    return kEstablishments;
  }
});

/// Cardápio de um estabelecimento — API real com fallback pro seed.
final menuProvider = FutureProvider.family<List<MenuItem>, String>((ref, slug) async {
  try {
    return await ref.watch(publicApiProvider).menu(slug);
  } catch (_) {
    return kMenu;
  }
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
final establishmentProfileProvider = FutureProvider<Map<String, String>>((ref) async {
  final token = ref.watch(authProvider).token;
  if (token == null) return const {};
  return ref.watch(publicApiProvider).establishmentProfile(token);
});
