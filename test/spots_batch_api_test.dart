import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jurandir/core/data/public_api.dart';

/// Adapter falso: guarda a última requisição e responde status/corpo fixos.
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
  test('addSpotsBatch: POST com Bearer e {labels}; lê created/skipped/spots', () async {
    final t = _api(200, {
      'ok': true,
      'created': 2,
      'skipped': 1,
      'spots': ['Mesa 1', 'Mesa 2', 'Mesa 3'],
    });
    final r = await t.api.addSpotsBatch('tok', ['Mesa 1', 'Mesa 2', 'Mesa 3']);
    expect(t.fake.last?.method, 'POST');
    expect(t.fake.last?.path, '/establishment/spots/batch');
    expect(t.fake.last?.headers['Authorization'], 'Bearer tok');
    expect((t.fake.last?.data as Map)['labels'], ['Mesa 1', 'Mesa 2', 'Mesa 3']);
    expect(r.created, 2);
    expect(r.skipped, 1);
    expect(r.spots, ['Mesa 1', 'Mesa 2', 'Mesa 3']);
  });

  test('addSpotsBatch lança em erro HTTP ou ok != true', () async {
    expect(_api(400, {'error': 'x'}).api.addSpotsBatch('tok', ['A']), throwsA(anything));
    expect(_api(200, {'ok': false}).api.addSpotsBatch('tok', ['A']), throwsA(anything));
  });
}
