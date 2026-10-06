import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Alerta local (sem FCM): vibração + som de notificação, pra chamar a atenção
/// do garçom com o app ABERTO. Best-effort — nunca lança.
class AlertService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _channelId = 'jurandir_chamados';

  static Future<void> init() async {
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: true, requestSoundPermission: true, requestBadgePermission: false,
      );
      await _plugin.initialize(settings: const InitializationSettings(android: android, iOS: ios));
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.createNotificationChannel(const AndroidNotificationChannel(
        _channelId, 'Chamados',
        description: 'Chamados de clientes na mesa',
        importance: Importance.max, playSound: true, enableVibration: true,
      ));
    } catch (_) {}
  }

  /// Pede a permissão de notificação (Android 13+). Só o garçom precisa.
  static Future<void> ensurePermission() async {
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {}
  }

  static Future<void> ring({required String title, required String body}) async {
    try { HapticFeedback.heavyImpact(); } catch (_) {}
    try {
      await _plugin.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title, body: body, notificationDetails:
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId, 'Chamados',
            importance: Importance.max, priority: Priority.high,
            playSound: true, enableVibration: true, category: AndroidNotificationCategory.call,
          ),
          iOS: DarwinNotificationDetails(presentSound: true, presentAlert: true),
        ),
      );
    } catch (_) {}
  }
}
