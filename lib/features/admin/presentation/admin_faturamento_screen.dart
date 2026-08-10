import 'package:flutter/material.dart';

import '../../../core/data/models.dart';
import '../../../core/data/seed_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../../core/widgets/dark_header.dart';
import '../../../core/widgets/segmented_control.dart';

class AdminFaturamentoScreen extends StatefulWidget {
  const AdminFaturamentoScreen({super.key});

  @override
  State<AdminFaturamentoScreen> createState() => _AdminFaturamentoScreenState();
}

class _AdminFaturamentoScreenState extends State<AdminFaturamentoScreen> {
  int _period = 3;
  double get _pf => [1 / 30, 7 / 30, 0.5, 1.0][_period];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          const DarkHeader(eyebrow: 'Plataforma', title: 'Faturamento'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              children: [
                SegmentedControl(
                  segments: const ['Dia', 'Semana', 'Quinzena', 'Mês'],
                  selected: _period,
                  onChanged: (i) => setState(() => _period = i),
                ),
                const SizedBox(height: 12),
                Text('Faturamento por estabelecimento · no período',
                    style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
                const SizedBox(height: 12),
                for (final e in kEstablishments) ...[
                  _card(e),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(Establishment e) {
    final rev = e.orders * 85 * _pf;
    final ped = (e.orders * _pf).round();
    final fee = estabFee(e.id);
    final feeVal = rev * fee / 100;
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
                    Text(e.location, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ativoBadge(),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: statCell('Faturamento', money(rev))),
              const SizedBox(width: 6),
              Expanded(child: statCell('Pedidos', groupThousands(ped))),
              const SizedBox(width: 6),
              Expanded(child: statCell('Fee (${fee.toStringAsFixed(0)}%)', money(feeVal), color: AppColors.successText)),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _ativoBadge() => Container(
  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
  decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(999)),
  child: Text('Ativo', style: AppText.body(size: 10, weight: FontWeight.w700, color: AppColors.successText)),
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
