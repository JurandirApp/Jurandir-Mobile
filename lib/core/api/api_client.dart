import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/i18n.dart';
import 'api_config.dart';

/// Cliente HTTP compartilhado (Dio) para falar com a API pública do backend.
///
/// Os repositórios das features leem este provider para fazer as chamadas.
final apiClientProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json'},
    ),
  );
  // Idioma do app → o servidor devolve os rótulos prontos ("Abre hoje às
  // 18:00") traduzidos. Só em GET (é onde vêm os rótulos) e fora do pt.
  dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
    final code = I18n.code;
    if (o.method == 'GET' && code != I18n.fallbackCode && !o.queryParameters.containsKey('lang')) {
      o.queryParameters = {...o.queryParameters, 'lang': code};
    }
    h.next(o);
  }));
  return dio;
});
