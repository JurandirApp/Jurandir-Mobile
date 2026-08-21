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
import '../../../core/widgets/filter_pill.dart';

const _mFilters = [
  ('todos', 'Todos'),
  ('pix', 'Pix'),
  ('credito', 'Crédito'),
  ('debito', 'Débito'),
  ('usdc', 'USDC'),
  ('split', 'Dividido'),
];

const _mLbl = {'pix': 'Pix', 'credito': 'Crédito', 'debito': 'Débito', 'usdc': 'USDC', 'split': 'Dividido'};

String _relTime(int ts) {
  final min = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts)).inMinutes;
  if (min < 1) return 'agora';
  return min < 60 ? 'há ${min}min' : 'há ${(min / 60).floor()}h';
}

class AdminBacklogScreen extends ConsumerStatefulWidget {
  const AdminBacklogScreen({super.key});

  @override
  ConsumerState<AdminBacklogScreen> createState() => _AdminBacklogScreenState();
}

class _AdminBacklogScreenState extends ConsumerState<AdminBacklogScreen> {
  String _method = 'todos';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminOverviewProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          const DarkHeader(eyebrow: 'Plataforma', title: 'Backlog'),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.coral, strokeWidth: 3)),
              error: (_, _) => _error(),
              data: (ov) => _body(ov?.backlog ?? const <AdminBacklogOrder>[]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _error() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Symbols.cloud_off, size: 40, color: AppColors.inkA(0.4)),
              const SizedBox(height: 12),
              Text('Não foi possível carregar o backlog.',
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

  Widget _body(List<AdminBacklogOrder> all) {
    final rows = _method == 'todos' ? all : all.where((r) => r.method == _method).toList();
    final total = rows.fold(0.0, (s, r) => s + r.total);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      children: [
        Text('Compras de toda a plataforma. Cartão sempre mascarado.',
            style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
        const SizedBox(height: 14),
        SizedBox(
          height: 38,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < _mFilters.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  FilterPill(
                    label: _mFilters[i].$2,
                    selected: _mFilters[i].$1 == _method,
                    onTap: () => setState(() => _method = _mFilters[i].$1),
                  ),
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
              child: Text('Nenhuma compra neste filtro.',
                  style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.inkA(0.45))),
            ),
          )
        else ...[
          for (final r in rows) ...[_row(r), const SizedBox(height: 10)],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total (${rows.length} compra${rows.length == 1 ? '' : 's'})',
                    style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.dune)),
                Text(money(total), style: AppText.display(size: 16, letterSpacing: 0, color: AppColors.dune)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _row(AdminBacklogOrder r) {
    final meta = '${r.city} · ${_relTime(r.ts)} · ${_mLbl[r.method] ?? r.method}${r.card.isNotEmpty ? ' · ${r.card}' : ''}';
    return BrutalCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(r.estab,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.display(size: 13, weight: FontWeight.w700, letterSpacing: 0)),
              ),
              const SizedBox(width: 8),
              Text(money(r.total), style: AppText.body(size: 14, weight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Symbols.location_on, size: 12, color: AppColors.coral),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(meta, style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
              ),
            ],
          ),
          if (r.items.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(r.items, style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.inkA(0.65))),
          ],
          const SizedBox(height: 6),
          Text(r.code,
              style: AppText.body(size: 10, weight: FontWeight.w700, color: AppColors.inkA(0.35)).copyWith(fontFamily: 'monospace')),
        ],
      ),
    );
  }
}
