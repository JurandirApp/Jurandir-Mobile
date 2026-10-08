import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/data/models.dart';
import '../../../core/data/public_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/brutal_card.dart';
import 'admin_faturamento_screen.dart' show statCell;
import 'admin_sub_header.dart';

/// Admin · Repasse Débito: débito Pagar.me pago a repassar (Pix) por bar, por
/// período. Mesma lógica da web — valor a repassar = total menos a taxa Jurandir.
class AdminRepasseDebitoScreen extends ConsumerStatefulWidget {
  const AdminRepasseDebitoScreen({super.key});

  @override
  ConsumerState<AdminRepasseDebitoScreen> createState() => _AdminRepasseDebitoState();
}

class _AdminRepasseDebitoState extends ConsumerState<AdminRepasseDebitoScreen> {
  // (valor da API, rótulo do pill)
  static const _periods = [
    ('hoje', 'Hoje'),
    ('7d', '7 dias'),
    ('30d', '30 dias'),
    ('tudo', 'Tudo'),
  ];
  String _period = 'hoje';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminDebitPayoutProvider(_period));
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          const AdminSubHeader(title: 'Repasse Débito'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Text(
              'Débitos Pagar.me pagos no período. Valor a repassar por bar = total menos a taxa Jurandir.',
              style: AppText.body(size: 12, weight: FontWeight.w600, height: 1.4, color: AppColors.inkA(0.5)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (final p in _periods) ...[_pill(p.$1, p.$2), const SizedBox(width: 8)],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.coral, strokeWidth: 3)),
              error: (_, _) => _error(),
              data: _list,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String value, String label) {
    final active = _period == value;
    return GestureDetector(
      onTap: () => setState(() => _period = value),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: active ? AppColors.ink : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? AppColors.ink : AppColors.inkA(0.15), width: 2),
        ),
        child: Text(label,
            style: AppText.body(size: 12, weight: FontWeight.w700, color: active ? AppColors.dune : AppColors.inkA(0.6))),
      ),
    );
  }

  Widget _error() => Center(
        child: GestureDetector(
          onTap: () => ref.invalidate(adminDebitPayoutProvider(_period)),
          child: Text('Erro ao carregar. Toque para tentar de novo.',
              style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.inkA(0.5))),
        ),
      );

  Widget _list(List<DebitPayoutRow> rows) {
    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Symbols.payments, size: 40, color: AppColors.inkA(0.35)),
              const SizedBox(height: 12),
              Text('Nenhum débito no período.',
                  style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
            ],
          ),
        ),
      );
    }
    final total = rows.fold<double>(0, (s, r) => s + r.aRepassar);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
      children: [
        BrutalCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          background: AppColors.ink,
          child: Row(
            children: [
              const Icon(Symbols.account_balance_wallet, size: 22, color: AppColors.amber),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Total a repassar (Pix)',
                    style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.duneA(0.85))),
              ),
              Text(money(total), style: AppText.display(size: 18, letterSpacing: 0, color: AppColors.dune)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (final r in rows) ...[_card(r), const SizedBox(height: 10)],
      ],
    );
  }

  Widget _card(DebitPayoutRow r) {
    return BrutalCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(r.nome.isEmpty ? '—' : r.nome, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: AppText.display(size: 14, weight: FontWeight.w700, letterSpacing: 0)),
              ),
              const SizedBox(width: 8),
              Text('${r.qtd} déb.', style: AppText.body(size: 11, weight: FontWeight.w700, color: AppColors.inkA(0.5))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: statCell('Bruto', money(r.bruto))),
              const SizedBox(width: 6),
              Expanded(child: statCell('Taxa Jurandir', money(r.taxa), color: AppColors.coralDeep)),
              const SizedBox(width: 6),
              Expanded(child: statCell('A repassar', money(r.aRepassar), color: AppColors.successText)),
            ],
          ),
        ],
      ),
    );
  }
}
