import 'dart:convert';
import 'dart:math';

// 3DS da Tuna (débito). Doc: https://dev.tuna.uy/api/3ds-integration
//
// Fluxo: código curto → Token/Generate (ou Bind) com `authenticationInformation.code`
// → a Tuna devolve os dados do Cardinal (accessToken/DDC/referenceId/transactionId)
// → coleta de dados do aparelho (DDC, WebView invisível, best-effort) → cobrança
// com `tuna.threeDs` → se o banco pedir desafio, a resposta traz `challenge`
// (tela com o banco; o resultado vai direto pra Tuna e o app acompanha o pedido).
//
// NUNCA logar accessToken, token do desafio, referenceId/transactionId nem o código.

/// Gera o código de autenticação 3DS: `j3ds_` + 24 hex aleatórios (29 chars).
/// A Tuna aceita no máximo 50 chars (o sessionId dela tem 112 — não serve) e o
/// nosso servidor exige `^[A-Za-z0-9_-]{8,50}$`. O MESMO código vai no Generate
/// (ou Bind) e na cobrança.
String newTunaThreeDsCode([Random? random]) {
  final r = random ?? Random.secure();
  final hex = List.generate(24, (_) => r.nextInt(16).toRadixString(16)).join();
  return 'j3ds_$hex';
}

/// Formato aceito pelo servidor pro código 3DS.
final RegExp tunaThreeDsCodePattern = RegExp(r'^[A-Za-z0-9_-]{8,50}$');

/// Dados 3DS que a Tuna devolve no Generate/Bind (`authenticationInformation`).
/// Só em memória — nunca logar.
class TunaAuthInfo {
  final String? accessToken; // JWT do DDC (Cardinal)
  final String? deviceDataCollectionUrl;
  final String referenceId;
  final String transactionId;
  const TunaAuthInfo({
    this.accessToken,
    this.deviceDataCollectionUrl,
    required this.referenceId,
    required this.transactionId,
  });

  /// Dá pra rodar o DDC (tem JWT e URL https).
  bool get canCollect {
    final u = Uri.tryParse(deviceDataCollectionUrl ?? '');
    return (accessToken ?? '').isNotEmpty && u != null && u.scheme == 'https' && u.host.isNotEmpty;
  }
}

/// Lê `authenticationInformation` da resposta do Generate/Bind. Null se não vier
/// ou faltar referenceId/transactionId (sem eles a cobrança não leva 3DS).
TunaAuthInfo? parseTunaAuthInfo(Object? data) {
  if (data is! Map) return null;
  final a = data['authenticationInformation'];
  if (a is! Map) return null;
  String? s(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
  final ref = s(a['referenceId']);
  final tx = s(a['transactionId']);
  if (ref == null || tx == null) return null;
  return TunaAuthInfo(
    accessToken: s(a['accessToken']),
    deviceDataCollectionUrl: s(a['deviceDataCollectionUrl']),
    referenceId: ref,
    transactionId: tx,
  );
}

/// Bloco `tuna.threeDs` da cobrança.
Map<String, dynamic> tunaThreeDsBlock(String code, TunaAuthInfo auth) => {
      'code': code,
      'referenceId': auth.referenceId,
      'transactionId': auth.transactionId,
    };

/// Bloco `tuna.browser` da cobrança (dados do "navegador" pro 3DS). Tela em px
/// lógicos; `timeDifference` na convenção do JS `getTimezoneOffset` (UTC−3 → 180).
Map<String, dynamic> tunaBrowserBlock({
  required double screenWidth,
  required double screenHeight,
  required Duration timeZoneOffset,
  String? languageTag,
}) =>
    {
      if (languageTag != null && languageTag.isNotEmpty) 'acceptLanguage': languageTag,
      'colorDepth': 24,
      'screenHeight': screenHeight.round(),
      'screenWidth': screenWidth.round(),
      'timeDifference': -timeZoneOffset.inMinutes,
      'javaEnabled': false,
      'javaScriptEnabled': true,
    };

/// Desafio 3DS devolvido pela cobrança (`challenge: { url, token, paRequest? }`).
class TunaChallenge {
  final String url;
  final String token; // JWT do step-up — nunca logar
  final String? paRequest;
  const TunaChallenge({required this.url, required this.token, this.paRequest});
}

/// Lê o `challenge` da resposta do `/orders/card`. Só https; senão null.
TunaChallenge? parseTunaChallenge(Object? data) {
  if (data is! Map) return null;
  final url = data['url'];
  final token = data['token'];
  if (url is! String || token is! String || token.trim().isEmpty) return null;
  final u = Uri.tryParse(url.trim());
  if (u == null || u.scheme != 'https' || u.host.isEmpty) return null;
  final pa = data['paRequest'];
  return TunaChallenge(
    url: url.trim(),
    token: token.trim(),
    paRequest: pa is String && pa.trim().isNotEmpty ? pa.trim() : null,
  );
}

/// Tamanho da janela do desafio (`challengeWindowSize` do paRequest em base64).
/// 01=250×400, 02=390×400, 03=500×600, 04=600×400, 05=tela cheia. Null = tela
/// cheia (05, ausente ou ilegível).
({double width, double height})? tunaChallengeWindowSize(String? paRequest) {
  if (paRequest == null || paRequest.trim().isEmpty) return null;
  try {
    var b64 = paRequest.trim().replaceAll(RegExp(r'\s'), '').replaceAll('-', '+').replaceAll('_', '/');
    while (b64.length % 4 != 0) {
      b64 += '=';
    }
    final d = jsonDecode(utf8.decode(base64.decode(b64)));
    if (d is! Map) return null;
    final v = d['challengeWindowSize'];
    final code = v is num ? v.toInt().toString().padLeft(2, '0') : (v is String ? v.trim().padLeft(2, '0') : '');
    return switch (code) {
      '01' => (width: 250.0, height: 400.0),
      '02' => (width: 390.0, height: 400.0),
      '03' => (width: 500.0, height: 600.0),
      '04' => (width: 600.0, height: 400.0),
      _ => null,
    };
  } catch (_) {
    return null;
  }
}

/// Escapa texto pra atributo/conteúdo HTML.
String htmlEscape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

/// Nome do canal JS que a página do DDC usa pra avisar o app.
const String tunaDdcChannel = 'TunaDDC';

/// Página do DDC (Cardinal): iframe escondido + form POST com `JWT` e escuta o
/// `message` "profile.completed" (só de *.cardinalcommerce.com) → avisa o app
/// pelo canal [tunaDdcChannel]. Vai com `loadHtmlString` (base jurandir.app.br).
String tunaDdcHtml({required String url, required String jwt}) => '''<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;background:transparent">
<iframe id="ddc" name="ddc" style="display:none;width:0;height:0;border:0"></iframe>
<form id="ddcForm" method="POST" target="ddc" action="${htmlEscape(url)}">
<input type="hidden" name="JWT" value="${htmlEscape(jwt)}">
</form>
<script>
(function(){
  var sent=false;
  window.addEventListener('message',function(e){
    try{
      var host=new URL(e.origin).hostname;
      if(!/(^|\\.)cardinalcommerce\\.com\$/.test(host))return;
      var d=e.data;
      if(typeof d==='string'){d=JSON.parse(d);}
      if(!d||d.MessageType!=='profile.completed'||sent)return;
      sent=true;
      if(window.$tunaDdcChannel){window.$tunaDdcChannel.postMessage(d.Status===false?'failed':'completed');}
    }catch(_){}
  },false);
  document.getElementById('ddcForm').submit();
})();
</script>
</body></html>''';

/// Página do desafio: form POST (no próprio frame) pro `challenge.url` com o
/// `JWT` = `challenge.token`, enviado assim que carrega.
String tunaChallengeHtml(TunaChallenge c) => '''<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;background:#fff">
<form id="stepUp" method="POST" action="${htmlEscape(c.url)}">
<input type="hidden" name="JWT" value="${htmlEscape(c.token)}">
</form>
<script>document.getElementById('stepUp').submit();</script>
</body></html>''';
