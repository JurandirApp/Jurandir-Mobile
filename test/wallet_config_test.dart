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
