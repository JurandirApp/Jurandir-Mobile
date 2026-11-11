import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jurandir/core/payments/tuna_tokenizer.dart';

/// Adapter falso: guarda o pedido e devolve uma resposta fixa (sem rede).
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.status, this.body);
  final int status;
  final Object body;
  RequestOptions? last;
  Object? lastBody;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    last = options;
    lastBody = options.data;
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const card = TunaCard(number: '4111 1111 1111 1111', holder: ' FULANO ', expMonth: 2, expYear: 2031, cvv: '123');

  test('monta o corpo do Generate (dígitos, ano 4 dígitos, uso único)', () {
    final b = tunaGenerateBody('sess', card);
    final c = b['card'] as Map<String, dynamic>;
    expect(b['sessionId'], 'sess');
    expect(c['cardNumber'], '4111111111111111');
    expect(c['cardHolderName'], 'FULANO');
    expect(c['expirationMonth'], 2);
    expect(c['expirationYear'], 2031);
    expect(c['cvv'], '123');
    expect(c['singleUse'], true);
  });

  test('URL do Generate só em HTTPS', () {
    expect(tunaGenerateUrl('https://token.tunagateway.com'), 'https://token.tunagateway.com/api/Token/Generate');
    expect(tunaGenerateUrl('https://token.tunagateway.com/'), 'https://token.tunagateway.com/api/Token/Generate');
    expect(tunaGenerateUrl('http://token.tunagateway.com'), isNull);
    expect(tunaGenerateUrl(''), isNull);
  });

  group('parseTunaGenerate', () {
    test('code 1 com token → token + bandeira', () {
      final t = parseTunaGenerate({'code': 1, 'token': 'ct_abc', 'brand': 'Visa'});
      expect(t?.token, 'ct_abc');
      expect(t?.brand, 'Visa');
    });
    test('code negativo → null (cartão inválido)', () {
      expect(parseTunaGenerate({'code': -1, 'message': 'Card number is invalid'}), isNull);
    });
    test('sem token → null', () {
      expect(parseTunaGenerate({'code': 1}), isNull);
      expect(parseTunaGenerate({'code': 1, 'token': ''}), isNull);
    });
    test('resposta inesperada → null', () {
      expect(parseTunaGenerate(null), isNull);
      expect(parseTunaGenerate('erro'), isNull);
      expect(parseTunaGenerate({'token': 'ct_abc'}), isNull); // sem code
    });
    test('sem bandeira → brand null', () {
      expect(parseTunaGenerate({'code': 1, 'token': 'ct_abc'})?.brand, isNull);
    });
  });

  group('tunaGenerateToken', () {
    test('posta direto na Tuna, sem headers do backend', () async {
      final fake = _FakeAdapter(200, {'code': 1, 'token': 'ct_abc', 'brand': 'Master'});
      final dio = Dio()..httpClientAdapter = fake;
      final t = await tunaGenerateToken(
          tokenUrl: 'https://token.tunagateway.com', sessionId: 'sess', card: card, dio: dio);
      expect(t?.token, 'ct_abc');
      expect(t?.brand, 'Master');
      expect(fake.last?.uri.toString(), 'https://token.tunagateway.com/api/Token/Generate');
      expect(fake.last?.headers.containsKey('Authorization'), isFalse);
      expect((fake.lastBody as Map)['sessionId'], 'sess');
    });

    test('code < 0 → null', () async {
      final dio = Dio()..httpClientAdapter = _FakeAdapter(200, {'code': -1, 'message': 'Session has expired'});
      expect(await tunaGenerateToken(tokenUrl: 'https://t.example', sessionId: 's', card: card, dio: dio), isNull);
    });

    test('erro HTTP → null (nunca lança)', () async {
      final dio = Dio()..httpClientAdapter = _FakeAdapter(500, {'error': 'x'});
      expect(await tunaGenerateToken(tokenUrl: 'https://t.example', sessionId: 's', card: card, dio: dio), isNull);
    });

    test('tokenUrl sem HTTPS → null sem chamar a rede', () async {
      final fake = _FakeAdapter(200, {'code': 1, 'token': 'ct_abc'});
      final dio = Dio()..httpClientAdapter = fake;
      expect(await tunaGenerateToken(tokenUrl: 'http://t.example', sessionId: 's', card: card, dio: dio), isNull);
      expect(fake.last, isNull);
    });
  });
}
