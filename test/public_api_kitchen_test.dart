import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jurandir/core/data/kitchen.dart';
import 'package:jurandir/core/data/public_api.dart';

/// Adapter falso: guarda o último pedido e responde status/corpo fixos.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.status, this.body);
  final int status;
  final Object body;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    last = options;
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

({PublicApi api, _FakeAdapter fake}) _api(int status, Object body) {
  final fake = _FakeAdapter(status, body);
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example/api/public'))..httpClientAdapter = fake;
  return (api: PublicApi(dio), fake: fake);
}

void main() {
  test('menuData lê cardápio + cozinha da rota do slug', () async {
    final t = _api(200, {
      'est': {'kitchenOpenNow': false, 'kitchenNextOpenLabel': 'abre às 11:30'},
      'menu': [
        {'id': 1, 'name': 'Moqueca', 'price': 90, 'kitchen': true},
        {'id': 2, 'name': 'Água', 'price': 5, 'kitchen': false},
      ],
    });
    final d = await t.api.menuData('bar-x');
    expect(t.fake.last?.path, '/bar-x');
    expect(d.kitchen.openNow, isFalse);
    expect(d.kitchen.nextOpenLabel, 'abre às 11:30');
    expect(d.items.where((i) => i.kitchen).map((i) => i.name), ['Moqueca']);
    // `menu()` continua devolvendo só os itens (compatível com quem já usava).
    expect((await t.api.menu('bar-x')).length, 2);
  });

  test('establishmentKitchen manda o Bearer e parseia', () async {
    final t = _api(200, {
      'kitchenHours': List.generate(7, (i) => i == 6 ? [{'o': '12:00', 'c': '16:00'}] : []),
      'kitchenCategories': ['Pratos'],
    });
    final cfg = await t.api.establishmentKitchen('tok');
    expect(t.fake.last?.path, '/establishment/kitchen');
    expect(t.fake.last?.headers['Authorization'], 'Bearer tok');
    expect(cfg.hours![6].single, {'o': '12:00', 'c': '16:00'});
    expect(cfg.categories, ['Pratos']);
  });

  test('saveEstablishmentKitchen faz POST com o corpo do contrato', () async {
    final t = _api(200, {'ok': true});
    final cfg = KitchenConfig.fromJson({}).copyWith(categories: ['Porções']);
    await t.api.saveEstablishmentKitchen('tok', cfg);
    expect(t.fake.last?.method, 'POST');
    final body = t.fake.last?.data as Map<String, dynamic>;
    expect(body['kitchenCategories'], ['Porções']);
    expect((body['kitchenHours'] as List).length, 7);
  });

  test('saveEstablishmentKitchen lança em erro (a tela faz rollback)', () async {
    final t = _api(500, {'error': 'x'});
    expect(() => t.api.saveEstablishmentKitchen('tok', KitchenConfig.fromJson({})), throwsA(isA<DioException>()));
  });
}
