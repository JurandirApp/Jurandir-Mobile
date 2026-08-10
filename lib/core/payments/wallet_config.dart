/// Configuração das carteiras (Google/Apple Pay) para o plugin `pay`.
///
/// Env por `--dart-define`: PAY_ENV, PAY_GATEWAY, PAY_MERCHANT_ID,
/// APPLE_MERCHANT_ID. Default = ambiente de TESTE (gateway "example" do Google,
/// que devolve um token de teste — demoável no Android sem conta real).
///
/// Produção: `--dart-define=PAY_ENV=PRODUCTION --dart-define=PAY_GATEWAY=pagarme
/// --dart-define=PAY_MERCHANT_ID=SEU_RECEBEDOR`.
abstract final class WalletConfig {
  static const env = String.fromEnvironment('PAY_ENV', defaultValue: 'TEST');
  static const gateway = String.fromEnvironment('PAY_GATEWAY', defaultValue: 'example');
  static const merchantId = String.fromEnvironment('PAY_MERCHANT_ID', defaultValue: 'exampleGatewayMerchantId');
  static const appleMerchantId = String.fromEnvironment('APPLE_MERCHANT_ID', defaultValue: 'merchant.br.app.jurandir');
  static const merchantName = 'Jurandir';

  static String get googlePay =>
      '{"provider":"google_pay","data":{"environment":"$env","apiVersion":2,"apiVersionMinor":0,'
      '"allowedPaymentMethods":[{"type":"CARD","tokenizationSpecification":{"type":"PAYMENT_GATEWAY",'
      '"parameters":{"gateway":"$gateway","gatewayMerchantId":"$merchantId"}},'
      '"parameters":{"allowedCardNetworks":["VISA","MASTERCARD","ELO"],"allowedAuthMethods":["PAN_ONLY","CRYPTOGRAM_3DS"]}}],'
      '"merchantInfo":{"merchantName":"$merchantName"},'
      '"transactionInfo":{"countryCode":"BR","currencyCode":"BRL"}}}';

  static String get applePay =>
      '{"provider":"apple_pay","data":{"merchantIdentifier":"$appleMerchantId","displayName":"$merchantName",'
      '"merchantCapabilities":["3DS","debit","credit"],"supportedNetworks":["visa","masterCard"],'
      '"countryCode":"BR","currencyCode":"BRL"}}';
}
