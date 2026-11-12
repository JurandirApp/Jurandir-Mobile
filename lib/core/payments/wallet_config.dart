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
/// - PAGBANK_MERCHANT_ID: `ACCO_…` da conta PagBank da plataforma — usado quando o
///   Google Pay do estabelecimento está no PagBank (`gateway: pagbank`).
/// - TUNA_GPAY_GATEWAY_MERCHANT_ID: `gatewayMerchantId` da Tuna (`gateway: tuna`),
///   usado quando o Google Pay do estabelecimento está na Tuna. Default = o id
///   que a própria Tuna usa (tuna.js, igual em produção e sandbox).
///
/// O ambiente do Google (TEST/PRODUCTION) é SEMPRE o PAY_ENV, pra qualquer
/// gateway. Homolog/staging da Tuna aceita token TEST do Google (PAY_ENV=TEST).
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

  /// `gatewayMerchantId` do PagBank = o account id (`ACCO_…`) da conta da plataforma.
  static const pagbankMerchantId = String.fromEnvironment('PAGBANK_MERCHANT_ID', defaultValue: '');

  /// `gatewayMerchantId` da Tuna (confirmado funcionando com a Tuna).
  static const tunaMerchantId =
      String.fromEnvironment('TUNA_GPAY_GATEWAY_MERCHANT_ID', defaultValue: '78c30483-2a55-422e-98f1-b68f77fcaa70');

  /// Config do Google Pay pro gateway escolhido pelo estabelecimento (nome do
  /// enum do backend). PagBank usa `gateway: pagbank` + o `ACCO_…`; sem o
  /// PAGBANK_MERCHANT_ID definido, cai na config padrão (PAY_GATEWAY). Tuna usa
  /// `gateway: tuna` + o TUNA_GPAY_GATEWAY_MERCHANT_ID.
  static String googlePayFor(String backendGateway) {
    final pagbank = backendGateway == 'PAGBANK' && pagbankMerchantId.isNotEmpty;
    final tuna = backendGateway == 'TUNA' && tunaMerchantId.isNotEmpty;
    final gw = tuna ? 'tuna' : (pagbank ? 'pagbank' : gateway);
    final mid = tuna ? tunaMerchantId : (pagbank ? pagbankMerchantId : merchantId);
    return '{"provider":"google_pay","data":{"environment":"$env","apiVersion":2,"apiVersionMinor":0,'
        '"allowedPaymentMethods":[{"type":"CARD","tokenizationSpecification":{"type":"PAYMENT_GATEWAY",'
        '"parameters":{"gateway":"$gw","gatewayMerchantId":"$mid"}},'
        '"parameters":{"allowedCardNetworks":["VISA","MASTERCARD","ELO"],"allowedAuthMethods":["PAN_ONLY","CRYPTOGRAM_3DS"]}}],'
        '"merchantInfo":$_merchantInfo,'
        '"transactionInfo":{"countryCode":"BR","currencyCode":"BRL"}}}';
  }

  static String get applePay =>
      '{"provider":"apple_pay","data":{"merchantIdentifier":"$appleMerchantId","displayName":"$merchantName",'
      '"merchantCapabilities":["3DS","credit"],"supportedNetworks":["visa","masterCard","elo"],'
      '"countryCode":"BR","currencyCode":"BRL"}}';
}
