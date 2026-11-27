import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/data/app_language.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// Raiz do app: liga o tema e o roteador (go_router).
class JurandirApp extends ConsumerWidget {
  const JurandirApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    // Idioma escolhido no perfil (sem flutter_localizations ainda: os widgets
    // Material seguem no padrão do Flutter; as telas do app são em português).
    final lang = ref.watch(appLanguageProvider);
    return MaterialApp.router(
      title: 'Jurandir',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: lang.locale,
      routerConfig: router,
    );
  }
}
