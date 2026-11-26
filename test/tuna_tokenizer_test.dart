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

  test('Generate com singleUse: false (salvar cartão)', () {
    final c = tunaGenerateBody('sess_dev', card, singleUse: false)['card'] as Map<String, dynamic>;
    expect(c['singleUse'], false);
  });

  test('URL das operações de token só em HTTPS', () {
    expect(tunaTokenApiUrl('https://token.tunagateway.com/', 'List'), 'https://token.tunagateway.com/api/Token/List');
    expect(tunaTokenApiUrl('https://token.tunagateway.com', 'Bind'), 'https://token.tunagateway.com/api/Token/Bind');
    expect(tunaTokenApiUrl('http://token.tunagateway.com', 'Delete'), isNull);
  });

  group('cartões salvos · corpos', () {
    test('List / Bind / Delete', () {
      expect(tunaListBody('sess'), {'sessionId': 'sess'});
      expect(tunaBindBody('sess', 'tok', ' 123 '), {'sessionId': 'sess', 'token': 'tok', 'cvv': '123'});
      expect(tunaDeleteBody('sess', 'tok'), {'sessionId': 'sess', 'token': 'tok'});
    });
  });

  group('parseTunaList', () {
    test('lê os cartões (formato do staging) e monta o rótulo', () {
      final l = parseTunaList({
        'code': 1,
        'tokens': [
          {
            'token': 'tok_1',
            'brand': 'Master',
            'cardHolderName': 'FULANO',
            'expirationMonth': 1,
            'expirationYear': 2030,
            'maskedNumber': '520000xxxxxx2235',
            'singleUse': false,
            'bin': '520000',
          },
          {'token': '', 'brand': 'Visa'}, // sem token → ignora
          'lixo',
        ],
      });
      expect(l, hasLength(1));
      expect(l![0].token, 'tok_1');
      expect(l[0].brand, 'Master');
      expect(l[0].last4, '2235');
      expect(l[0].label, 'Mastercard •••• 2235 · 01/30');
    });
    test('sem tokens → lista vazia; code < 0 / formato estranho → null', () {
      expect(parseTunaList({'code': 1, 'tokens': []}), isEmpty);
      expect(parseTunaList({'code': 1}), isEmpty);
      expect(parseTunaList({'code': -1, 'message': 'Session has expired'}), isNull);
      expect(parseTunaList({'tokens': []}), isNull);
      expect(parseTunaList({'code': 1, 'tokens': 'x'}), isNull);
      expect(parseTunaList(null), isNull);
    });
    test('rótulo sem bandeira nem validade', () {
      const c = TunaSavedCard(token: 't', maskedNumber: '411111xxxxxx1111');
      expect(c.label, 'Cartão •••• 1111');
    });
  });

  test('parseTunaOk: Bind e Delete', () {
    expect(parseTunaOk({'code': 1, 'message': 'Bind succeded', 'validFor': 1200}), isTrue);
    expect(parseTunaOk({'status': 'Success', 'code': 1}), isTrue);
    expect(parseTunaOk({'code': -1}), isFalse);
    expect(parseTunaOk({'status': 'Success'}), isFalse);
    expect(parseTunaOk(null), isFalse);
  });

  group('chamadas de cartões salvos', () {
    test('List posta direto na Tuna e devolve os cartões', () async {
      final fake = _FakeAdapter(200, {
        'code': 1,
        'tokens': [
          {'token': 'tok_1', 'brand': 'Visa', 'maskedNumber': '411111xxxxxx1111'}
        ],
      });
      final dio = Dio()..httpClientAdapter = fake;
      final l = await tunaListCards(tokenUrl: 'https://token.tunagateway.com', sessionId: 'sess', dio: dio);
      expect(l?.single.token, 'tok_1');
      expect(fake.last?.uri.toString(), 'https://token.tunagateway.com/api/Token/List');
      expect(fake.lastBody, {'sessionId': 'sess'});
    });

    test('Bind manda sessão + token + CVV', () async {
      final fake = _FakeAdapter(200, {'code': 1, 'message': 'Bind succeded', 'validFor': 1200});
      final dio = Dio()..httpClientAdapter = fake;
      final ok = await tunaBindCvv(
          tokenUrl: 'https://token.tunagateway.com', sessionId: 'sess', token: 'tok_1', cvv: '321', dio: dio);
      expect(ok, isTrue);
      expect(fake.last?.uri.toString(), 'https://token.tunagateway.com/api/Token/Bind');
      expect(fake.lastBody, {'sessionId': 'sess', 'token': 'tok_1', 'cvv': '321'});
    });

    test('Delete manda sessão + token', () async {
      final fake = _FakeAdapter(200, {'status': 'Success', 'code': 1});
      final dio = Dio()..httpClientAdapter = fake;
      final ok = await tunaDeleteCard(tokenUrl: 'https://token.tunagateway.com', sessionId: 'sess', token: 'tok_1', dio: dio);
      expect(ok, isTrue);
      expect(fake.last?.uri.toString(), 'https://token.tunagateway.com/api/Token/Delete');
      expect(fake.lastBody, {'sessionId': 'sess', 'token': 'tok_1'});
    });

    test('falhas → null/false (nunca lança)', () async {
      final dio = Dio()..httpClientAdapter = _FakeAdapter(500, {'error': 'x'});
      expect(await tunaListCards(tokenUrl: 'https://t.example', sessionId: 's', dio: dio), isNull);
      expect(await tunaBindCvv(tokenUrl: 'https://t.example', sessionId: 's', token: 't', cvv: '1', dio: dio), isFalse);
      expect(await tunaDeleteCard(tokenUrl: 'https://t.example', sessionId: 's', token: 't', dio: dio), isFalse);
      final neg = Dio()..httpClientAdapter = _FakeAdapter(200, {'code': -1});
      expect(await tunaBindCvv(tokenUrl: 'https://t.example', sessionId: 's', token: 't', cvv: '1', dio: neg), isFalse);
    });

    test('Generate salvando manda singleUse false', () async {
      final fake = _FakeAdapter(200, {'code': 1, 'token': 'tok_salvo', 'brand': 'Visa'});
      final dio = Dio()..httpClientAdapter = fake;
      final t = await tunaGenerateToken(
          tokenUrl: 'https://t.example', sessionId: 'sess_dev', card: card, singleUse: false, dio: dio);
      expect(t?.token, 'tok_salvo');
      expect(((fake.lastBody as Map)['card'] as Map)['singleUse'], false);
    });
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
