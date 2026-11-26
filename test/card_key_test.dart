import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:jurandir/core/data/client_profile.dart';

void main() {
  group('generateCardKey (chave dos cartões salvos)', () {
    test('32 bytes em base64url sem padding → 43 chars no formato do servidor', () {
      final k = generateCardKey();
      expect(k.length, 43);
      expect(k, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
      expect(k.contains('='), isFalse);
      expect(isValidCardKey(k), isTrue);
    });

    test('aleatória (duas chaves diferem)', () {
      expect(generateCardKey(), isNot(generateCardKey()));
    });

    test('mesma semente → mesma chave (usa o Random informado)', () {
      expect(generateCardKey(Random(7)), generateCardKey(Random(7)));
    });
  });

  test('isValidCardKey rejeita curta, longa e caracteres fora do base64url', () {
    expect(isValidCardKey('a' * 31), isFalse);
    expect(isValidCardKey('a' * 129), isFalse);
    expect(isValidCardKey('${'a' * 40}='), isFalse);
    expect(isValidCardKey('${'a' * 40}+/'), isFalse);
    expect(isValidCardKey('a' * 32), isTrue);
  });
}
