import 'dart:async';

/// Intervalo da consulta de status conforme o tempo de espera: rápido no começo
/// (quando o pagamento costuma cair) e cada vez mais espaçado depois — num pico
/// com muitos clientes esperando, isso corta a maior parte das requisições sem
/// atrasar a confirmação de quem paga logo.
typedef PollSchedule = Duration Function(Duration elapsed);

/// Padrão das telas de pagamento (Pix, conta dividida): 4 s no 1º minuto,
/// 8 s até 3 min, depois 15 s.
Duration paymentPollSchedule(Duration elapsed) {
  if (elapsed < const Duration(minutes: 1)) return const Duration(seconds: 4);
  if (elapsed < const Duration(minutes: 3)) return const Duration(seconds: 8);
  return const Duration(seconds: 15);
}

/// Cartão sendo processado (costuma resolver em segundos): 3 s nos primeiros
/// 30 s, 6 s até 2 min, depois 12 s.
Duration cardWaitPollSchedule(Duration elapsed) {
  if (elapsed < const Duration(seconds: 30)) return const Duration(seconds: 3);
  if (elapsed < const Duration(minutes: 2)) return const Duration(seconds: 6);
  return const Duration(seconds: 12);
}

/// Chama [onTick] repetidamente com o intervalo dado por [schedule] (medido a
/// partir do [start]). Substitui o `Timer.periodic` de intervalo fixo.
class BackoffPoller {
  BackoffPoller(this.onTick, {this.schedule = paymentPollSchedule});

  final void Function() onTick;
  final PollSchedule schedule;

  Timer? _timer;
  // Soma dos intervalos já esperados (determinístico — não depende do relógio).
  Duration _elapsed = Duration.zero;

  bool get isActive => _timer != null;

  /// Tempo de espera acumulado desde o [start].
  Duration get elapsed => _elapsed;

  /// Começa a contar (idempotente: chamar de novo não reinicia).
  void start() {
    if (_timer != null) return;
    _schedule();
  }

  void _schedule() {
    final wait = schedule(_elapsed);
    _timer = Timer(wait, () {
      if (_timer == null) return; // cancelado
      _elapsed += wait;
      onTick();
      if (_timer != null) _schedule();
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
