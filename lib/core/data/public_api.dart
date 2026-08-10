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
}

final publicApiProvider = Provider((ref) => PublicApi(ref.watch(apiClientProvider)));

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
