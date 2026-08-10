import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/data/models.dart';
import '../../../core/data/seed_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../../core/widgets/filter_pill.dart';
import 'estab_sub_header.dart';

const _methodFilters = [
  ('todos', 'Todos'),
  ('pix', 'Pix'),
  ('credito', 'Crédito'),
  ('debito', 'Débito'),
  ('usdc', 'USDC'),
];

const _methodLabel = {'pix': 'Pix', 'credito': 'Crédito', 'debito': 'Débito', 'usdc': 'USDC'};
const _gwRate = {'pix': 0.99, 'credito': 3.49, 'debito': 1.99, 'usdc': 1.0};

String _relTime(int min) => min < 60 ? 'há ${min}min' : 'há ${(min / 60).floor()}h';

class EstabAuditoriaScreen extends StatefulWidget {
  const EstabAuditoriaScreen({super.key});

  @override
  State<EstabAuditoriaScreen> createState() => _EstabAuditoriaScreenState();
}

class _EstabAuditoriaScreenState extends State<EstabAuditoriaScreen> {
  String _method = 'todos';

  @override
  Widget build(BuildContext context) {
    final sales = kEstabOrders.where((o) => o.method != null).toList();
    final rows = _method == 'todos' ? sales : sales.where((o) => o.method == _method).toList();
    final total = rows.fold(0, (s, o) => s + o.total);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          const EstabSubHeader(title: 'Auditoria'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              children: [
                Text('Todas as vendas registradas para conferência.',
                    style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
                const SizedBox(height: 14),
                SizedBox(
                  height: 38,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var i = 0; i < _methodFilters.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          FilterPill(
                            label: _methodFilters[i].$2,
                            selected: _methodFilters[i].$1 == _method,
                            onTap: () => setState(() => _method = _methodFilters[i].$1),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                for (final o in rows) ...[
                  _row(o),
                  const SizedBox(height: 10),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total (${rows.length})',
                          style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.dune)),
                      Text(money(total), style: AppText.display(size: 16, letterSpacing: 0, color: AppColors.dune)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(EstabOrder o) {
    final rate = _gwRate[o.method] ?? 0;
    final fee = o.total * rate / 100;
    final rateStr = rate.toStringAsFixed(2).replaceAll('.', ',');
    return BrutalCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('PED-${o.id.toString().padLeft(4, '0')}',
                  style: AppText.body(size: 11, weight: FontWeight.w700, color: AppColors.inkA(0.5))
                      .copyWith(fontFamily: 'monospace')),
              Text(_relTime(o.minutesAgo), style: AppText.body(size: 11, weight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Symbols.location_on, size: 12, color: AppColors.coral),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text('${o.loc} · ${_methodLabel[o.method]}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.inkA(0.6))),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(money(o.total), style: AppText.body(size: 14, weight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Taxa gateway: ${money(fee)} ($rateStr%)',
              style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.4))),
        ],
      ),
    );
  }
}
