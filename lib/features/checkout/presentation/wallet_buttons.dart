import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:pay/pay.dart';

import '../../../core/payments/wallet_config.dart';

/// Botão de carteira nativa (Google Pay no Android / Apple Pay no iOS).
/// Renderiza nada no web (as carteiras não existem no preview do navegador).
/// Ao concluir, [onToken] recebe o resultado (com o token) do plugin.
class WalletButtons extends StatelessWidget {
  final double amount;
  final ValueChanged<Map<String, dynamic>> onToken;

  const WalletButtons({super.key, required this.amount, required this.onToken});

  List<PaymentItem> get _items => [
    PaymentItem(
      label: 'Total',
      amount: amount.toStringAsFixed(2),
      status: PaymentItemStatus.final_price,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return ApplePayButton(
        paymentConfiguration: PaymentConfiguration.fromJsonString(WalletConfig.applePay),
        paymentItems: _items,
        type: ApplePayButtonType.buy,
        style: ApplePayButtonStyle.black,
        width: double.infinity,
        height: 48,
        onPaymentResult: onToken,
        loadingIndicator: const Center(child: CircularProgressIndicator()),
      );
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return GooglePayButton(
        paymentConfiguration: PaymentConfiguration.fromJsonString(WalletConfig.googlePay),
        paymentItems: _items,
        type: GooglePayButtonType.pay,
        width: double.infinity,
        height: 48,
        onPaymentResult: onToken,
        loadingIndicator: const Center(child: CircularProgressIndicator()),
      );
    }

    return const SizedBox.shrink();
  }
}
