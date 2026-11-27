import 'package:dio/dio.dart';

import 'tuna_threeds.dart';
import '../../l10n/i18n.dart';

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

/// Token de uso único da Tuna + a bandeira (vai no `tuna.brand` da cobrança) +
/// os dados 3DS (`auth`) quando o Generate/Bind foi chamado com o código 3DS
/// (débito) e a Tuna devolveu `authenticationInformation`.
typedef TunaToken = ({String token, String? brand, TunaAuthInfo? auth});

/// Corpo do `POST <tokenUrl>/api/Token/Generate`. `singleUse: false` SALVA o
/// cartão no customer da sessão (só com a sessão do aparelho — cartões salvos).
/// `authCode` (débito, 3DS): pede à Tuna os dados do Cardinal pra autenticação.
Map<String, dynamic> tunaGenerateBody(String sessionId, TunaCard card, {bool singleUse = true, String? authCode}) => {
      'sessionId': sessionId,
      'card': {
        'cardNumber': card.number.replaceAll(RegExp(r'\D'), ''),
        'cardHolderName': card.holder.trim(),
        'expirationMonth': card.expMonth,
        'expirationYear': card.expYear,
        'cvv': card.cvv.trim(),
        'singleUse': singleUse,
      },
      if (authCode != null && authCode.isNotEmpty) 'authenticationInformation': {'code': authCode},
    };

/// URL do Generate a partir do `tokenUrl` da sessão. Só HTTPS — o cartão cru
/// nunca sai do celular em texto puro. Null se a URL não servir.
String? tunaGenerateUrl(String tokenUrl) => tunaTokenApiUrl(tokenUrl, 'Generate');

/// URL de uma operação da API de token (`Generate`, `List`, `Bind`, `Delete`).
/// Só HTTPS; null se a URL não servir.
String? tunaTokenApiUrl(String tokenUrl, String op) {
  final uri = Uri.tryParse(tokenUrl.trim());
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
  return '${uri.toString().replaceFirst(RegExp(r'/+$'), '')}/api/Token/$op';
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
  return (
    token: token,
    brand: brand is String && brand.isNotEmpty ? brand : null,
    auth: parseTunaAuthInfo(data),
  );
}

/// Tokeniza o cartão DIRETO na Tuna com a sessão do pedido (`/tuna/session`):
/// o cartão cru nunca passa pelo nosso backend e nenhuma chave vai no app (a
/// sessão é a "chave pública"). Dio separado — sem baseUrl nem headers do nosso
/// backend. Null em qualquer falha (cartão inválido, sessão expirada, sem rede).
Future<TunaToken?> tunaGenerateToken({
  required String tokenUrl,
  required String sessionId,
  required TunaCard card,
  bool singleUse = true,
  String? authCode,
  Dio? dio,
}) async {
  final url = tunaGenerateUrl(tokenUrl);
  if (url == null || sessionId.isEmpty) return null;
  try {
    final res = await (dio ?? _tunaDio())
        .post<Object?>(url, data: tunaGenerateBody(sessionId, card, singleUse: singleUse, authCode: authCode));
    return parseTunaGenerate(res.data);
  } on DioException {
    return null;
  }
}

/// Dio só pra Tuna — sem baseUrl nem headers do nosso backend.
Dio _tunaDio() => Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    ));

// ---- Cartões salvos (sessão do APARELHO, de `/tuna/cards/session`) ----------
// A Tuna só lista os cartões do customer da sessão: o token salvo só aparece
// pro aparelho dono, e o CVV é pedido sempre (Bind). Nunca logar token/CVV.

/// Cartão salvo na Tuna (vem do Token/List). Sem número completo nem CVV.
class TunaSavedCard {
  final String token;
  final String? brand;
  final int? expMonth;
  final int? expYear;
  final String maskedNumber; // ex.: "520000xxxxxx2235"
  const TunaSavedCard({
    required this.token,
    this.brand,
    this.expMonth,
    this.expYear,
    required this.maskedNumber,
  });

  /// Últimos 4 dígitos do número mascarado ('' se não houver).
  String get last4 {
    final d = maskedNumber.replaceAll(RegExp(r'\D'), '');
    return d.length >= 4 ? d.substring(d.length - 4) : '';
  }

  /// Ex.: "Mastercard •••• 2235 · 01/30".
  String get label {
    final b = switch ((brand ?? '').trim()) {
      '' => tr('payments.card'),
      'Master' => 'Mastercard',
      final x => x,
    };
    final m = expMonth;
    final y = expYear;
    final exp = m != null && y != null
        ? ' · ${m.toString().padLeft(2, '0')}/${(y % 100).toString().padLeft(2, '0')}'
        : '';
    return '$b •••• $last4$exp';
  }
}

/// Corpo do `Token/List`.
Map<String, dynamic> tunaListBody(String sessionId) => {'sessionId': sessionId};

/// Lê o `Token/List`: só itens com token. `code < 0` ou formato estranho → null.
List<TunaSavedCard>? parseTunaList(Object? data) {
  if (data is! Map) return null;
  final code = data['code'];
  if (code is! num || code < 0) return null;
  final tokens = data['tokens'];
  if (tokens == null) return const [];
  if (tokens is! List) return null;
  int? asInt(Object? v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);
  String? asStr(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
  return [
    for (final t in tokens)
      if (t is Map && asStr(t['token']) != null)
        TunaSavedCard(
          token: asStr(t['token'])!,
          brand: asStr(t['brand']),
          expMonth: asInt(t['expirationMonth']),
          expYear: asInt(t['expirationYear']),
          maskedNumber: asStr(t['maskedNumber']) ?? '',
        ),
  ];
}

/// Corpo do `Token/Bind` (vincula o CVV ao token salvo pra esta cobrança).
/// `authCode` (débito, 3DS): igual ao Generate — se a Tuna devolver
/// `authenticationInformation`, o débito com cartão salvo também leva 3DS.
Map<String, dynamic> tunaBindBody(String sessionId, String token, String cvv, {String? authCode}) => {
      'sessionId': sessionId,
      'token': token,
      'cvv': cvv.trim(),
      if (authCode != null && authCode.isNotEmpty) 'authenticationInformation': {'code': authCode},
    };

/// Corpo do `Token/Delete`.
Map<String, dynamic> tunaDeleteBody(String sessionId, String token) => {'sessionId': sessionId, 'token': token};

/// Resposta da Tuna com `code >= 0` = deu certo (Bind/Delete).
bool parseTunaOk(Object? data) {
  if (data is! Map) return false;
  final code = data['code'];
  return code is num && code >= 0;
}

/// Lista os cartões salvos do aparelho. Null em qualquer falha (nunca lança).
Future<List<TunaSavedCard>?> tunaListCards({required String tokenUrl, required String sessionId, Dio? dio}) async {
  final url = tunaTokenApiUrl(tokenUrl, 'List');
  if (url == null || sessionId.isEmpty) return null;
  try {
    final res = await (dio ?? _tunaDio()).post<Object?>(url, data: tunaListBody(sessionId));
    return parseTunaList(res.data);
  } on DioException {
    return null;
  }
}

/// Vincula o CVV ao cartão salvo. false em qualquer falha (nunca lança).
Future<bool> tunaBindCvv({
  required String tokenUrl,
  required String sessionId,
  required String token,
  required String cvv,
  Dio? dio,
}) async =>
    (await tunaBind(tokenUrl: tokenUrl, sessionId: sessionId, token: token, cvv: cvv, dio: dio)).ok;

/// Bind do CVV com o código 3DS opcional. `auth` = `authenticationInformation`
/// da resposta (se a Tuna devolver). `ok: false` em qualquer falha (nunca lança).
Future<({bool ok, TunaAuthInfo? auth})> tunaBind({
  required String tokenUrl,
  required String sessionId,
  required String token,
  required String cvv,
  String? authCode,
  Dio? dio,
}) async {
  final url = tunaTokenApiUrl(tokenUrl, 'Bind');
  if (url == null || sessionId.isEmpty || token.isEmpty) return (ok: false, auth: null);
  try {
    final res = await (dio ?? _tunaDio())
        .post<Object?>(url, data: tunaBindBody(sessionId, token, cvv, authCode: authCode));
    final ok = parseTunaOk(res.data);
    return (ok: ok, auth: ok ? parseTunaAuthInfo(res.data) : null);
  } on DioException {
    return (ok: false, auth: null);
  }
}

/// Apaga o cartão salvo na Tuna. false em qualquer falha (nunca lança).
Future<bool> tunaDeleteCard({required String tokenUrl, required String sessionId, required String token, Dio? dio}) async {
  final url = tunaTokenApiUrl(tokenUrl, 'Delete');
  if (url == null || sessionId.isEmpty || token.isEmpty) return false;
  try {
    final res = await (dio ?? _tunaDio()).post<Object?>(url, data: tunaDeleteBody(sessionId, token));
    return parseTunaOk(res.data);
  } on DioException {
    return false;
  }
}
