import 'package:dio/dio.dart';

/// Chave PÚBLICA do Pagar.me (`pk_...`) — segura de embutir no app. Vem por
/// `--dart-define=PAGARME_PUBLIC_KEY=pk_...`.
const _publicKey = String.fromEnvironment('PAGARME_PUBLIC_KEY', defaultValue: '');

/// O cartão está pronto pra tokenizar? (a chave pública foi configurada).
bool get pagarmeCardConfigured => _publicKey.isNotEmpty;

/// Tokeniza o cartão DIRETO no Pagar.me usando a chave pública — o cartão cru
/// (número/CVV/validade) **nunca** passa pelo nosso backend (exigência de PCI da
/// própria Pagar.me). Retorna o `token_...` (vale ~60s, uso único) ou `null` em
/// falha (chave ausente, cartão recusado na tokenização, sem rede).
Future<String?> tokenizeCard({
  required String number,
  required String holderName,
  required int expMonth,
  required int expYear,
  required String cvv,
}) async {
  if (_publicKey.isEmpty) return null;
  final dio = Dio(BaseOptions(
    baseUrl: 'https://api.pagar.me/core/v5',
    headers: {'Content-Type': 'application/json'},
  ));
  try {
    final res = await dio.post<Map<String, dynamic>>(
      '/tokens',
      queryParameters: {'appId': _publicKey},
      data: {
        'type': 'card',
        'card': {
          'number': number.replaceAll(RegExp(r'\D'), ''),
          'holder_name': holderName.trim(),
          'exp_month': expMonth,
          'exp_year': expYear,
          'cvv': cvv.trim(),
        },
      },
    );
    return res.data?['id'] as String?;
  } on DioException {
    return null;
  }
}
