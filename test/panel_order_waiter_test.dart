import 'package:flutter_test/flutter_test.dart';
import 'package:jurandir/core/data/models.dart';

void main() {
  Map<String, dynamic> order([Map<String, dynamic> extra = const {}]) => {
        'id': 1,
        'dbId': 'o1',
        'code': 'ABC',
        'st': 'producao',
        'loc': 'Mesa 2',
        'ts': 0,
        'items': [
          [1, 'Chopp', 10],
        ],
        ...extra,
      };

  test('waiterName presente', () {
    expect(PanelOrder.fromJson(order({'waiterName': ' João '})).waiterName, 'João');
  });

  test('sem waiterName (servidor antigo) / vazio / null → null', () {
    expect(PanelOrder.fromJson(order()).waiterName, isNull);
    expect(PanelOrder.fromJson(order({'waiterName': ''})).waiterName, isNull);
    expect(PanelOrder.fromJson(order({'waiterName': null})).waiterName, isNull);
  });
}
