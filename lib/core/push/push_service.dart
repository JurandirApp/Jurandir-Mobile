import 'package:firebase_messaging/firebase_messaging.dart';
import '../alert/alert_service.dart';

/// Push FCM: pede permissão (só o garçom chama isto), pega o token, registra no
/// backend, e mostra o alerta em foreground. Best-effort — nunca lança.
class PushService {
  /// Chamar quando o GARÇOM abre a fila. Pede permissão + registra o token + handlers.
  static Future<void> registerWaiter(Future<void> Function(String fcmToken) register) async {
    try {
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) { try { await register(token); } catch (_) {} }
      FirebaseMessaging.instance.onTokenRefresh.listen((t) { register(t).catchError((_) {}); });
      FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        AlertService.ring(title: n?.title ?? '🔔 Chamado', body: n?.body ?? 'Cliente precisa de ajuda');
      });
    } catch (_) {}
  }
}
