import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Instância de SharedPreferences — sobrescrita no `main()` após carregar.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPrefsProvider deve ser sobrescrito no main()'),
);

/// Persiste se o cliente já viu a apresentação (onboarding). Sobrevive a
/// fechar o app e independe de login/logout — mostra só uma vez.
class OnboardingController {
  final SharedPreferences _prefs;
  const OnboardingController(this._prefs);

  static const _key = 'onboarding_seen';

  bool get seen => _prefs.getBool(_key) ?? false;

  Future<void> markSeen() => _prefs.setBool(_key, true);
}

final onboardingProvider = Provider(
  (ref) => OnboardingController(ref.watch(sharedPrefsProvider)),
);
