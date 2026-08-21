/// Configuração das carteiras (Google/Apple Pay) para o plugin `pay`.
///
/// Env por `--dart-define` (ou `dart_defines.json`):
/// - PAY_ENV: TEST | PRODUCTION (PRODUCTION = cartões reais → cobra de verdade).
/// - PAY_GATEWAY: para a Pagar.me use `pagarme` (doc oficial). Default `example`
///   (gateway de TESTE do Google, devolve token fake — demoável sem conta real).
/// - PAY_MERCHANT_ID: o `gatewayMerchantId` = o **account_id da Pagar.me**
///   (ex.: `acc_8Vj4qPGTaA9PTsl`), do painel da Pagar.me.
/// - GOOGLE_MERCHANT_ID: o merchant id do **Google Pay Business Console**
///   (`merchantInfo.merchantId`). Obrigatório em PRODUCTION.
/// - APPLE_MERCHANT_ID: Merchant ID da Apple (`merchant.br.app.jurandir`).
///
/// Produção Google Pay:
/// `--dart-define=PAY_ENV=PRODUCTION --dart-define=PAY_GATEWAY=pagarme
///  --dart-define=PAY_MERCHANT_ID=acc_xxx --dart-define=GOOGLE_MERCHANT_ID=xxx`.
abstract final class WalletConfig {
  static const env = String.fromEnvironment('PAY_ENV', defaultValue: 'TEST');
  static const gateway = String.fromEnvironment('PAY_GATEWAY', defaultValue: 'example');
  static const merchantId = String.fromEnvironment('PAY_MERCHANT_ID', defaultValue: 'exampleGatewayMerchantId');
  static const googleMerchantId = String.fromEnvironment('GOOGLE_MERCHANT_ID', defaultValue: '');
  static const appleMerchantId = String.fromEnvironment('APPLE_MERCHANT_ID', defaultValue: 'merchant.br.app.jurandir');
  static const merchantName = 'Jurandir';

  /// `merchantInfo` do Google Pay. Inclui o `merchantId` do Google só quando
  /// definido (em TEST ele é opcional; em PRODUCTION é obrigatório).
  static String get _merchantInfo => googleMerchantId.isEmpty
      ? '{"merchantName":"$merchantName"}'
      : '{"merchantId":"$googleMerchantId","merchantName":"$merchantName"}';

  static String get googlePay =>
      '{"provider":"google_pay","data":{"environment":"$env","apiVersion":2,"apiVersionMinor":0,'
      '"allowedPaymentMethods":[{"type":"CARD","tokenizationSpecification":{"type":"PAYMENT_GATEWAY",'
      '"parameters":{"gateway":"$gateway","gatewayMerchantId":"$merchantId"}},'
      '"parameters":{"allowedCardNetworks":["VISA","MASTERCARD","ELO"],"allowedAuthMethods":["PAN_ONLY","CRYPTOGRAM_3DS"]}}],'
      '"merchantInfo":$_merchantInfo,'
      '"transactionInfo":{"countryCode":"BR","currencyCode":"BRL"}}}';

  static String get applePay =>
      '{"provider":"apple_pay","data":{"merchantIdentifier":"$appleMerchantId","displayName":"$merchantName",'
      '"merchantCapabilities":["3DS","debit","credit"],"supportedNetworks":["visa","masterCard"],'
      '"countryCode":"BR","currencyCode":"BRL"}}';
}
