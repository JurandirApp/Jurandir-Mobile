import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jurandir/core/data/kitchen.dart';
import 'package:jurandir/core/data/models.dart';
import 'package:jurandir/features/estab/presentation/estab_kitchen_card.dart';

MenuItem _item(int id, {bool kitchen = false}) =>
    MenuItem(id: id, name: 'Item $id', desc: '', price: 10, category: 'X', kitchen: kitchen);

PanelMenuItem _panel(String cat) => PanelMenuItem(
    dbId: cat, name: cat, desc: '', price: 1, photo: '', cat: cat, sub: '', active: true);

void main() {
  group('GET /api/public/{slug} → MenuData', () {
    test('servidor novo: cozinha fechada + rótulo + itens de cozinha', () {
      final d = MenuData.fromJson({
        'est': {'kitchenOpenNow': false, 'kitchenNextOpenLabel': 'abre às 18:00'},
        'menu': [
          {'id': 1, 'name': 'Picanha', 'price': 80, 'kitchen': true},
          {'id': 2, 'name': 'Chopp', 'price': 12},
        ],
      });
      expect(d.kitchen.openNow, isFalse);
      expect(d.kitchen.closedLabel, 'Cozinha fechada · abre às 18:00');
      expect(d.items.map((i) => i.kitchen), [true, false]);
    });

    test('servidor antigo (sem campos): cozinha aberta e nada é de cozinha', () {
      final d = MenuData.fromJson({
        'est': {'name': 'Bar'},
        'menu': [
          {'id': 1, 'name': 'Picanha', 'price': 80},
        ],
      });
      expect(d.kitchen.openNow, isTrue);
      expect(d.items.single.kitchen, isFalse);
    });

    test('sem est / menu ausente / tipos estranhos não quebram', () {
      final d = MenuData.fromJson({});
      expect(d.items, isEmpty);
      expect(d.kitchen.openNow, isTrue);
      expect(KitchenStatus.fromEst({'kitchenOpenNow': 'false'}).openNow, isTrue);
      expect(KitchenStatus.fromEst({'kitchenOpenNow': false, 'kitchenNextOpenLabel': '  '}).closedLabel,
          'Cozinha fechada');
    });

    test('mesma resposta traz bar aberto/fechado (openNow) e cozinha', () {
      final d = MenuData.fromJson({
        'est': {'openNow': false, 'nextOpenLabel': 'Abre hoje às 18:00', 'kitchenOpenNow': false},
        'menu': const [],
      });
      expect(d.open.openNow, isFalse);
      expect(d.open.closedLabel, 'Fechado agora · Abre hoje às 18:00');
      expect(d.kitchen.openNow, isFalse);
      expect(MenuData.fromJson({}).open.openNow, isTrue);
    });
  });

  group('regras de bloqueio', () {
    const closed = KitchenStatus(openNow: false);
    test('só item de cozinha com a cozinha fechada bloqueia', () {
      expect(itemBlockedByKitchen(_item(1, kitchen: true), closed), isTrue);
      expect(itemBlockedByKitchen(_item(2), closed), isFalse);
      expect(itemBlockedByKitchen(_item(1, kitchen: true), KitchenStatus.open), isFalse);
    });

    test('kitchenBlockedItems lista só a comida, e nada com a cozinha aberta', () {
      final cart = [_item(1, kitchen: true), _item(2), _item(3, kitchen: true)];
      expect(kitchenBlockedItems(cart, closed).map((i) => i.id), [1, 3]);
      expect(kitchenBlockedItems(cart, KitchenStatus.open), isEmpty);
    });
  });

  group('erro kitchenClosed do servidor', () {
    DioException err(Object? data) => DioException(
          requestOptions: RequestOptions(path: '/orders'),
          response: Response(requestOptions: RequestOptions(path: '/orders'), statusCode: 409, data: data),
        );

    test('reconhece no DioException e no corpo cru', () {
      expect(isKitchenClosedError(err({'error': 'kitchenClosed'})), isTrue);
      expect(isKitchenClosedError({'error': 'kitchenClosed'}), isTrue);
    });

    test('outros erros não', () {
      expect(isKitchenClosedError(err({'error': 'outro'})), isFalse);
      expect(isKitchenClosedError(err('html')), isFalse);
      expect(isKitchenClosedError(null), isFalse);
      expect(isKitchenClosedError(Exception('x')), isFalse);
    });
  });

  group('GET/POST /establishment/kitchen', () {
    test('formato do horário do bar (7 dias × {o,c}) é editável e volta igual', () {
      final raw = List.generate(7, (i) => i == 5 ? [{'o': '11:00', 'c': '15:00'}, {'o': '18:00', 'c': '23:00'}] : []);
      final cfg = KitchenConfig.fromJson({'kitchenHours': raw, 'kitchenCategories': ['Pratos', 'Porções']});
      expect(cfg.hoursEditable, isTrue);
      expect(cfg.hours![5].length, 2);
      expect(cfg.categories, ['Pratos', 'Porções']);
      expect(cfg.toJson()['kitchenHours'], raw);
    });

    test('ausente = não configurado → semana vazia editável', () {
      final cfg = KitchenConfig.fromJson({});
      expect(cfg.hoursEditable, isTrue);
      expect(cfg.hours!.length, 7);
      expect(cfg.hours!.every((d) => d.isEmpty), isTrue);
      expect(cfg.categories, isEmpty);
    });

    test('formato desconhecido: não editável e o POST devolve o cru intacto', () {
      final raw = {'mon': '11-15', 'tz': 'America/Sao_Paulo'};
      final cfg = KitchenConfig.fromJson({'kitchenHours': raw, 'kitchenCategories': ['Pratos', 3]});
      expect(cfg.hoursEditable, isFalse);
      expect(cfg.categories, ['Pratos']); // ignora não-string
      final body = cfg.copyWith(categories: ['Lanches']).toJson();
      expect(body['kitchenHours'], same(raw));
      expect(body['kitchenCategories'], ['Lanches']);
    });

    test('parseKitchenHours rejeita dias != 7, hora inválida e 3 turnos', () {
      expect(parseKitchenHours(List.generate(6, (_) => [])), isNull);
      expect(parseKitchenHours(List.generate(7, (i) => i == 0 ? [{'o': '9h', 'c': '15:00'}] : [])), isNull);
      expect(
          parseKitchenHours(List.generate(
              7, (i) => i == 0 ? List.generate(3, (_) => {'o': '10:00', 'c': '11:00'}) : [])),
          isNull);
    });

    test('copyWeek é cópia profunda (rollback não é afetado pela edição)', () {
      final orig = parseKitchenHours(List.generate(7, (i) => i == 1 ? [{'o': '11:00', 'c': '15:00'}] : []))!;
      final copy = copyWeek(orig);
      copy[1][0]['o'] = '12:00';
      copy[2].add({'o': '18:00', 'c': '22:00'});
      expect(orig[1][0]['o'], '11:00');
      expect(orig[2], isEmpty);
    });

    test('opções de categoria: ordem do cardápio, sem duplicar, mantém as salvas órfãs', () {
      final opts = kitchenCategoryOptions(
          [_panel('Pratos'), _panel('Bebidas'), _panel('Pratos'), _panel(' ')], ['Porções', 'Pratos']);
      expect(opts, ['Pratos', 'Bebidas', 'Porções']);
    });
  });
}
