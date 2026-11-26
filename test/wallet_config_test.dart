import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jurandir/core/payments/wallet_config.dart';

/// `tokenizationSpecification.parameters` + ambiente da config do Google Pay.
({String gateway, String merchantId, String env}) _params(String backendGateway) {
  final j = jsonDecode(WalletConfig.googlePayFor(backendGateway)) as Map<String, dynamic>;
  final data = j['data'] as Map<String, dynamic>;
  final pm = (data['allowedPaymentMethods'] as List).first as Map<String, dynamic>;
  final p = (pm['tokenizationSpecification'] as Map<String, dynamic>)['parameters'] as Map<String, dynamic>;
  return (
    gateway: p['gateway'] as String,
    merchantId: p['gatewayMerchantId'] as String,
    env: data['environment'] as String,
  );
}

// Sem --dart-define nos testes: valem os defaults (PAY_ENV=TEST, PAY_GATEWAY=example).
void main() {
  test('TUNA → gateway tuna + merchant id da Tuna', () {
    final p = _params('TUNA');
    expect(p.gateway, 'tuna');
    expect(p.merchantId, '78c30483-2a55-422e-98f1-b68f77fcaa70');
    expect(p.env, WalletConfig.env);
  });

  test('TUNA usa o gatewayMerchantId vindo do servidor quando informado', () {
    final j = jsonDecode(WalletConfig.googlePayFor('TUNA', tunaGatewayMerchantId: ' prod-id ')) as Map<String, dynamic>;
    final pm = ((j['data'] as Map)['allowedPaymentMethods'] as List).first as Map;
    final p = (pm['tokenizationSpecification'] as Map)['parameters'] as Map;
    expect(p['gateway'], 'tuna');
    expect(p['gatewayMerchantId'], 'prod-id');
  });

  test('override vazio cai no id do build; outros gateways ignoram o override', () {
    final j = jsonDecode(WalletConfig.googlePayFor('TUNA', tunaGatewayMerchantId: '  ')) as Map<String, dynamic>;
    final pm = ((j['data'] as Map)['allowedPaymentMethods'] as List).first as Map;
    expect(((pm['tokenizationSpecification'] as Map)['parameters'] as Map)['gatewayMerchantId'], WalletConfig.tunaMerchantId);
    final pg = jsonDecode(WalletConfig.googlePayFor('PAGARME', tunaGatewayMerchantId: 'prod-id')) as Map<String, dynamic>;
    final pm2 = ((pg['data'] as Map)['allowedPaymentMethods'] as List).first as Map;
    expect(((pm2['tokenizationSpecification'] as Map)['parameters'] as Map)['gatewayMerchantId'], WalletConfig.merchantId);
  });

  test('Apple Pay: sem APPLE_MERCHANT_ID_TUNA a Tuna fica indisponível; outros gateways usam o ID padrão', () {
    expect(WalletConfig.appleMerchantIdTuna, '');
    expect(WalletConfig.applePayAvailableFor('TUNA'), isFalse);
    expect(WalletConfig.applePayAvailableFor('PAGARME'), isTrue);
    final j = jsonDecode(WalletConfig.applePayFor('PAGARME')) as Map<String, dynamic>;
    expect((j['data'] as Map)['merchantIdentifier'], WalletConfig.appleMerchantId);
    // Mesmo pedindo TUNA, sem o ID dela nunca usa outro merchant por engano.
    final t = jsonDecode(WalletConfig.applePayFor('TUNA')) as Map<String, dynamic>;
    expect((t['data'] as Map)['merchantIdentifier'], WalletConfig.appleMerchantId);
  });

  test('débito na carteira: Google só CRYPTOGRAM_3DS; Apple só cartões de débito', () {
    Map<String, dynamic> gpParams(bool debit) {
      final j = jsonDecode(WalletConfig.googlePayFor('TUNA', debit: debit)) as Map<String, dynamic>;
      final pm = ((j['data'] as Map)['allowedPaymentMethods'] as List).first as Map;
      return (pm['parameters'] as Map).cast<String, dynamic>();
    }

    expect(gpParams(true)['allowedAuthMethods'], ['CRYPTOGRAM_3DS']);
    expect(gpParams(false)['allowedAuthMethods'], ['PAN_ONLY', 'CRYPTOGRAM_3DS']);
    final ap = jsonDecode(WalletConfig.applePayFor('PAGARME', debit: true)) as Map<String, dynamic>;
    expect((ap['data'] as Map)['merchantCapabilities'], ['3DS', 'debit']);
    final ac = jsonDecode(WalletConfig.applePayFor('PAGARME')) as Map<String, dynamic>;
    expect((ac['data'] as Map)['merchantCapabilities'], ['3DS', 'credit']);
  });

  test('PAGARME continua na config padrão (PAY_GATEWAY)', () {
    final p = _params('PAGARME');
    expect(p.gateway, WalletConfig.gateway);
    expect(p.merchantId, WalletConfig.merchantId);
  });

  test('PAGBANK sem PAGBANK_MERCHANT_ID cai na config padrão', () {
    expect(_params('PAGBANK').gateway, WalletConfig.gateway);
  });

  test('config é JSON válido pro plugin pay', () {
    final j = jsonDecode(WalletConfig.googlePayFor('TUNA')) as Map<String, dynamic>;
    expect(j['provider'], 'google_pay');
  });
}
