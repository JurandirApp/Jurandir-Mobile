import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/data/models.dart';
import '../../../core/data/public_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../../core/widgets/dark_header.dart';

/// Admin · Faturamento por estabelecimento (real, todo o período).
class AdminFaturamentoScreen extends ConsumerWidget {
  const AdminFaturamentoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminOverviewProvider);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          const DarkHeader(eyebrow: 'Plataforma', title: 'Faturamento'),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.coral, strokeWidth: 3)),
              error: (_, _) => _error(ref),
              data: (ov) {
                final ests = (ov?.establishments ?? const <AdminEstablishment>[]).toList()
                  ..sort((a, b) => b.gmv.compareTo(a.gmv));
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  children: [
                    Text('Faturamento e fees por estabelecimento.',
                        style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
                    const SizedBox(height: 12),
                    for (final e in ests) ...[_card(e), const SizedBox(height: 10)],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _error(WidgetRef ref) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Symbols.cloud_off, size: 40, color: AppColors.inkA(0.4)),
              const SizedBox(height: 12),
              Text('Não foi possível carregar o faturamento.',
                  style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => ref.invalidate(adminOverviewProvider),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(999)),
                  child: Text('Tentar de novo',
                      style: AppText.body(size: 13, weight: FontWeight.w800, color: AppColors.dune)),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _card(AdminEstablishment e) {
    return BrutalCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: AppText.display(size: 14, weight: FontWeight.w700, letterSpacing: 0)),
                    const SizedBox(height: 1),
                    Text(e.city, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ativoBadge(e.active),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: statCell('Faturamento', money(e.gmv))),
              const SizedBox(width: 6),
              Expanded(child: statCell('Pedidos', groupThousands(e.orders))),
              const SizedBox(width: 6),
              Expanded(child: statCell('Fee (${e.feePct}%)', money(e.fees), color: AppColors.successText)),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _ativoBadge(bool active) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: active ? AppColors.successBg : AppColors.inkA(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(active ? 'Ativo' : 'Inativo',
          style: AppText.body(size: 10, weight: FontWeight.w700, color: active ? AppColors.successText : AppColors.inkA(0.5))),
    );

/// Célula de stat (fundo areia) reutilizada em Faturamento/Cadastros.
Widget statCell(String label, String value, {Color? color}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      decoration: BoxDecoration(color: AppColors.duneA(0.4), borderRadius: BorderRadius.circular(9)),
      child: Column(
        children: [
          Text(label.toUpperCase(),
              textAlign: TextAlign.center, style: AppText.body(size: 9, weight: FontWeight.w700, color: AppColors.inkA(0.5))),
          const SizedBox(height: 1),
          Text(value, style: AppText.display(size: 12, letterSpacing: 0, color: color ?? AppColors.ink)),
        ],
      ),
    );
