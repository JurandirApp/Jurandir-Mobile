import 'package:flutter_test/flutter_test.dart';
import 'package:jurandir/core/data/models.dart';

void main() {
  group('DebitPayoutRow.fromJson', () {
    test('le o gateway quando presente', () {
      final r = DebitPayoutRow.fromJson({
        'establishmentId': 'e1',
        'nome': 'Bar do Ze',
        'qtd': 3,
        'bruto': 100,
        'taxa': 5,
        'aRepassar': 95,
        'gateway': 'PAGBANK',
      });
      expect(r.gateway, 'PAGBANK');
      expect(r.aRepassar, 95);
    });

    test('gateway vazio quando ausente (backend antigo)', () {
      final r = DebitPayoutRow.fromJson({'establishmentId': 'e1', 'nome': 'Bar'});
      expect(r.gateway, '');
    });
  });
}
