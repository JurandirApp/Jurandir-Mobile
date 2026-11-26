import 'package:flutter_test/flutter_test.dart';
import 'package:jurandir/core/data/models.dart';
import 'package:jurandir/features/pedidos/resume_order.dart';

const _menu = [
  MenuItem(id: 1, name: 'Cerveja', desc: '', price: 12, category: 'Bebidas'),
  MenuItem(
    id: 2,
    name: 'Hambúrguer',
    desc: '',
    price: 30,
    category: 'Lanches',
    groups: [
      MenuOptionGroup(
        id: 'g1',
        name: 'Adicionais',
        required: false,
        minSelect: 0,
        maxSelect: 3,
        options: [
          MenuOption(id: 'o1', name: 'Bacon', priceDelta: 5),
          MenuOption(id: 'o2', name: 'Queijo', priceDelta: 3),
        ],
      ),
    ],
  ),
];

ClientOrder _order({
  List<ClientOrderItem> items = const [ClientOrderItem(name: 'Cerveja', qty: 2, price: 12)],
  String status = 'aguardando',
  String? estSlug = 'bar-x',
  String? payMethod = 'credito',
  String? pixPayload,
  bool expired = false,
  List<ClientShare>? splits,
}) =>
    ClientOrder(
      dbId: 'o1',
      code: 'PED-1',
      ts: 0,
      items: items,
      total: 24,
      grand: 24.48,
      status: status,
      name: '',
      note: '',
      estSlug: estSlug,
      payMethod: payMethod,
      pixPayload: pixPayload,
      expired: expired,
      splits: splits,
    );

void main() {
  group('rebuildCartLines', () {
    test('casa itens e adicionais pelo nome (ignora maiúsculas/espaços)', () {
      final lines = rebuildCartLines(
        _order(items: const [
          ClientOrderItem(name: 'cerveja ', qty: 2, price: 12),
          ClientOrderItem(name: 'Hambúrguer', qty: 1, price: 38, options: ['bacon', 'Queijo']),
        ]),
        _menu,
      )!;
      expect(lines, hasLength(2));
      expect(lines[0].item.id, 1);
      expect(lines[0].qty, 2);
      expect(lines[1].options.map((o) => o.optionId), ['o1', 'o2']);
      expect(lines[1].options.first.groupId, 'g1');
    });

    test('item ou adicional que não existe mais → null (não retoma)', () {
      expect(rebuildCartLines(_order(items: const [ClientOrderItem(name: 'Vinho', qty: 1, price: 50)]), _menu), isNull);
      expect(
        rebuildCartLines(
            _order(items: const [ClientOrderItem(name: 'Hambúrguer', qty: 1, price: 35, options: ['Ovo'])]), _menu),
        isNull,
      );
    });
  });

  group('canResumePayment', () {
    test('aguardando com bar conhecido / Pix válido / divisão → sim', () {
      expect(canResumePayment(_order()), isTrue);
      expect(canResumePayment(_order(estSlug: null, payMethod: 'pix', pixPayload: 'qr')), isTrue);
      expect(
        canResumePayment(_order(estSlug: null, splits: const [ClientShare(amount: 10, paid: false)])),
        isTrue,
      );
    });

    test('pago/entregue, ou sem como retomar → não', () {
      expect(canResumePayment(_order(status: 'producao')), isFalse);
      expect(canResumePayment(_order(status: 'entregue')), isFalse);
      expect(canResumePayment(_order(estSlug: null)), isFalse);
      expect(canResumePayment(_order(estSlug: null, payMethod: 'pix', pixPayload: 'qr', expired: true)), isFalse);
    });
  });
}
