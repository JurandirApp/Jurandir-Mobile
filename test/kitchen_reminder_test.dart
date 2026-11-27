import 'package:flutter_test/flutter_test.dart';
import 'package:jurandir/core/alert/kitchen_reminder.dart';
import 'package:jurandir/core/data/kitchen.dart';

void main() {
  final closes = DateTime.utc(2026, 11, 28, 1); // 22:00 em Brasília

  test('pediu com folga → avisos de 30 e 10 min', () {
    final plan = kitchenReminderPlan(closes, DateTime.utc(2026, 11, 28, 0));
    expect(plan.map((p) => p.minutes), [30, 10]);
    expect(plan.first.at, DateTime.utc(2026, 11, 28, 0, 30));
  });

  test('pediu faltando 20 min → só o de 10', () {
    final plan = kitchenReminderPlan(closes, DateTime.utc(2026, 11, 28, 0, 40));
    expect(plan.map((p) => p.minutes), [10]);
  });

  test('pediu faltando 5 min → nenhum', () {
    expect(kitchenReminderPlan(closes, DateTime.utc(2026, 11, 28, 0, 55)), isEmpty);
  });

  test('texto do aviso', () {
    expect(kitchenClosingMsg(30), 'Horário da cozinha está finalizando em 30 minutos');
  });

  test('ids estáveis e distintos por aviso', () {
    expect(kitchenReminderId('leo', 30), kitchenReminderId('leo', 30));
    expect(kitchenReminderId('leo', 30), isNot(kitchenReminderId('leo', 10)));
  });

  test('kitchenClosesAt do servidor vira closesAt', () {
    final k = KitchenStatus.fromEst({'kitchenOpenNow': true, 'kitchenClosesAt': '2026-11-28T01:00:00.000Z'});
    expect(k.closesAt, closes);
    expect(KitchenStatus.fromEst({'kitchenOpenNow': true}).closesAt, isNull);
  });
}
