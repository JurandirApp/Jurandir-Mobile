import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/models.dart';
import '../../../core/data/public_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../../core/widgets/dark_header.dart';
import '../../../core/widgets/filter_pill.dart';
import '../../../l10n/i18n.dart';

const _dims = [('city', 'admin.dCity'), ('bairro', 'admin.dNeighborhood'), ('culinaria', 'admin.dCuisine'), ('tipo', 'admin.dType')];

class AdminBuscasScreen extends ConsumerStatefulWidget {
  const AdminBuscasScreen({super.key});

  @override
  ConsumerState<AdminBuscasScreen> createState() => _AdminBuscasScreenState();
}

class _AdminBuscasScreenState extends ConsumerState<AdminBuscasScreen> {
  String _dim = 'city';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminSearchesProvider);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          DarkHeader(eyebrow: tr('admin.platform'), title: tr('admin.tabSearches')),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.coral, strokeWidth: 3)),
              error: (_, _) => Center(
                child: GestureDetector(
                  onTap: () => ref.invalidate(adminSearchesProvider),
                  child: Text(tr('admin.loadErrorTap'),
                      style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.inkA(0.5))),
                ),
              ),
              data: (s) => _body(s),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(AdminSearches? s) {
    final rows = s?.dims[_dim] ?? const <AdminSearchRow>[];
    final abTot = rows.fold(0, (a, r) => a + r.count);
    final abMax = rows.isEmpty ? 1 : rows.first.count;
    final total = s?.total ?? 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      children: [
        Text.rich(
          TextSpan(children: [
            TextSpan(text: tr('admin.searchesPre')),
            TextSpan(text: groupThousands(total), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
            TextSpan(text: tr('admin.searchesPost')),
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
                  FilterPill(label: tr(_dims[i].$2), selected: _dims[i].$1 == _dim, onTap: () => setState(() => _dim = _dims[i].$1)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(tr('admin.noSearches'),
                  textAlign: TextAlign.center,
                  style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.inkA(0.45))),
            ),
          )
        else
          BrutalCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _barBlock(i + 1, rows[i].label, rows[i].count, abTot, abMax),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _barBlock(int pos, String label, int count, int abTot, int abMax) {
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
              TextSpan(text: '$count', style: AppText.body(size: 13, weight: FontWeight.w800)),
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
