// Idioma do app (preferência do aparelho, não da conta).
//
// Hoje o app é só em português (sem infraestrutura de i18n — ver
// docs/app-i18n-plano.md). Esta preferência já fica guardada e chega no
// `MaterialApp.locale`, pra quando as telas forem traduzidas bastar ler o
// [appLanguageProvider]. Sem `flutter_localizations` no projeto, o Flutter
// resolve qualquer locale pro padrão dele (en_US) nos widgets Material — o que
// já era o comportamento antes.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'onboarding_controller.dart';

enum AppLanguage {
  pt('pt', 'Português', Locale('pt', 'BR')),
  en('en', 'English', Locale('en'));

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
