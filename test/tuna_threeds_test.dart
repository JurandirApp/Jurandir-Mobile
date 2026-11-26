import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jurandir/core/data/public_api.dart';
import 'package:jurandir/core/payments/tuna_threeds.dart';
import 'package:jurandir/core/payments/tuna_tokenizer.dart';

/// Adapter falso: guarda o pedido e devolve uma resposta fixa (sem rede).
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

const _authJson = {
  'accessToken': 'jwt.ddc',
  'deviceDataCollectionUrl': 'https://centinelapi.cardinalcommerce.com/V1/Cruise/Collect',
  'referenceId': 'ref-1',
  'transactionId': 'tx-1',
  'token': 'x',
};

String _paRequest(Object size) => base64.encode(utf8.encode(jsonEncode({'challengeWindowSize': size, 'x': 1})));

void main() {
  const card = TunaCard(number: '5200 0000 0000 2235', holder: 'FULANO', expMonth: 1, expYear: 2030, cvv: '123');

  group('código 3DS', () {
    test('formato j3ds_ + 24 hex, dentro do limite do servidor', () {
      for (var i = 0; i < 50; i++) {
        final c = newTunaThreeDsCode();
        expect(c, matches(RegExp(r'^j3ds_[0-9a-f]{24}$')));
        expect(c.length, lessThanOrEqualTo(50));
        expect(tunaThreeDsCodePattern.hasMatch(c), isTrue);
      }
    });

    test('aleatório (Random.secure por padrão) e determinístico com seed', () {
      expect(newTunaThreeDsCode(), isNot(newTunaThreeDsCode()));
      expect(newTunaThreeDsCode(Random(1)), newTunaThreeDsCode(Random(1)));
    });
  });

  group('Generate / Bind com authenticationInformation', () {
    test('Generate manda o código quando informado', () {
      final b = tunaGenerateBody('sess', card, authCode: 'j3ds_abc12345');
      expect(b['authenticationInformation'], {'code': 'j3ds_abc12345'});
      expect(tunaGenerateBody('sess', card).containsKey('authenticationInformation'), isFalse);
      expect(tunaGenerateBody('sess', card, authCode: '').containsKey('authenticationInformation'), isFalse);
    });

    test('Bind manda o código quando informado', () {
      expect(tunaBindBody('s', 't', '123', authCode: 'j3ds_abc12345'), {
        'sessionId': 's',
        'token': 't',
        'cvv': '123',
        'authenticationInformation': {'code': 'j3ds_abc12345'},
      });
    });

    test('parse do Generate traz os dados 3DS', () {
      final t = parseTunaGenerate({'code': 1, 'token': 'ct', 'brand': 'Master', 'authenticationInformation': _authJson});
      expect(t?.token, 'ct');
      expect(t?.auth?.referenceId, 'ref-1');
      expect(t?.auth?.transactionId, 'tx-1');
      expect(t?.auth?.accessToken, 'jwt.ddc');
      expect(t?.auth?.canCollect, isTrue);
    });

    test('sem authenticationInformation (crédito) → auth null', () {
      expect(parseTunaGenerate({'code': 1, 'token': 'ct'})?.auth, isNull);
    });

    test('auth sem referenceId/transactionId → null; sem DDC → não coleta', () {
      expect(parseTunaAuthInfo({'authenticationInformation': {'referenceId': 'r'}}), isNull);
      expect(parseTunaAuthInfo({'authenticationInformation': 'x'}), isNull);
      final a = parseTunaAuthInfo({
        'authenticationInformation': {'referenceId': 'r', 'transactionId': 't'}
      });
      expect(a, isNotNull);
      expect(a!.canCollect, isFalse);
      final http = parseTunaAuthInfo({
        'authenticationInformation': {..._authJson, 'deviceDataCollectionUrl': 'http://x.example'}
      });
      expect(http!.canCollect, isFalse);
    });

    test('tunaGenerateToken manda o código e lê os dados 3DS', () async {
      final fake = _FakeAdapter(200, {'code': 1, 'token': 'ct', 'authenticationInformation': _authJson});
      final dio = Dio()..httpClientAdapter = fake;
      final t = await tunaGenerateToken(
          tokenUrl: 'https://token.tunagateway.com', sessionId: 's', card: card, authCode: 'j3ds_abc12345', dio: dio);
      expect((fake.last?.data as Map)['authenticationInformation'], {'code': 'j3ds_abc12345'});
      expect(t?.auth?.referenceId, 'ref-1');
    });

    test('tunaBind: com auth na resposta, sem auth e falha', () async {
      Future<({bool ok, TunaAuthInfo? auth})> bind(Object body) => tunaBind(
          tokenUrl: 'https://token.tunagateway.com',
          sessionId: 's',
          token: 't',
          cvv: '123',
          authCode: 'j3ds_abc12345',
          dio: Dio()..httpClientAdapter = _FakeAdapter(200, body));
      final withAuth = await bind({'code': 1, 'authenticationInformation': _authJson});
      expect(withAuth.ok, isTrue);
      expect(withAuth.auth?.transactionId, 'tx-1');
      final noAuth = await bind({'code': 1});
      expect(noAuth.ok, isTrue);
      expect(noAuth.auth, isNull);
      final fail = await bind({'code': -1, 'authenticationInformation': _authJson});
      expect(fail.ok, isFalse);
      expect(fail.auth, isNull);
    });
  });

  group('blocos da cobrança', () {
    test('threeDs', () {
      const a = TunaAuthInfo(referenceId: 'r', transactionId: 't');
      expect(tunaThreeDsBlock('j3ds_abc12345', a), {'code': 'j3ds_abc12345', 'referenceId': 'r', 'transactionId': 't'});
    });

    test('browser: px lógicos inteiros, fuso na convenção do JS', () {
      final b = tunaBrowserBlock(
        screenWidth: 392.7,
        screenHeight: 850.2,
        timeZoneOffset: const Duration(hours: -3),
        languageTag: 'pt-BR',
      );
      expect(b, {
        'acceptLanguage': 'pt-BR',
        'colorDepth': 24,
        'screenHeight': 850,
        'screenWidth': 393,
        'timeDifference': 180,
        'javaEnabled': false,
        'javaScriptEnabled': true,
      });
      expect(
          tunaBrowserBlock(screenWidth: 1, screenHeight: 1, timeZoneOffset: Duration.zero).containsKey('acceptLanguage'),
          isFalse);
    });
  });

  group('challenge', () {
    test('parse: https obrigatório, token obrigatório', () {
      final c = parseTunaChallenge({
        'url': 'https://client.cardinaltrusted.com/centinelapi/V2/Cruise/StepUp',
        'token': 'jwt.step',
        'paRequest': 'abc',
      });
      expect(c?.url, 'https://client.cardinaltrusted.com/centinelapi/V2/Cruise/StepUp');
      expect(c?.token, 'jwt.step');
      expect(c?.paRequest, 'abc');
      expect(parseTunaChallenge({'url': 'http://x.example', 'token': 't'}), isNull);
      expect(parseTunaChallenge({'url': 'https://x.example', 'token': ''}), isNull);
      expect(parseTunaChallenge({'url': 'https://x.example'}), isNull);
      expect(parseTunaChallenge(null), isNull);
      expect(parseTunaChallenge({'url': 'https://x.example', 'token': 't'})?.paRequest, isNull);
    });

    test('tamanho da janela do paRequest', () {
      expect(tunaChallengeWindowSize(_paRequest('01')), (width: 250.0, height: 400.0));
      expect(tunaChallengeWindowSize(_paRequest('02')), (width: 390.0, height: 400.0));
      expect(tunaChallengeWindowSize(_paRequest('03')), (width: 500.0, height: 600.0));
      expect(tunaChallengeWindowSize(_paRequest('04')), (width: 600.0, height: 400.0));
      expect(tunaChallengeWindowSize(_paRequest(2)), (width: 390.0, height: 400.0)); // número
      expect(tunaChallengeWindowSize(_paRequest('05')), isNull); // tela cheia
      expect(tunaChallengeWindowSize(null), isNull);
      expect(tunaChallengeWindowSize('%%%nao-base64'), isNull);
      // base64 sem padding / url-safe também serve
      expect(tunaChallengeWindowSize(_paRequest('01').replaceAll('=', '')), (width: 250.0, height: 400.0));
    });
  });

  group('HTML', () {
    test('escape', () {
      expect(htmlEscape('a"b<c>&\'d'), 'a&quot;b&lt;c&gt;&amp;&#39;d');
    });

    test('DDC: form POST escondido com JWT, escuta profile.completed do Cardinal', () {
      final h = tunaDdcHtml(url: 'https://centinelapi.cardinalcommerce.com/V1/Cruise/Collect?a=1&b=2', jwt: 'a"><script>x');
      expect(h, contains('action="https://centinelapi.cardinalcommerce.com/V1/Cruise/Collect?a=1&amp;b=2"'));
      expect(h, contains('method="POST"'));
      expect(h, contains('target="ddc"'));
      expect(h, contains('name="JWT" value="a&quot;&gt;&lt;script&gt;x"'));
      expect(h, isNot(contains('a"><script>x')));
      expect(h, contains('display:none'));
      expect(h, contains("MessageType!=='profile.completed'"));
      expect(h, contains(r'cardinalcommerce\.com$'));
      expect(h, contains('window.$tunaDdcChannel.postMessage'));
      expect(h, contains("getElementById('ddcForm').submit()"));
    });

    test('desafio: form POST pro step-up com JWT, auto-submit', () {
      final h = tunaChallengeHtml(const TunaChallenge(
          url: 'https://client.cardinaltrusted.com/centinelapi/V2/Cruise/StepUp', token: 'jwt<&>"'));
      expect(h, contains('action="https://client.cardinaltrusted.com/centinelapi/V2/Cruise/StepUp"'));
      expect(h, contains('method="POST"'));
      expect(h, contains('name="JWT" value="jwt&lt;&amp;&gt;&quot;"'));
      expect(h, contains("getElementById('stepUp').submit()"));
    });
  });

  group('createCardOrder', () {
    test('manda threeDs + browser no bloco tuna e lê o challenge', () async {
      final fake = _FakeAdapter(200, {
        'ok': true,
        'status': 'pending',
        'challenge': {'url': 'https://client.cardinaltrusted.com/StepUp', 'token': 'jwt.step'},
      });
      final api = PublicApi(Dio(BaseOptions(baseUrl: 'https://api.example/api/public'))..httpClientAdapter = fake);
      final tuna = {
        'sessionId': 'sess',
        'brand': 'Master',
        'deviceSessionId': 'dfp',
        'threeDs': {'code': 'j3ds_abc12345', 'referenceId': 'r', 'transactionId': 't'},
        'browser': {'colorDepth': 24, 'screenWidth': 393, 'screenHeight': 850, 'timeDifference': 180},
      };
      final r = await api.createCardOrder('ord_1', 'ct', method: 'debit', tuna: tuna);
      final body = fake.last?.data as Map;
      expect(body['tuna'], tuna);
      expect(body['method'], 'debit');
      expect(r.ok, isTrue);
      expect(r.status, 'pending');
      expect(r.challenge?.url, 'https://client.cardinaltrusted.com/StepUp');
      expect(r.challenge?.token, 'jwt.step');
    });

    test('sem challenge → null', () async {
      final fake = _FakeAdapter(200, {'ok': true, 'status': 'paid'});
      final api = PublicApi(Dio(BaseOptions(baseUrl: 'https://api.example/api/public'))..httpClientAdapter = fake);
      expect((await api.createCardOrder('ord_1', 'ct', method: 'credit')).challenge, isNull);
    });
  });
}
