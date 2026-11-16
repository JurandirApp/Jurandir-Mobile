import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:jurandir/core/payments/tuna_fingerprint.dart';

void main() {
  group('generateDeviceSessionId', () {
    test('32 hex minúsculos', () {
      for (var i = 0; i < 50; i++) {
        expect(generateDeviceSessionId(), matches(RegExp(r'^[0-9a-f]{32}$')));
      }
    });

    test('um novo a cada chamada', () {
      final ids = {for (var i = 0; i < 100; i++) generateDeviceSessionId()};
      expect(ids.length, 100);
    });

    test('determinístico com Random semeado (mantém zeros à esquerda)', () {
      final a = generateDeviceSessionId(Random(1));
      final b = generateDeviceSessionId(Random(1));
      expect(a, b);
      expect(a.length, 32);
    });
  });

  group('tunaFingerprintTagUrl', () {
    test('monta org_id e session_id = merchant + id', () {
      final url = tunaFingerprintTagUrl(
          orgId: 'k8vif92e', merchantId: 'tuna_merchant', deviceSessionId: 'abc123');
      expect(url,
          'https://h.online-metrix.net/fp/tags.js?org_id=k8vif92e&session_id=tuna_merchantabc123');
    });

    test('codifica caracteres especiais', () {
      final url = tunaFingerprintTagUrl(orgId: 'a&b', merchantId: 'm x', deviceSessionId: 'id');
      final q = Uri.parse(url).queryParameters;
      expect(q['org_id'], 'a&b');
      expect(q['session_id'], 'm xid');
    });
  });

  group('tunaFingerprintHtml', () {
    test('carrega o tags.js (com & escapado no atributo)', () {
      final html = tunaFingerprintHtml('https://h.online-metrix.net/fp/tags.js?org_id=o&session_id=s');
      expect(html,
          contains('<script type="text/javascript" src="https://h.online-metrix.net/fp/tags.js?org_id=o&amp;session_id=s"></script>'));
    });
  });

  group('TunaFingerprintConfig.fromJson', () {
    test('ligado e completo → usable', () {
      final c = TunaFingerprintConfig.fromJson({'enabled': true, 'orgId': 'org', 'merchantId': 'm'});
      expect(c.enabled, isTrue);
      expect(c.orgId, 'org');
      expect(c.merchantId, 'm');
      expect(c.usable, isTrue);
    });

    for (final j in <Object?>[
      null,
      'x',
      <String, dynamic>{},
      {'enabled': false, 'orgId': 'org', 'merchantId': 'm'},
      {'enabled': 'true', 'orgId': 'org', 'merchantId': 'm'},
      {'enabled': true, 'merchantId': 'm'},
      {'enabled': true, 'orgId': 'org'},
      {'enabled': true, 'orgId': '', 'merchantId': 'm'},
      {'enabled': true, 'orgId': 1, 'merchantId': 'm'},
    ]) {
      test('$j → não usável', () {
        expect(TunaFingerprintConfig.fromJson(j).usable, isFalse);
      });
    }
  });
}
