import 'package:flutter/material.dart';

import '../../../core/data/seed_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../../core/widgets/dark_header.dart';
import '../../../core/widgets/filter_pill.dart';
import '../../../core/widgets/segmented_control.dart';

const _dims = [('city', 'Cidade'), ('bairro', 'Bairro'), ('culinaria', 'Culinária'), ('tipo', 'Tipo')];

class AdminBuscasScreen extends StatefulWidget {
  const AdminBuscasScreen({super.key});

  @override
  State<AdminBuscasScreen> createState() => _AdminBuscasScreenState();
}

class _AdminBuscasScreenState extends State<AdminBuscasScreen> {
  String _dim = 'city';
  int _period = 1; // 0=7d, 1=30d, 2=tudo

  double get _mult => [0.35, 1.0, 1.7][_period];

  @override
  Widget build(BuildContext context) {
    final rows = kBuscaDims[_dim]!;
    final abTot = rows.fold(0, (s, r) => s + r.$2);
    final abMax = rows.first.$2;
    final totalAll = kBuscaDims.values.expand((x) => x).fold(0, (s, r) => s + r.$2);
    final totalBuscas = (totalAll * _mult).round();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          const DarkHeader(eyebrow: 'Plataforma · 30 dias', title: 'Buscas'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              children: [
                SegmentedControl(
                  segments: const ['7 dias', '30 dias', 'Tudo'],
                  selected: _period,
                  onChanged: (i) => setState(() => _period = i),
                ),
                const SizedBox(height: 12),
                Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'O que os visitantes filtram — '),
                    TextSpan(text: groupThousands(totalBuscas), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
                    const TextSpan(text: ' buscas no período.'),
                  ]),
                  style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.inkA(0.5)),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 38,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var i = 0; i < _dims.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          FilterPill(label: _dims[i].$2, selected: _dims[i].$1 == _dim, onTap: () => setState(() => _dim = _dims[i].$1)),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                BrutalCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        _barBlock(i + 1, rows[i].$1, rows[i].$2, abTot, abMax),
                      ],
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

  Widget _barBlock(int pos, String label, int count, int abTot, int abMax) {
    final n = (count * _mult).round();
    final pct = abTot == 0 ? 0 : (count / abTot * 100).round();
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: '$posº  ', style: AppText.body(size: 13, weight: FontWeight.w800, color: AppColors.inkA(0.4))),
                  TextSpan(text: label, style: AppText.body(size: 13, weight: FontWeight.w700)),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text.rich(TextSpan(children: [
              TextSpan(text: '$n', style: AppText.body(size: 13, weight: FontWeight.w800)),
              TextSpan(text: ' · $pct%', style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.4))),
            ])),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 8,
            color: AppColors.duneA(0.5),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: abMax == 0 ? 0 : (count / abMax).clamp(0, 1),
              child: Container(decoration: BoxDecoration(color: AppColors.coral, borderRadius: BorderRadius.circular(999))),
            ),
          ),
        ),
      ],
    );
  }
}
