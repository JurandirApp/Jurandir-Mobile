import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/data/models.dart';
import '../../../core/data/orders_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/dark_header.dart';
import '../../../l10n/i18n.dart';
import '../../shell/client_mode.dart';
import '../resume_order.dart';

/// Meus pedidos: status real (Neon) dos pedidos que este aparelho criou.
/// Puxe pra baixo pra atualizar o status.
class PedidosScreen extends ConsumerWidget {
  const PedidosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myOrdersProvider);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          DarkHeader(title: context.tr('pedidos.title')),
          Expanded(
            child: async.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.coral, strokeWidth: 3),
              ),
              error: (_, _) => _empty(context),
              data: (orders) => orders.isEmpty
                  ? _empty(context)
                  : RefreshIndicator(
                      color: AppColors.coral,
                      onRefresh: () async => ref.invalidate(myOrdersProvider),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                        itemCount: orders.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _orderCard(context, ref, orders[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.receipt_long, size: 44, color: AppColors.inkA(0.4)),
            const SizedBox(height: 12),
            Text(context.tr('pedidos.empty'),
                style: AppText.body(size: 14, weight: FontWeight.w600, color: AppColors.inkA(0.45))),
            const SizedBox(height: 16),
            AppButton.primary(
              label: context.tr('pedidos.scanAndOrder'),
              icon: Symbols.qr_code_scanner,
              expand: false,
              onPressed: () => context.go('/scanner'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderCard(BuildContext context, WidgetRef ref, ClientOrder o) {
    final resumable = canResumePayment(o);
    // Aguardando pagamento: o card inteiro (e o botão) leva de volta ao
    // pagamento — o cliente não precisa refazer a compra se saiu da tela.
    return GestureDetector(
      onTap: resumable ? () => resumeOrderPayment(context, ref, o) : null,
      child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.ink, width: 2),
        boxShadow: const [BoxShadow(color: AppColors.ink, offset: Offset(4, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(o.code, style: AppText.display(size: 15, letterSpacing: -0.2)),
              _statusChip(context, o.status),
            ],
          ),
          if (o.note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(o.note,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.45))),
          ],
          const SizedBox(height: 10),
          for (final it in o.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text('${it.qty}× ${it.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body(size: 13, weight: FontWeight.w500)),
                      ),
                      Text(money(it.price * it.qty),
                          style: AppText.body(size: 13, weight: FontWeight.w600)),
                    ],
                  ),
                  if (it.options.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 14, top: 1),
                      child: Text('+ ${it.options.join(', ')}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.45))),
                    ),
                  // Só mostra o acompanhamento por quantidade quando há
                  // progresso real (pronto/a caminho/entregue) — pedido recém
                  // criado (tudo "preparando") não agrega informação nova.
                  if (it.ready + it.outForDelivery + it.delivered > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 14, top: 1),
                      child: Text(it.statusLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.45))),
                    ),
                ],
              ),
            ),
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.inkA(0.08))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(context.tr('common.total'), style: AppText.body(size: 13, weight: FontWeight.w700)),
                Text(money(o.grand),
                    style: AppText.body(size: 14, weight: FontWeight.w800, color: AppColors.coralDeep)),
              ],
            ),
          ),
          if (resumable) ...[
            const SizedBox(height: 12),
            AppButton.primary(
              // Modo visualização: o botão continua visível (é o que o cliente
              // vê), mas tocar só avisa que o pagamento está desativado.
              label: ref.watch(previewModeProvider) ? previewPaymentBlockedMsg : context.tr('pedidos.resumePayment'),
              icon: Symbols.payments,
              onPressed: () => resumeOrderPayment(context, ref, o),
            ),
          ],
          if (o.code4 != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(context.tr('pedidos.deliveryCode', {'code': o.code4}),
                    style: AppText.display(size: 16, letterSpacing: -0.2)),
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }

  Widget _statusChip(BuildContext context, String status) {
    final (String label, Color bg, Color fg) = switch (status) {
      'producao' => (context.tr('pedidos.statusProducao'), AppColors.coral, Colors.white),
      'entregue' => (context.tr('pedidos.statusEntregue'), AppColors.successBg, AppColors.successText),
      _ => (context.tr('pedidos.statusAguardando'), AppColors.amber, AppColors.ink),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label.toUpperCase(),
          style: AppText.body(size: 10, weight: FontWeight.w800, color: fg)),
    );
  }
}
