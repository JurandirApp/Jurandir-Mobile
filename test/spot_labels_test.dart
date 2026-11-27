import 'package:flutter_test/flutter_test.dart';
import 'package:jurandir/features/estab/spot_labels.dart';

void main() {
  group('rangeSpotLabels', () {
    test('Mesa 1→30 sem zero', () {
      final l = rangeSpotLabels(prefix: 'Mesa', from: 1, to: 30);
      expect(l.length, 30);
      expect(l.first, 'Mesa 1');
      expect(l.last, 'Mesa 30');
    });

    test('zero à esquerda: mínimo 2 dígitos, ou a largura do maior', () {
      expect(rangeSpotLabels(prefix: 'Mesa', from: 1, to: 3, zeroPad: true), ['Mesa 01', 'Mesa 02', 'Mesa 03']);
      final big = rangeSpotLabels(prefix: 'Mesa', from: 1, to: 120, zeroPad: true);
      expect(big.first, 'Mesa 001');
      expect(big.last, 'Mesa 120');
    });

    test('faixa invertida, prefixo com espaços e prefixo vazio', () {
      expect(rangeSpotLabels(prefix: '  Guarda-sol  ', from: 3, to: 1), ['Guarda-sol 1', 'Guarda-sol 2', 'Guarda-sol 3']);
      expect(rangeSpotLabels(prefix: '', from: 9, to: 10, zeroPad: true), ['09', '10']);
    });

    test('números negativos → vazio', () {
      expect(rangeSpotLabels(prefix: 'Mesa', from: -1, to: 2), isEmpty);
      expect(rangeCount(-1, 2), 0);
    });

    test('rangeCount', () {
      expect(rangeCount(1, 30), 30);
      expect(rangeCount(30, 1), 30);
      expect(rangeCount(5, 5), 1);
      expect(rangeCount(1, 5000) > maxSpotBatch, isTrue);
    });
  });

  group('parseSpotList', () {
    test('uma por linha, trim, sem vazias, sem duplicadas (ignora caixa)', () {
      const text = '  Mesa VIP \r\n\nGuarda-sol 1\nguarda-sol   1\n  \nBalcão\nMesa VIP';
      expect(parseSpotList(text), ['Mesa VIP', 'Guarda-sol 1', 'Balcão']);
    });

    test('texto vazio → lista vazia', () {
      expect(parseSpotList(''), isEmpty);
      expect(parseSpotList('\n \n'), isEmpty);
    });
  });

  test('spotsBatchSummary', () {
    expect(spotsBatchSummary(30, 0), '30 mesas criadas');
    expect(spotsBatchSummary(28, 2), '28 mesas criadas, 2 já existiam');
    expect(spotsBatchSummary(1, 1), '1 mesa criada, 1 já existia');
    expect(spotsBatchSummary(0, 5), '0 mesas criadas, 5 já existiam');
  });
}
