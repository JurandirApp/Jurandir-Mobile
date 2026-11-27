import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jurandir/core/data/app_language.dart';
import 'package:jurandir/core/data/onboarding_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('parseAppLanguage: códigos conhecidos e padrão português', () {
    expect(parseAppLanguage('en'), AppLanguage.en);
    expect(parseAppLanguage('pt'), AppLanguage.pt);
    expect(parseAppLanguage(null), AppLanguage.pt);
    expect(parseAppLanguage('es'), AppLanguage.es);
    expect(parseAppLanguage('fr'), AppLanguage.pt);
  });

  test('locale de cada idioma', () {
    expect(AppLanguage.pt.locale.toLanguageTag(), 'pt-BR');
    expect(AppLanguage.en.locale.languageCode, 'en');
    expect(AppLanguage.es.locale.languageCode, 'es');
  });

  test('carrega do SharedPreferences e persiste a troca', () async {
    SharedPreferences.setMockInitialValues({kAppLanguagePrefKey: 'en'});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);

    expect(c.read(appLanguageProvider), AppLanguage.en);
    await c.read(appLanguageProvider.notifier).set(AppLanguage.pt);
    expect(c.read(appLanguageProvider), AppLanguage.pt);
    expect(prefs.getString(kAppLanguagePrefKey), 'pt');
  });

  test('sem SharedPreferences (sem override) cai no português sem quebrar', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(appLanguageProvider), AppLanguage.pt);
    await c.read(appLanguageProvider.notifier).set(AppLanguage.en); // não lança
    expect(c.read(appLanguageProvider), AppLanguage.en);
  });
}
