// Idioma do app (preferência do aparelho, não da conta).
//
// Guardada no aparelho e ligada em `MaterialApp.locale` + no sistema de
// tradução do app (`lib/l10n/`, ver docs/app-i18n.md). Português é o padrão.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'onboarding_controller.dart';

enum AppLanguage {
  pt('pt', 'Português', Locale('pt', 'BR')),
  en('en', 'English', Locale('en')),
  es('es', 'Español', Locale('es'));

  final String code;
  final String label; // sempre no próprio idioma (padrão de seletor de idioma)
  final Locale locale;
  const AppLanguage(this.code, this.label, this.locale);
}

/// Código salvo → idioma. Desconhecido/ausente = português (padrão). Pura.
AppLanguage parseAppLanguage(String? code) {
  for (final l in AppLanguage.values) {
    if (l.code == code) return l;
  }
  return AppLanguage.pt;
}

const kAppLanguagePrefKey = 'app_language';

class AppLanguageController extends Notifier<AppLanguage> {
  @override
  AppLanguage build() {
    try {
      return parseAppLanguage(ref.read(sharedPrefsProvider).getString(kAppLanguagePrefKey));
    } catch (_) {
      // Sem SharedPreferences (ex.: teste de widget sem override): padrão.
      return AppLanguage.pt;
    }
  }

  Future<void> set(AppLanguage lang) async {
    if (lang == state) return;
    state = lang;
    try {
      await ref.read(sharedPrefsProvider).setString(kAppLanguagePrefKey, lang.code);
    } catch (_) {
      // Falha ao persistir não desfaz a escolha na sessão atual.
    }
  }
}

final appLanguageProvider =
    NotifierProvider<AppLanguageController, AppLanguage>(AppLanguageController.new);
