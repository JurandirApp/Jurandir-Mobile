import 'dart:math';

/// Device fingerprint do antifraude da Tuna (CyberSource Decision Manager /
/// ThreatMetrix). O app gera um id de sessão do dispositivo, carrega o
/// `tags.js` da CyberSource numa WebView invisível (precisa de 5–10 s rodando
/// antes de cobrar) e manda o MESMO id (sem o prefixo do merchant) na cobrança.
///
/// O id da sessão identifica o dispositivo no antifraude: nunca logar.

/// Configuração vinda de `GET /tuna/fingerprint`. Desligado (ou sem org/merchant)
/// → o fingerprint é pulado em silêncio.
class TunaFingerprintConfig {
  const TunaFingerprintConfig({required this.enabled, this.orgId, this.merchantId});

  /// Fingerprint desligado — usado em qualquer erro/timeout da config.
  const TunaFingerprintConfig.disabled() : this(enabled: false);

  final bool enabled;
  final String? orgId;
  final String? merchantId;

  /// Só roda com tudo preenchido (org + merchant).
  bool get usable =>
      enabled && (orgId?.isNotEmpty ?? false) && (merchantId?.isNotEmpty ?? false);

  /// Lê o JSON do backend; qualquer formato inesperado vira "desligado".
  factory TunaFingerprintConfig.fromJson(Object? json) {
    if (json is! Map) return const TunaFingerprintConfig.disabled();
    final enabled = json['enabled'] == true;
    final orgId = json['orgId'];
    final merchantId = json['merchantId'];
    return TunaFingerprintConfig(
      enabled: enabled,
      orgId: orgId is String ? orgId.trim() : null,
      merchantId: merchantId is String ? merchantId.trim() : null,
    );
  }
}

/// Id da sessão do dispositivo: 32 caracteres hex minúsculos (16 bytes de
/// `Random.secure()`). Um novo por abertura do checkout.
String generateDeviceSessionId([Random? random]) {
  final r = random ?? Random.secure();
  final sb = StringBuffer();
  for (var i = 0; i < 16; i++) {
    sb.write(r.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

/// URL do `tags.js` da CyberSource: `session_id` = merchantId + id do dispositivo.
String tunaFingerprintTagUrl({
  required String orgId,
  required String merchantId,
  required String deviceSessionId,
}) =>
    'https://h.online-metrix.net/fp/tags.js'
    '?org_id=${Uri.encodeQueryComponent(orgId)}'
    '&session_id=${Uri.encodeQueryComponent(merchantId + deviceSessionId)}';

/// HTML mínimo que só carrega o `tags.js` (vai na WebView invisível).
String tunaFingerprintHtml(String tagUrl) {
  final src = tagUrl.replaceAll('&', '&amp;').replaceAll('"', '&quot;');
  return '<!DOCTYPE html><html><head><meta charset="utf-8">'
      '<meta name="viewport" content="width=device-width,initial-scale=1">'
      '</head><body><script type="text/javascript" src="$src"></script></body></html>';
}
