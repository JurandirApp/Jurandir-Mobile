import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jurandir/core/utils/backoff_poller.dart';

void main() {
  test('paymentPollSchedule: 4 s no 1º minuto, 8 s até 3 min, depois 15 s', () {
    expect(paymentPollSchedule(Duration.zero), const Duration(seconds: 4));
    expect(paymentPollSchedule(const Duration(seconds: 59)), const Duration(seconds: 4));
    expect(paymentPollSchedule(const Duration(minutes: 1)), const Duration(seconds: 8));
    expect(paymentPollSchedule(const Duration(minutes: 3)), const Duration(seconds: 15));
  });

  test('cardWaitPollSchedule: 3 s, 6 s, 12 s', () {
    expect(cardWaitPollSchedule(Duration.zero), const Duration(seconds: 3));
    expect(cardWaitPollSchedule(const Duration(seconds: 30)), const Duration(seconds: 6));
    expect(cardWaitPollSchedule(const Duration(minutes: 2)), const Duration(seconds: 12));
  });

  test('BackoffPoller espaça as chamadas e para no cancel', () {
    fakeAsync((fa) {
      var ticks = 0;
      final p = BackoffPoller(() => ticks++)..start();
      fa.elapse(const Duration(seconds: 60)); // 4 s → ~15 chamadas
      final firstMinute = ticks;
      expect(firstMinute, inInclusiveRange(14, 15));
      fa.elapse(const Duration(seconds: 120)); // 8 s → +15
      expect(ticks - firstMinute, inInclusiveRange(14, 16));
      p.cancel();
      final stopped = ticks;
      fa.elapse(const Duration(minutes: 5));
      expect(ticks, stopped);
      expect(p.isActive, isFalse);
    });
  });
}
