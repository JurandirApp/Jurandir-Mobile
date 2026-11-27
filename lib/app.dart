import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/data/app_language.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'l10n/i18n.dart';

/// Raiz do app: liga o tema, o roteador (go_router) e o idioma.
class JurandirApp extends ConsumerStatefulWidget {
  const JurandirApp({super.key});

  @override
  ConsumerState<JurandirApp> createState() => _JurandirAppState();
}

class _JurandirAppState extends ConsumerState<JurandirApp> {
  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    // Idioma escolhido no perfil: alimenta o `tr()` global, o `I18nScope`
    // (context.tr) e os widgets Material (flutter_localizations).
    final lang = ref.watch(appLanguageProvider);
    I18n.setLanguage(lang.code);
    ref.listen(appLanguageProvider, (prev, next) {
      I18n.setLanguage(next.code);
      // Textos resolvidos com `tr()` global (sem dependência no contexto)
      // também precisam refazer: reconstrói a árvore toda (troca é rara).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) rebuildAllWidgets(context as Element);
      });
    });
    return MaterialApp.router(
      title: 'Jurandir',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: lang.locale,
      supportedLocales: [for (final l in AppLanguage.values) l.locale],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => I18nScope(code: lang.code, child: child ?? const SizedBox.shrink()),
      routerConfig: router,
    );
  }
}
