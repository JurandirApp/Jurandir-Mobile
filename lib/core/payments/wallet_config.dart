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
  ///
  /// [tunaGatewayMerchantId]: o id vindo do servidor (GET /tuna/wallet-config);
  /// tem prioridade sobre o fixo no build, pra trocar sem versão nova.
  static String googlePayFor(String backendGateway, {String? tunaGatewayMerchantId}) {
    final tunaMid = (tunaGatewayMerchantId?.trim().isNotEmpty ?? false) ? tunaGatewayMerchantId!.trim() : tunaMerchantId;
    final pagbank = backendGateway == 'PAGBANK' && pagbankMerchantId.isNotEmpty;
    final tuna = backendGateway == 'TUNA' && tunaMid.isNotEmpty;
    final gw = tuna ? 'tuna' : (pagbank ? 'pagbank' : gateway);
    final mid = tuna ? tunaMid : (pagbank ? pagbankMerchantId : merchantId);
    return '{"provider":"google_pay","data":{"environment":"$env","apiVersion":2,"apiVersionMinor":0,'
        '"allowedPaymentMethods":[{"type":"CARD","tokenizationSpecification":{"type":"PAYMENT_GATEWAY",'
        '"parameters":{"gateway":"$gw","gatewayMerchantId":"$mid"}},'
        '"parameters":{"allowedCardNetworks":["VISA","MASTERCARD","ELO"],"allowedAuthMethods":["PAN_ONLY","CRYPTOGRAM_3DS"]}}],'
        '"merchantInfo":$_merchantInfo,'
        '"transactionInfo":{"countryCode":"BR","currencyCode":"BRL"}}}';
  }

  /// Merchant ID da Apple usado quando o Apple Pay do bar está na TUNA. É um ID
  /// SEPARADO (o certificado de processamento é gerado pelo CSR da Tuna; o
  /// `merchant.br.app.jurandir` segue com o Pagar.me). Vazio = Apple Pay da Tuna
  /// desligado no app. Ao ligar, o ID também precisa estar no
  /// `Runner.entitlements` e na capability Apple Pay do App ID.
  static const appleMerchantIdTuna = String.fromEnvironment('APPLE_MERCHANT_ID_TUNA', defaultValue: '');

  /// Apple Pay disponível no app pro gateway do bar? (Tuna só com o ID dela.)
  static bool applePayAvailableFor(String backendGateway) =>
      backendGateway != 'TUNA' || appleMerchantIdTuna.isNotEmpty;

  /// Config do Apple Pay pro gateway do bar: Tuna usa o Merchant ID da Tuna;
  /// os demais, o padrão.
  static String applePayFor(String backendGateway) =>
      _applePayWith(backendGateway == 'TUNA' && appleMerchantIdTuna.isNotEmpty ? appleMerchantIdTuna : appleMerchantId);

  static String get applePay => _applePayWith(appleMerchantId);

  static String _applePayWith(String merchantIdentifier) =>
      '{"provider":"apple_pay","data":{"merchantIdentifier":"$merchantIdentifier","displayName":"$merchantName",'
      '"merchantCapabilities":["3DS","credit"],"supportedNetworks":["visa","masterCard","elo"],'
      '"countryCode":"BR","currencyCode":"BRL"}}';
}
