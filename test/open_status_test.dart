import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jurandir/core/data/models.dart';
import 'package:jurandir/core/data/open_status.dart';
import 'package:jurandir/core/data/public_api.dart';

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

Map<String, dynamic> _est([Map<String, dynamic> extra = const {}]) =>
    {'id': 'e1', 'slug': 'bar', 'name': 'Bar', 'open': true, ...extra};

void main() {
  group('Establishment.fromJson openNow', () {
    test('servidor antigo (sem campos) → aberto', () {
      final e = Establishment.fromJson(_est());
      expect(e.openNow, isTrue);
      expect(e.isOpenNow, isTrue);
      expect(e.closedLabel, isNull);
    });

    test('fechado com próximo horário', () {
      final e = Establishment.fromJson(_est({'openNow': false, 'nextOpenLabel': 'Abre hoje às 18:00'}));
      expect(e.isOpenNow, isFalse);
      expect(e.nextOpenLabel, 'Abre hoje às 18:00');
      expect(e.closedLabel, 'Fechado agora · Abre hoje às 18:00');
    });

    test('fechado sem previsão', () {
      final e = Establishment.fromJson(_est({'openNow': false}));
      expect(e.closedLabel, 'Fechado agora');
    });

    test('inativo (open=false) conta como fechado', () {
      final e = Establishment.fromJson(_est({'open': false, 'openNow': true}));
      expect(e.isOpenNow, isFalse);
      expect(e.openStatus.openNow, isFalse);
    });
  });

  group('BarOpenStatus', () {
    test('null/sem campos → aberto', () {
      expect(BarOpenStatus.fromJson(null).openNow, isTrue);
      expect(BarOpenStatus.fromJson(const {}).openNow, isTrue);
    });

    test('label vazio vira null', () {
      final s = BarOpenStatus.fromJson(const {'openNow': false, 'nextOpenLabel': '  '});
      expect(s.nextOpenLabel, isNull);
      expect(s.closedLabel, 'Fechado agora');
    });

    test('mensagem do checkout', () {
      expect(closedCheckoutMessage('Abre amanhã às 11:00'),
          'Este bar está fechado agora e não está aceitando pedidos. Abre amanhã às 11:00.');
      expect(closedCheckoutMessage(null), 'Este bar está fechado agora e não está aceitando pedidos.');
    });

    test('isClosedError', () {
      expect(isClosedError({'error': 'closed'}), isTrue);
      expect(isClosedError({'error': 'other'}), isFalse);
      expect(isClosedError('closed'), isTrue);
      expect(isClosedError(null), isFalse);
    });
  });

  group('PublicApi', () {
    test('barOpenStatus lê o `est` do GET /{slug}', () async {
      final t = _api(200, {
        'est': _est({'openNow': false, 'nextOpenLabel': 'Abre hoje às 18:00'}),
        'menu': [],
      });
      final s = await t.api.barOpenStatus('bar');
      expect(t.fake.last?.path, '/bar');
      expect(s?.openNow, isFalse);
      expect(s?.nextOpenLabel, 'Abre hoje às 18:00');
    });

    test('barOpenStatus: erro de rede → null', () async {
      expect(await _api(500, {'error': 'x'}).api.barOpenStatus('bar'), isNull);
    });

    test('createOrder: 4xx `closed` → BarClosedException', () async {
      final t = _api(409, {'error': 'closed', 'nextOpenLabel': 'Abre hoje às 18:00'});
      await expectLater(
        t.api.createOrder(const {}),
        throwsA(isA<BarClosedException>()
            .having((e) => e.message, 'message', contains('Abre hoje às 18:00'))),
      );
    });

    test('createOrder: outro erro propaga como DioException', () async {
      await expectLater(_api(500, {'error': 'boom'}).api.createOrder(const {}), throwsA(isA<DioException>()));
    });
  });
}
