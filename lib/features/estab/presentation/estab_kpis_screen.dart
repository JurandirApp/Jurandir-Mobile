import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/data/seed_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../../core/widgets/dark_header.dart';
import '../../../core/widgets/donut_chart.dart';
import '../../../core/widgets/segmented_control.dart';

const _payInfo = [
  ('Pix', Symbols.qr_code_2, AppColors.pix, 0.44),
  ('Crédito', Symbols.credit_card, AppColors.credit, 0.30),
  ('Débito', Symbols.account_balance_wallet, AppColors.debit, 0.14),
  ('USDC', Symbols.toll, AppColors.usdc, 0.12),
];

const _topSellers = [
  ('Caipirinha de Limão', 14),
  ('Porção de Camarão', 9),
  ('Heineken Long Neck', 8),
];

class EstabKpisScreen extends StatefulWidget {
  const EstabKpisScreen({super.key});

  @override
  State<EstabKpisScreen> createState() => _EstabKpisScreenState();
}

class _EstabKpisScreenState extends State<EstabKpisScreen> {
  int _period = 0; // 0=hoje, 1=7 dias, 2=30 dias

  double get _f => switch (_period) { 1 => 6.4, 2 => 26.0, _ => 1.0 };

  @override
  Widget build(BuildContext context) {
    final catOf = {for (final m in kMenu) m.name: m.category};
    final byCat = <String, double>{};
    for (final o in kEstabOrders.where((o) => o.status != 'aguardando')) {
      for (final i in o.items) {
        final c = catOf[i.$2] ?? 'Outros';
        byCat[c] = (byCat[c] ?? 0) + i.$1 * i.$3;
      }
    }
    final catTot = byCat.values.fold(0.0, (a, b) => a + b);
    final sortedCats = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final eFat = kEstabOrders.fold(0.0, (s, o) => s + o.total);
    final eProd = kEstabOrders.where((o) => o.status == 'producao').length;

    final stats = [
      ('Faturamento', money(eFat * _f), AppColors.coralDeep),
      ('Pedidos', (kEstabOrders.length * _f).round().toString(), AppColors.ink),
      ('Ticket médio', money(eFat / kEstabOrders.length), AppColors.oceanDeep),
      ('Em produção', eProd.toString(), AppColors.warningText),
    ];

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          const DarkHeader(eyebrow: 'Quiosque do Mar', title: 'Resumo'),
          Expanded(
            child: ListView(
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
                _h2('Vendas por categoria'),
                _donutCard(sortedCats, catTot),
                const SizedBox(height: 22),
                _h2('Vendas por método'),
                _methodCard(eFat),
                const SizedBox(height: 22),
                _h2('Mais vendidos'),
                _topCard(),
              ],
            ),
          ),
        ],
      ),
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
    final totF = tot * _f;
    final centerStr = totF >= 1000
        ? 'R\$ ${(totF / 1000).toStringAsFixed(1).replaceAll('.', ',')}k'
        : money(totF);

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
                    money(cats[i].value * _f),
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

  Widget _methodCard(double eFat) {
    return BrutalCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (var i = 0; i < _payInfo.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _methodRow(_payInfo[i], eFat),
          ],
        ],
      ),
    );
  }

  Widget _methodRow((String, IconData, Color, double) pm, double eFat) {
    final (label, icon, color, share) = pm;
    final val = money(eFat * share * _f);
    final pct = (share * 100).round();
    final w = share / 0.44;
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
              TextSpan(text: val, style: AppText.body(size: 13, weight: FontWeight.w800)),
              TextSpan(text: ' · $pct%', style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.4))),
            ])),
          ],
        ),
        const SizedBox(height: 5),
        _bar(w, color),
      ],
    );
  }

  Widget _topCard() {
    return BrutalCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (var i = 0; i < _topSellers.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _topRow(i + 1, _topSellers[i]),
          ],
        ],
      ),
    );
  }

  Widget _topRow(int pos, (String, int) row) {
    final (name, qty) = row;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text.rich(TextSpan(children: [
                TextSpan(text: '$posº  ', style: AppText.body(size: 13, weight: FontWeight.w800, color: AppColors.inkA(0.4))),
                TextSpan(text: name, style: AppText.body(size: 13, weight: FontWeight.w700)),
              ]), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            Text('${(qty * _f).round()} un', style: AppText.body(size: 13, weight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 4),
        _bar(qty / 14, AppColors.coral),
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
