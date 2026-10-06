import 'package:firebase_messaging/firebase_messaging.dart';
import '../alert/alert_service.dart';

/// Push FCM: só o garçom chama. Listeners são configurados UMA vez (sem vazar);
/// o callback de registro é sempre o mais recente (bearer atual). Best-effort.
class PushService {
  static Future<void> Function(String fcmToken)? _register;
  static bool _wired = false;

  static Future<void> registerWaiter(Future<void> Function(String fcmToken) register) async {
    _register = register; // sempre o mais recente (bearer do garçom logado agora)
    try {
      await FirebaseMessaging.instance.requestPermission();
      if (!_wired) {
        _wired = true;
        FirebaseMessaging.instance.onTokenRefresh.listen((t) { _register?.call(t).catchError((_) {}); });
        FirebaseMessaging.onMessage.listen((m) {
          final n = m.notification;
          AlertService.ring(title: n?.title ?? '🔔 Chamado', body: n?.body ?? 'Cliente precisa de ajuda');
        });
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) { try { await _register?.call(token); } catch (_) {} }
    } catch (_) {}
  }
}
