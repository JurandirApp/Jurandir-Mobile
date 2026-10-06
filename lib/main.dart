import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/alert/alert_service.dart';
import 'core/data/onboarding_controller.dart';

@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage message) async {
  // Notification messages já são exibidas pelo SO em background; nada a fazer.
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);
  } catch (_) {
    // Firebase não configurado/falhou → segue sem push (não brica o app).
  }
  final prefs = await SharedPreferences.getInstance();
  await AlertService.init();
  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const JurandirApp(),
    ),
  );
}
