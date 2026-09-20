import 'package:flutter_test/flutter_test.dart';
import 'package:jurandir/core/data/models.dart';
import 'package:jurandir/features/estab/presentation/estab_kpis_logic.dart';

PanelOrderLine _line(String name, int qty, double price) =>
    PanelOrderLine(qty: qty, name: name, price: price);

PanelOrder _ord({
  required String status,
  required int ts,
  String pay = 'pix',
  List<PanelOrderLine> items = const [],
}) =>
    PanelOrder(
      id: 0,
      dbId: 'x',
      code: 'c',
      status: status,
      loc: 'Mesa 1',
      ts: ts,
      pay: pay,
      items: items,
    );

void main() {
  test('pedido "aguardando" (não pago) não entra no faturamento nem na contagem', () {
    final kpis = computeEstabKpis(
      all: [
        _ord(status: 'aguardando', ts: 1000, items: [_line('Cerveja', 1, 99)]),
        _ord(status: 'producao', ts: 1000, items: [_line('Cerveja', 1, 10)]),
      ],
      menu: const [],
      cutoffMs: 0,
    );
    expect(kpis.faturamento, 10); // só o de produção
    expect(kpis.pedidos, 1);
  });

  test('"producao" e "entregue" contam como venda', () {
    final kpis = computeEstabKpis(
      all: [
        _ord(status: 'producao', ts: 1000, items: [_line('X', 1, 10)]),
        _ord(status: 'entregue', ts: 1000, items: [_line('Y', 1, 20)]),
      ],
      menu: const [],
      cutoffMs: 0,
    );
    expect(kpis.faturamento, 30);
    expect(kpis.pedidos, 2);
  });

  test('respeita o corte de período (ts abaixo do cutoff fica de fora)', () {
    final kpis = computeEstabKpis(
      all: [
        _ord(status: 'producao', ts: 500, items: [_line('X', 1, 10)]),
        _ord(status: 'producao', ts: 2000, items: [_line('X', 1, 5)]),
      ],
      menu: const [],
      cutoffMs: 1000,
    );
    expect(kpis.faturamento, 5);
    expect(kpis.pedidos, 1);
  });

  test('vendas por método ignoram os não pagos', () {
    final kpis = computeEstabKpis(
      all: [
        _ord(status: 'aguardando', ts: 1000, pay: 'pix', items: [_line('X', 1, 99)]),
        _ord(status: 'producao', ts: 1000, pay: 'credito', items: [_line('X', 1, 10)]),
      ],
      menu: const [],
      cutoffMs: 0,
    );
    expect(kpis.byPay['pix'], isNull);
    expect(kpis.byPay['credito'], 10);
  });
}
