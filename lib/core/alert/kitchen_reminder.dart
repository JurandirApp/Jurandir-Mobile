import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Minutos antes do fim da cozinha em que o cliente é avisado.
const kKitchenReminderMinutes = [30, 10];

/// Texto do aviso: "Horário da cozinha está finalizando em 30 minutos".
String kitchenClosingMsg(int minutes) => 'Horário da cozinha está finalizando em $minutes minutos';

/// Plano puro (testável): quais avisos agendar dado o fim da cozinha. Só os que
/// ainda estão no futuro — pediu faltando 20 min → só o de 10.
List<({int minutes, DateTime at})> kitchenReminderPlan(DateTime closesAt, DateTime now) => [
      for (final m in kKitchenReminderMinutes)
        if (closesAt.subtract(Duration(minutes: m)).isAfter(now))
          (minutes: m, at: closesAt.subtract(Duration(minutes: m))),
    ];

/// IDs estáveis por bar (reagendar substitui; nunca duplica).
int kitchenReminderId(String slug, int minutes) =>
    700000 + (slug.hashCode & 0x7FFF) * 4 + kKitchenReminderMinutes.indexOf(minutes);

/// Aviso LOCAL (sem servidor/cron) pro cliente que já pediu num bar: "Horário
/// da cozinha está finalizando em X minutos", 30 e 10 min antes do fim da
/// cozinha. Agendado depois do pedido; funciona com o app fechado.
/// Best-effort — nunca lança.
class KitchenReminder {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static const _channelId = 'jurandir_cozinha';

  static Future<void> _init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@drawable/ic_notification');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true, requestSoundPermission: true, requestBadgePermission: false,
    );
    await _plugin.initialize(settings: const InitializationSettings(android: android, iOS: ios));
    final androidImpl =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId, 'Cozinha',
      description: 'Aviso de que o horário da cozinha está acabando',
      importance: Importance.high,
    ));
    await androidImpl?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, sound: true);
    _ready = true;
  }

  /// Agenda (ou reagenda) os avisos do bar `slug`. `closesAt` null = cozinha
  /// sem horário/24h → cancela os avisos antigos desse bar.
  static Future<void> scheduleFor({
    required String slug,
    required DateTime? closesAt,
    String? barName,
  }) async {
    try {
      await _init();
      for (final m in kKitchenReminderMinutes) {
        await _plugin.cancel(id: kitchenReminderId(slug, m));
      }
      if (closesAt == null) return;
      final title = (barName == null || barName.trim().isEmpty) ? 'Cozinha' : barName.trim();
      for (final r in kitchenReminderPlan(closesAt, DateTime.now())) {
        await _plugin.zonedSchedule(
          id: kitchenReminderId(slug, r.minutes),
          title: title,
          body: '${kitchenClosingMsg(r.minutes)}. Quer pedir mais alguma coisa?',
          scheduledDate: tz.TZDateTime.from(r.at.toUtc(), tz.UTC),
          // Inexato de propósito: não exige a permissão de alarme exato (Play
          // restringe). Pode atrasar uns minutos com o aparelho em repouso.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId, 'Cozinha',
              importance: Importance.high, priority: Priority.high,
              icon: 'ic_notification', color: Color(0xFFFFC24B),
            ),
            iOS: DarwinNotificationDetails(presentSound: true, presentAlert: true),
          ),
        );
      }
    } catch (_) {}
  }
}
