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
          const DarkHeader(title: 'Meus pedidos'),
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
                        itemBuilder: (_, i) => _orderCard(orders[i]),
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
            Text('Nenhum pedido ainda.',
                style: AppText.body(size: 14, weight: FontWeight.w600, color: AppColors.inkA(0.45))),
            const SizedBox(height: 16),
            AppButton.primary(
              label: 'Escanear e pedir',
              icon: Symbols.qr_code_scanner,
              expand: false,
              onPressed: () => context.go('/scanner'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderCard(ClientOrder o) {
    return Container(
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
              _statusChip(o.status),
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
              child: Row(
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
                Text('Total', style: AppText.body(size: 13, weight: FontWeight.w700)),
                Text(money(o.grand),
                    style: AppText.body(size: 14, weight: FontWeight.w800, color: AppColors.coralDeep)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final (String label, Color bg, Color fg) = switch (status) {
      'producao' => ('Em produção', AppColors.coral, Colors.white),
      'entregue' => ('Entregue', AppColors.successBg, AppColors.successText),
      _ => ('Aguardando pagamento', AppColors.amber, AppColors.ink),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label.toUpperCase(),
          style: AppText.body(size: 10, weight: FontWeight.w800, color: fg)),
    );
  }
}
