import 'package:dio/dio.dart';

/// Cartão cru pro Token/Generate da Tuna — SÓ em memória, nunca logar/persistir.
class TunaCard {
  final String number; // só dígitos
  final String holder;
  final int expMonth;
  final int expYear; // 4 dígitos
  final String cvv;
  const TunaCard({
    required this.number,
    required this.holder,
    required this.expMonth,
    required this.expYear,
    required this.cvv,
  });
}

/// Token de uso único da Tuna + a bandeira (vai no `tuna.brand` da cobrança).
typedef TunaToken = ({String token, String? brand});

/// Corpo do `POST <tokenUrl>/api/Token/Generate`.
Map<String, dynamic> tunaGenerateBody(String sessionId, TunaCard card) => {
      'sessionId': sessionId,
      'card': {
        'cardNumber': card.number.replaceAll(RegExp(r'\D'), ''),
        'cardHolderName': card.holder.trim(),
        'expirationMonth': card.expMonth,
        'expirationYear': card.expYear,
        'cvv': card.cvv.trim(),
        'singleUse': true,
      },
    };

/// URL do Generate a partir do `tokenUrl` da sessão. Só HTTPS — o cartão cru
/// nunca sai do celular em texto puro. Null se a URL não servir.
String? tunaGenerateUrl(String tokenUrl) {
  final uri = Uri.tryParse(tokenUrl.trim());
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
  return '${uri.toString().replaceFirst(RegExp(r'/+$'), '')}/api/Token/Generate';
}

/// Lê a resposta do Generate. A Tuna responde 200 até em erro de negócio:
/// `code < 0` (ex.: "Card number is invalid") ou sem token → null.
TunaToken? parseTunaGenerate(Object? data) {
  if (data is! Map) return null;
  final code = data['code'];
  if (code is! num || code < 0) return null;
  final token = data['token'];
  if (token is! String || token.isEmpty) return null;
  final brand = data['brand'];
  return (token: token, brand: brand is String && brand.isNotEmpty ? brand : null);
}

/// Tokeniza o cartão DIRETO na Tuna com a sessão do pedido (`/tuna/session`):
/// o cartão cru nunca passa pelo nosso backend e nenhuma chave vai no app (a
/// sessão é a "chave pública"). Dio separado — sem baseUrl nem headers do nosso
/// backend. Null em qualquer falha (cartão inválido, sessão expirada, sem rede).
Future<TunaToken?> tunaGenerateToken({
  required String tokenUrl,
  required String sessionId,
  required TunaCard card,
  Dio? dio,
}) async {
  final url = tunaGenerateUrl(tokenUrl);
  if (url == null || sessionId.isEmpty) return null;
  final client = dio ??
      Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Content-Type': 'application/json'},
      ));
  try {
    final res = await client.post<Object?>(url, data: tunaGenerateBody(sessionId, card));
    return parseTunaGenerate(res.data);
  } on DioException {
    return null;
  }
}
