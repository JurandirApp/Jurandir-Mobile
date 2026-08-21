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
import '../../../core/widgets/filter_pill.dart';

const _payMeta = [
  ('credito', 'Crédito', Color(0xFF3B82F6)),
  ('debito', 'Débito', Color(0xFF10B981)),
  ('pix', 'Pix', Color(0xFF14B8A6)),
  ('usdc', 'USDC', Color(0xFF0E565B)),
];

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  String _scope = ''; // '' = todos

  String _short(double v) => v >= 1000 ? 'R\$ ${(v / 1000).round()}k' : money(v);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminOverviewProvider);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          const DarkHeader(eyebrow: 'Plataforma', title: 'Dashboard'),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.coral, strokeWidth: 3)),
              error: (_, _) => _error(),
              data: (ov) => ov == null || ov.establishments.isEmpty
                  ? Center(
                      child: Text('Sem dados ainda.',
                          style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.inkA(0.45))),
                    )
                  : _content(ov),
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
              Text('Não foi possível carregar o dashboard.',
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

  Widget _content(AdminOverview ov) {
    final scoped = _scope.isEmpty ? ov.establishments : ov.establishments.where((e) => e.id == _scope).toList();
    final gmv = scoped.fold(0.0, (s, e) => s + e.gmv);
    final fees = scoped.fold(0.0, (s, e) => s + e.fees);
    final ped = scoped.fold(0, (s, e) => s + e.orders);
    final feeAvg = scoped.isEmpty ? 0.0 : scoped.fold(0.0, (s, e) => s + e.feePct) / scoped.length;

    // quebra por método (nível plataforma)
    final payTotal = _payMeta.fold(0.0, (s, m) => s + (ov.byPayment[m.$1] ?? 0));
    final usdcPct = payTotal == 0 ? 0.0 : (ov.byPayment['usdc'] ?? 0) / payTotal * 100;

    final stats = <(String, String, Color, String?)>[
      ('GMV da plataforma', money(gmv), AppColors.ink, 'faturamento somado dos clientes'),
      ('Receita de fees', money(fees), AppColors.successText, 'o que o Jurandir fatura'),
      ('Pedidos totais', groupThousands(ped), AppColors.ink, null),
      ('Ticket médio', money(ped > 0 ? gmv / ped : 0), AppColors.ink, null),
      ('Estabelecimentos', '${scoped.length}', AppColors.ink, '${scoped.where((e) => e.active).length} ativo(s)'),
      ('% via USDC', '${usdcPct.toStringAsFixed(1).replaceAll('.', ',')}%', const Color(0xFF0E565B), 'movimento em stablecoin'),
      ('Fee médio', '${feeAvg.toStringAsFixed(1).replaceAll('.', ',')}%', AppColors.ink, null),
      ('GMV/estab.', money(scoped.isEmpty ? 0 : gmv / scoped.length), AppColors.ink, null),
    ];

    // por tipo
    final typeNames = <String>{for (final e in scoped) e.type};
    final types = typeNames.map((t) {
      final g = scoped.where((e) => e.type == t).toList();
      return (tipo: t, count: g.length, rev: g.fold(0.0, (s, e) => s + e.gmv), po: g.fold(0, (s, e) => s + e.orders));
    }).toList()
      ..sort((a, b) => b.rev.compareTo(a.rev));
    final tRev = types.fold(0.0, (s, g) => s + g.rev);
    final tOrd = types.fold(0, (s, g) => s + g.po);

    // top
    final top = [...scoped]..sort((a, b) => b.gmv.compareTo(a.gmv));
    final top5 = top.take(5).toList();
    final topMax = top5.isEmpty ? 1.0 : (top5.first.gmv == 0 ? 1.0 : top5.first.gmv);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      children: [
        SizedBox(
          height: 38,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _scopePill('', 'Todos os estabelecimentos'),
                for (final e in ov.establishments) ...[
                  const SizedBox(width: 8),
                  _scopePill(e.id, e.name),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (var r = 0; r < stats.length; r += 2) ...[
          if (r > 0) const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _statCard(stats[r])),
              const SizedBox(width: 10),
              Expanded(child: _statCard(stats[r + 1])),
            ],
          ),
        ],
        const SizedBox(height: 22),
        _h2('Movimento por método'),
        _donutCard(ov.byPayment, payTotal),
        const SizedBox(height: 22),
        _h2('Por tipo de estabelecimento'),
        _typesCard(types, tRev == 0 ? 1 : tRev, tOrd == 0 ? 1 : tOrd),
        const SizedBox(height: 22),
        _h2('Top estabelecimentos'),
        _topCard(top5, topMax),
      ],
    );
  }

  Widget _h2(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text.toUpperCase(), style: AppText.sectionTitle),
      );

  Widget _scopePill(String id, String label) {
    return FilterPill(
      label: label,
      selected: _scope == id,
      icon: Symbols.storefront,
      onTap: () => setState(() => _scope = id),
    );
  }

  Widget _statCard((String, String, Color, String?) s) {
    return BrutalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.$1, style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
          const SizedBox(height: 5),
          Text(s.$2, style: AppText.display(size: 19, height: 1, color: s.$3)),
          if (s.$4 != null) ...[
            const SizedBox(height: 4),
            Text(s.$4!, style: AppText.body(size: 9, weight: FontWeight.w600, color: AppColors.inkA(0.45))),
          ],
        ],
      ),
    );
  }

  Widget _donutCard(Map<String, double> byPayment, double payTotal) {
    return BrutalCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          DonutChart(
            size: 104,
            segments: [
              for (final (key, _, color) in _payMeta) (color, payTotal == 0 ? 0.0 : (byPayment[key] ?? 0) / payTotal),
            ],
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('GMV', style: AppText.body(size: 8, weight: FontWeight.w700, letterSpacing: 0.4, color: AppColors.inkA(0.45))),
                Text(_short(payTotal), style: AppText.display(size: 12, height: 1.1)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                for (var i = 0; i < _payMeta.length; i++) ...[
                  if (i > 0) const SizedBox(height: 9),
                  _methodBar(_payMeta[i], byPayment[_payMeta[i].$1] ?? 0, payTotal),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _methodBar((String, String, Color) meta, double value, double payTotal) {
    final (_, label, color) = meta;
    final share = payTotal == 0 ? 0.0 : value / payTotal;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Container(width: 9, height: 9, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 5),
              Text(label, style: AppText.body(size: 11, weight: FontWeight.w700)),
            ]),
            Text.rich(TextSpan(children: [
              TextSpan(text: money(value), style: AppText.body(size: 11, weight: FontWeight.w700)),
              TextSpan(text: ' · ${(share * 100).round()}%', style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.4))),
            ])),
          ],
        ),
        const SizedBox(height: 3),
        _bar(share, color, track: AppColors.inkA(0.08), height: 6),
      ],
    );
  }

  Widget _typesCard(List<({int count, int po, double rev, String tipo})> types, double tRev, int tOrd) {
    return BrutalCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (var i = 0; i < types.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _typeBlock(types[i], tRev, tOrd),
          ],
        ],
      ),
    );
  }

  Widget _typeBlock(({int count, int po, double rev, String tipo}) g, double tRev, int tOrd) {
    final ticket = g.po > 0 ? g.rev / g.po : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(g.tipo, style: AppText.display(size: 13, weight: FontWeight.w700, letterSpacing: 0)),
            Text.rich(TextSpan(children: [
              const TextSpan(text: 'Ticket '),
              TextSpan(text: money(ticket), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
              TextSpan(text: ' · ${g.count} ${g.count == 1 ? 'estab.' : 'estabs.'}'),
            ]), style: AppText.body(size: 10, weight: FontWeight.w600, color: AppColors.inkA(0.45))),
          ],
        ),
        const SizedBox(height: 5),
        _typeBarRow('Fatur.', tRev == 0 ? 0 : g.rev / tRev, money(g.rev), AppColors.coral),
        const SizedBox(height: 3),
        _typeBarRow('Vendas', tOrd == 0 ? 0 : g.po / tOrd, groupThousands(g.po), AppColors.oceanDeep),
      ],
    );
  }

  Widget _typeBarRow(String label, double frac, String value, Color color) {
    return Row(
      children: [
        SizedBox(width: 52, child: Text(label.toUpperCase(), style: AppText.body(size: 9, weight: FontWeight.w700, color: AppColors.inkA(0.45)))),
        const SizedBox(width: 7),
        Expanded(child: _bar(frac, color, track: AppColors.inkA(0.08), height: 6)),
        const SizedBox(width: 7),
        SizedBox(
          width: 66,
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: '${(frac * 100).round()}% ', style: AppText.body(size: 10, weight: FontWeight.w700)),
              TextSpan(text: value, style: AppText.body(size: 10, weight: FontWeight.w600, color: AppColors.inkA(0.35))),
            ]),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _topCard(List<AdminEstablishment> top, double topMax) {
    return BrutalCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (var i = 0; i < top.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _topRow(i + 1, top[i], topMax),
          ],
        ],
      ),
    );
  }

  Widget _topRow(int pos, AdminEstablishment e, double topMax) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: '$posº  ', style: AppText.body(size: 13, weight: FontWeight.w800, color: AppColors.inkA(0.4))),
                  TextSpan(text: e.name, style: AppText.body(size: 13, weight: FontWeight.w700)),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text.rich(TextSpan(children: [
              TextSpan(text: money(e.gmv), style: AppText.body(size: 13, weight: FontWeight.w800)),
              TextSpan(text: ' · fee ${money(e.fees)}', style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.4))),
            ])),
          ],
        ),
        const SizedBox(height: 4),
        _bar(topMax == 0 ? 0 : e.gmv / topMax, AppColors.coral, track: AppColors.duneA(0.5), height: 8),
      ],
    );
  }

  Widget _bar(double frac, Color color, {required Color track, required double height}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: height,
        color: track,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: frac.clamp(0, 1),
          child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999))),
        ),
      ),
    );
  }
}
