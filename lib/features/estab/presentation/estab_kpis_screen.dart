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
import '../../../core/widgets/donut_chart.dart';
import '../../../core/widgets/segmented_control.dart';
import '../../auth/auth_controller.dart';

const _payMeta = [
  ('pix', 'Pix', Symbols.qr_code_2, AppColors.pix),
  ('credito', 'Crédito', Symbols.credit_card, AppColors.credit),
  ('debito', 'Débito', Symbols.account_balance_wallet, AppColors.debit),
];

/// Estab · Resumo (KPIs) com dados reais: calcula faturamento, categorias,
/// método e mais vendidos a partir dos pedidos do estabelecimento.
class EstabKpisScreen extends ConsumerStatefulWidget {
  const EstabKpisScreen({super.key});

  @override
  ConsumerState<EstabKpisScreen> createState() => _EstabKpisScreenState();
}

class _EstabKpisScreenState extends ConsumerState<EstabKpisScreen> {
  int _period = 0; // 0=hoje, 1=7 dias, 2=30 dias

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(establishmentOrdersProvider);
    final menu = ref.watch(establishmentMenuProvider).asData?.value ?? const <PanelMenuItem>[];
    final estName = ref.watch(authProvider).name ?? 'Estabelecimento';

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          DarkHeader(eyebrow: estName, title: 'Resumo'),
          Expanded(
            child: ordersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.coral, strokeWidth: 3)),
              error: (_, _) => _errorState(),
              data: (orders) => _content(orders, menu),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Symbols.cloud_off, size: 40, color: AppColors.inkA(0.4)),
              const SizedBox(height: 12),
              Text('Não foi possível carregar o resumo.',
                  style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => ref.invalidate(establishmentOrdersProvider),
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

  Widget _content(List<PanelOrder> all, List<PanelMenuItem> menu) {
    final now = DateTime.now();
    final cutoffMs = switch (_period) {
      0 => DateTime(now.year, now.month, now.day).millisecondsSinceEpoch,
      1 => now.subtract(const Duration(days: 7)).millisecondsSinceEpoch,
      _ => now.subtract(const Duration(days: 30)).millisecondsSinceEpoch,
    };
    final orders = all.where((o) => o.ts >= cutoffMs).toList();

    final faturamento = orders.fold(0.0, (s, o) => s + o.total);
    final pedidos = orders.length;
    final ticket = pedidos == 0 ? 0.0 : faturamento / pedidos;
    final emProducao = all.where((o) => o.status == 'producao').length;

    // vendas por categoria (usa o cardápio p/ mapear nome → categoria).
    // Usa os MESMOS pedidos do faturamento/método pra não dar divergência
    // (ex.: método mostra Pix R$24 mas categoria zerada).
    final catOf = {for (final m in menu) m.name: m.cat};
    final byCat = <String, double>{};
    for (final o in orders) {
      for (final it in o.items) {
        var c = catOf[it.name] ?? 'Outros';
        if (c.isEmpty) c = 'Outros';
        byCat[c] = (byCat[c] ?? 0) + it.qty * it.price;
      }
    }
    final catTot = byCat.values.fold(0.0, (a, b) => a + b);
    final sortedCats = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    // vendas por método
    final byPay = <String, double>{};
    for (final o in orders) {
      byPay[o.pay] = (byPay[o.pay] ?? 0) + o.total;
    }

    // mais vendidos (por quantidade) — mesmo conjunto de pedidos
    final byItem = <String, int>{};
    for (final o in orders) {
      for (final it in o.items) {
        byItem[it.name] = (byItem[it.name] ?? 0) + it.qty;
      }
    }
    final topSellers = (byItem.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(3).toList();

    final stats = [
      ('Faturamento', money(faturamento), AppColors.coralDeep),
      ('Pedidos', pedidos.toString(), AppColors.ink),
      ('Ticket médio', money(ticket), AppColors.oceanDeep),
      ('Em produção', emProducao.toString(), AppColors.warningText),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      children: [
        SegmentedControl(
          segments: const ['Hoje', '7 dias', '30 dias'],
          selected: _period,
          onChanged: (i) => setState(() => _period = i),
        ),
        const SizedBox(height: 14),
        Row(children: [Expanded(child: _statCard(stats[0])), const SizedBox(width: 10), Expanded(child: _statCard(stats[1]))]),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: _statCard(stats[2])), const SizedBox(width: 10), Expanded(child: _statCard(stats[3]))]),
        const SizedBox(height: 22),
        if (pedidos == 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text('Sem pedidos neste período.',
                  style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.inkA(0.45))),
            ),
          )
        else ...[
          _h2('Vendas por categoria'),
          _donutCard(sortedCats, catTot),
          const SizedBox(height: 22),
          _h2('Vendas por método'),
          _methodCard(byPay, faturamento),
          const SizedBox(height: 22),
          _h2('Mais vendidos'),
          _topCard(topSellers),
        ],
      ],
    );
  }

  Widget _h2(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text.toUpperCase(), style: AppText.sectionTitle),
      );

  Widget _statCard((String, String, Color) s) {
    return BrutalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.$1, style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
          const SizedBox(height: 5),
          Text(s.$2, style: AppText.display(size: 20, height: 1, color: s.$3)),
        ],
      ),
    );
  }

  Widget _donutCard(List<MapEntry<String, double>> cats, double tot) {
    final centerStr = tot >= 1000
        ? 'R\$ ${(tot / 1000).toStringAsFixed(1).replaceAll('.', ',')}k'
        : money(tot);

    return BrutalCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          DonutChart(
            segments: [
              for (var i = 0; i < cats.length; i++)
                (AppColors.chart[i % AppColors.chart.length], tot == 0 ? 0.0 : cats[i].value / tot),
            ],
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Vendas',
                    style: AppText.body(size: 8, weight: FontWeight.w700, letterSpacing: 0.4, color: AppColors.inkA(0.45))),
                Text(centerStr, style: AppText.display(size: 12, height: 1.1)),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              children: [
                for (var i = 0; i < cats.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _legendRow(
                    AppColors.chart[i % AppColors.chart.length],
                    cats[i].key,
                    tot == 0 ? 0 : (cats[i].value / tot * 100).round(),
                    money(cats[i].value),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendRow(Color color, String label, int pct, String val) {
    return Row(
      children: [
        Container(width: 11, height: 11, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 7),
        Expanded(
          child: Text(label,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 12, weight: FontWeight.w700)),
        ),
        const SizedBox(width: 8),
        Text('$pct%', style: AppText.body(size: 12, weight: FontWeight.w800)),
        const SizedBox(width: 4),
        Text('· $val', style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.4))),
      ],
    );
  }

  Widget _methodCard(Map<String, double> byPay, double total) {
    final maxV = byPay.values.isEmpty ? 0.0 : byPay.values.reduce((a, b) => a > b ? a : b);
    return BrutalCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (var i = 0; i < _payMeta.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _methodRow(_payMeta[i], byPay[_payMeta[i].$1] ?? 0, total, maxV),
          ],
        ],
      ),
    );
  }

  Widget _methodRow((String, String, IconData, Color) pm, double value, double total, double maxV) {
    final (_, label, icon, color) = pm;
    final pct = total == 0 ? 0 : (value / total * 100).round();
    final w = maxV == 0 ? 0.0 : value / maxV;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: AppColors.ink, width: 2),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 8),
                Text(label, style: AppText.body(size: 13, weight: FontWeight.w700)),
              ],
            ),
            Text.rich(TextSpan(children: [
              TextSpan(text: money(value), style: AppText.body(size: 13, weight: FontWeight.w800)),
              TextSpan(text: ' · $pct%', style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.4))),
            ])),
          ],
        ),
        const SizedBox(height: 5),
        _bar(w, color),
      ],
    );
  }

  Widget _topCard(List<MapEntry<String, int>> top) {
    final maxQty = top.isEmpty ? 1 : top.first.value;
    return BrutalCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (var i = 0; i < top.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _topRow(i + 1, top[i], maxQty),
          ],
        ],
      ),
    );
  }

  Widget _topRow(int pos, MapEntry<String, int> row, int maxQty) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text.rich(TextSpan(children: [
                TextSpan(text: '$posº  ', style: AppText.body(size: 13, weight: FontWeight.w800, color: AppColors.inkA(0.4))),
                TextSpan(text: row.key, style: AppText.body(size: 13, weight: FontWeight.w700)),
              ]), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            Text('${row.value} un', style: AppText.body(size: 13, weight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 4),
        _bar(maxQty == 0 ? 0 : row.value / maxQty, AppColors.coral),
      ],
    );
  }

  Widget _bar(double frac, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 8,
        color: AppColors.duneA(0.5),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: frac.clamp(0, 1),
          child: Container(
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
          ),
        ),
      ),
    );
  }
}
