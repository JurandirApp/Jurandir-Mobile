import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/data/models.dart';
import '../../../core/data/public_api.dart';
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
];

const _methodLabel = {
  'pix': 'Pix',
  'credito': 'Crédito',
  'debito': 'Débito',
  'usdc': 'USDC',
  'split': 'Dividido',
};
const _gwRate = {'pix': 0.99, 'credito': 3.49, 'debito': 1.99};

String _relTime(int ts) {
  final min = ((DateTime.now().millisecondsSinceEpoch - ts) / 60000).floor();
  if (min < 1) return 'agora';
  return min < 60 ? 'há ${min}min' : 'há ${(min / 60).floor()}h';
}

/// Estab · Auditoria: vendas REAIS do estabelecimento logado (pra conferência).
class EstabAuditoriaScreen extends ConsumerStatefulWidget {
  const EstabAuditoriaScreen({super.key});

  @override
  ConsumerState<EstabAuditoriaScreen> createState() => _EstabAuditoriaScreenState();
}

class _EstabAuditoriaScreenState extends ConsumerState<EstabAuditoriaScreen> {
  String _method = 'todos';

  double _orderTotal(PanelOrder o) => o.items.fold(0.0, (s, l) => s + l.qty * l.price);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(establishmentOrdersProvider);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          const EstabSubHeader(title: 'Auditoria'),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.coral)),
              error: (e, _) => _error(),
              data: _list,
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(List<PanelOrder> orders) {
    // Só vendas confirmadas (pagas): em produção ou entregues.
    final sales = orders.where((o) => o.status != 'aguardando').toList();
    final rows = _method == 'todos' ? sales : sales.where((o) => o.pay == _method).toList();
    final total = rows.fold(0.0, (s, o) => s + _orderTotal(o));

    return RefreshIndicator(
      color: AppColors.coral,
      onRefresh: () async => ref.invalidate(establishmentOrdersProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        children: [
          Text('Vendas confirmadas, para conferência.',
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
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text('Nenhuma venda registrada ainda.',
                    style: AppText.body(size: 14, color: AppColors.inkA(0.45))),
              ),
            )
          else
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
    );
  }

  Widget _error() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Não foi possível carregar as vendas.',
                textAlign: TextAlign.center, style: AppText.body(size: 14, color: AppColors.inkA(0.6))),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => ref.invalidate(establishmentOrdersProvider),
              child: Text('Tentar de novo',
                  style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.coral)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(PanelOrder o) {
    final orderTotal = _orderTotal(o);
    final rate = _gwRate[o.pay] ?? 0;
    final fee = orderTotal * rate / 100;
    final rateStr = rate.toStringAsFixed(2).replaceAll('.', ',');
    return BrutalCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(o.code,
                  style: AppText.body(size: 11, weight: FontWeight.w700, color: AppColors.inkA(0.5))
                      .copyWith(fontFamily: 'monospace')),
              Text(_relTime(o.ts), style: AppText.body(size: 11, weight: FontWeight.w800)),
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
                      child: Text('${o.loc} · ${_methodLabel[o.pay] ?? o.pay}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.inkA(0.6))),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(money(orderTotal), style: AppText.body(size: 14, weight: FontWeight.w800)),
            ],
          ),
          if (rate > 0) ...[
            const SizedBox(height: 4),
            Text('Taxa gateway (est.): ${money(fee)} ($rateStr%)',
                style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.4))),
          ],
        ],
      ),
    );
  }
}
