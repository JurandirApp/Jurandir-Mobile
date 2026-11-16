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

  group('createCardOrder · deviceSessionId', () {
    test('vai DENTRO do bloco tuna', () async {
      final t = _api(200, {'ok': true, 'status': 'paid'});
      await t.api.createCardOrder('ord_1', 'tok', method: 'credit',
          tuna: {'sessionId': 'sess', 'brand': 'Visa', 'deviceSessionId': 'a' * 32});
      final body = t.fake.last?.data as Map;
      expect(body['tuna'], {'sessionId': 'sess', 'brand': 'Visa', 'deviceSessionId': 'a' * 32});
      expect(body.containsKey('deviceSessionId'), isFalse);
    });
  });

  group('createWalletOrder', () {
    test('manda deviceSessionId no topo quando informado', () async {
      final t = _api(200, {'ok': true, 'status': 'paid'});
      final r = await t.api.createWalletOrder('ord_1', 'google_pay', 'gtok', deviceSessionId: 'b' * 32);
      expect(r.ok, isTrue);
      expect(t.fake.last?.path, '/orders/wallet');
      expect(t.fake.last?.data,
          {'orderId': 'ord_1', 'walletType': 'google_pay', 'token': 'gtok', 'deviceSessionId': 'b' * 32});
    });

    test('sem deviceSessionId o corpo fica como antes', () async {
      final t = _api(200, {'ok': false, 'status': 'failed'});
      await t.api.createWalletOrder('ord_1', 'google_pay', 'gtok');
      expect(t.fake.last?.data, {'orderId': 'ord_1', 'walletType': 'google_pay', 'token': 'gtok'});
    });
  });

  group('tunaFingerprint', () {
    test('200 ligado → config usável', () async {
      final t = _api(200, {'enabled': true, 'orgId': 'org', 'merchantId': 'm'});
      final c = await t.api.tunaFingerprint();
      expect(t.fake.last?.path, '/tuna/fingerprint');
      expect(t.fake.last?.method, 'GET');
      expect(c.usable, isTrue);
      expect(c.orgId, 'org');
      expect(c.merchantId, 'm');
    });

    test('200 desligado → não usável', () async {
      final c = await _api(200, {'enabled': false}).api.tunaFingerprint();
      expect(c.usable, isFalse);
    });

    test('500 → desligado (nunca lança)', () async {
      final c = await _api(500, {'error': 'x'}).api.tunaFingerprint();
      expect(c.usable, isFalse);
    });

    test('erro de rede → desligado (nunca lança)', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example/api/public'))
        ..httpClientAdapter = _ThrowingAdapter();
      final c = await PublicApi(dio).tunaFingerprint();
      expect(c.usable, isFalse);
    });
  });
}

/// Adapter que sempre falha (simula rede/timeout).
class _ThrowingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) =>
      throw DioException.connectionTimeout(timeout: const Duration(seconds: 8), requestOptions: options);

  @override
  void close({bool force = false}) {}
}
