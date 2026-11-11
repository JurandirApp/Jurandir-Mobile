import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
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
  group('tunaSession', () {
    test('200 → sessão + tokenUrl', () async {
      final t = _api(200, {'sessionId': 'sess', 'tokenUrl': 'https://token.tunagateway.com', 'env': 'TEST'});
      final r = await t.api.tunaSession('ord_1');
      expect(r.error, isNull);
      expect(r.session?.sessionId, 'sess');
      expect(r.session?.tokenUrl, 'https://token.tunagateway.com');
      expect(t.fake.last?.path, '/tuna/session');
      expect(t.fake.last?.data, {'orderId': 'ord_1'});
    });

    for (final c in [
      (404, 'orderNotFound'),
      (409, 'notChargeable'),
      (403, 'cardsDisabled'),
      (502, 'unavailable'),
      (500, 'unavailable'),
    ]) {
      test('${c.$1} → ${c.$2} (nunca lança)', () async {
        final r = await _api(c.$1, {'error': c.$2}).api.tunaSession('ord_1');
        expect(r.session, isNull);
        expect(r.error, c.$2);
      });
    }

    test('200 sem sessionId → unavailable', () async {
      final r = await _api(200, {'tokenUrl': 'https://t.example'}).api.tunaSession('ord_1');
      expect(r.session, isNull);
      expect(r.error, 'unavailable');
    });
  });

  group('createCardOrder', () {
    test('manda o bloco tuna quando informado', () async {
      final t = _api(200, {'ok': true, 'status': 'paid'});
      final r = await t.api.createCardOrder('ord_1', 'ct_abc',
          method: 'debit', customerDocument: '12345678909', tuna: {'sessionId': 'sess', 'brand': 'Visa'});
      expect(r.ok, isTrue);
      expect(r.status, 'paid');
      final body = t.fake.last?.data as Map;
      expect(body['tuna'], {'sessionId': 'sess', 'brand': 'Visa'});
      expect(body['method'], 'debit');
      expect(body['installments'], 1);
      expect(body.containsKey('billing'), isFalse);
      expect(body.containsKey('authenticationId'), isFalse);
    });

    test('sem tuna o corpo fica como antes', () async {
      final t = _api(200, {'ok': false, 'status': 'failed'});
      await t.api.createCardOrder('ord_1', 'tok', method: 'credit');
      expect((t.fake.last?.data as Map).containsKey('tuna'), isFalse);
    });
  });
}
