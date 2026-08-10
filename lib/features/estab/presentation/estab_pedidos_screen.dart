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
import '../../../core/widgets/status_badge.dart';
import '../../auth/auth_controller.dart';

const _filters = [
  ('todos', 'Todos'),
  ('aguardando', 'Aguardando'),
  ('producao', 'Produção'),
  ('entregue', 'Entregues'),
];

String _relTime(int min) =>
    min < 1 ? 'agora' : (min < 60 ? 'há ${min}min' : 'há ${(min / 60).floor()}h');

/// Pedidos reais do estabelecimento logado. Puxe pra baixo pra atualizar.
class EstabPedidosScreen extends ConsumerStatefulWidget {
  const EstabPedidosScreen({super.key});

  @override
  ConsumerState<EstabPedidosScreen> createState() => _EstabPedidosScreenState();
}

class _EstabPedidosScreenState extends ConsumerState<EstabPedidosScreen> {
  String _filter = 'todos';
  final Set<String> _busy = {}; // dbIds sendo entregues

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        content: Text(msg, style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.dune)),
      ));
  }

  Future<void> _deliver(PanelOrder o) async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    setState(() => _busy.add(o.dbId));
    try {
      await ref.read(publicApiProvider).deliverEstablishmentOrder(token, o.dbId);
      ref.invalidate(establishmentOrdersProvider);
      _toast('Pedido ${o.code} marcado como entregue');
    } catch (_) {
      _toast('Não foi possível concluir agora');
    } finally {
      if (mounted) setState(() => _busy.remove(o.dbId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(establishmentOrdersProvider);
    final estName = ref.watch(authProvider).name ?? 'Estabelecimento';

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          DarkHeader(eyebrow: estName, title: 'Pedidos'),
          Expanded(
            child: async.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.coral, strokeWidth: 3),
              ),
              error: (_, _) => _errorState(),
              data: _body,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.cloud_off, size: 40, color: AppColors.inkA(0.4)),
            const SizedBox(height: 12),
            Text('Não foi possível carregar os pedidos.',
                textAlign: TextAlign.center,
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
  }

  Widget _body(List<PanelOrder> orders) {
    int countOf(String f) =>
        f == 'todos' ? orders.length : orders.where((o) => o.status == f).length;
    final list =
        _filter == 'todos' ? orders : orders.where((o) => o.status == _filter).toList();

    return RefreshIndicator(
      color: AppColors.coral,
      onRefresh: () async => ref.invalidate(establishmentOrdersProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        children: [
          SizedBox(
            height: 38,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < _filters.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    _filterPill(_filters[i].$1, _filters[i].$2, countOf(_filters[i].$1)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (orders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text('Nenhum pedido ainda.',
                    style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.inkA(0.45))),
              ),
            )
          else if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text('Nenhum pedido neste status.',
                    style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.inkA(0.45))),
              ),
            ),
          for (final o in list)
            Padding(padding: const EdgeInsets.only(bottom: 12), child: _orderCard(o)),
        ],
      ),
    );
  }

  Widget _filterPill(String id, String label, int count) {
    final active = _filter == id;
    final fg = active ? AppColors.dune : AppColors.ink;
    return GestureDetector(
      onTap: () => setState(() => _filter = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.ink : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.ink, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: AppText.body(size: 12, weight: FontWeight.w800, color: fg)),
            const SizedBox(width: 5),
            Text('$count', style: AppText.body(size: 12, weight: FontWeight.w800, color: fg.withValues(alpha: 0.55))),
          ],
        ),
      ),
    );
  }

  Widget _orderCard(PanelOrder o) {
    final status = o.status;
    final (label, tone) = switch (status) {
      'aguardando' => ('Aguardando', BadgeTone.pending),
      'producao' => ('Em produção', BadgeTone.production),
      _ => ('Entregue', BadgeTone.done),
    };
    final showSplit = status == 'aguardando' && o.split != null;
    final busy = _busy.contains(o.dbId);

    return BrutalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Pedido #${o.id.toString().padLeft(3, '0')}',
                  style: AppText.display(size: 14, weight: FontWeight.w700, letterSpacing: 0)),
              StatusBadge(label, tone: tone),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Symbols.location_on, size: 12, color: AppColors.coral),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${o.loc} · ${_relTime(o.minutesAgo)}${o.cust != null ? ' · ${o.cust}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.5)),
                ),
              ),
            ],
          ),
          if (o.note != null && o.note!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Symbols.chat, size: 13, color: Color(0xFF92400E)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(o.note!,
                        style: AppText.body(size: 11, weight: FontWeight.w600, color: const Color(0xFF92400E))),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          for (final i in o.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${i.qty}× ${i.name}', style: AppText.body(size: 13)),
                  Text(money(i.qty * i.price), style: AppText.body(size: 13, color: AppColors.inkA(0.5))),
                ],
              ),
            ),
          if (showSplit) _splitBlock(o),
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.inkA(0.08)))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(money(o.total),
                    style: AppText.body(
                        size: 14,
                        weight: FontWeight.w800,
                        color: status == 'aguardando' ? AppColors.dangerText : AppColors.ink)),
                Row(
                  children: [
                    if (status != 'entregue')
                      GestureDetector(
                        onTap: () => _toast('Impressão é enviada pelo agente local (em breve).'),
                        child: Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: AppColors.duneA(0.5), shape: BoxShape.circle),
                          child: Icon(Symbols.print, size: 16, color: AppColors.inkA(0.7)),
                        ),
                      ),
                    if (status == 'producao') ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: busy ? null : () => _deliver(o),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: busy ? AppColors.success.withValues(alpha: 0.6) : AppColors.success,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: busy
                              ? const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Symbols.check, size: 14, color: Colors.white),
                                    const SizedBox(width: 5),
                                    Text('Entregue',
                                        style: AppText.body(size: 12, weight: FontWeight.w800, color: Colors.white)),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _splitBlock(PanelOrder o) {
    final people = o.split!.people;
    final paid = o.split!.paid;
    final share = people == 0 ? 0.0 : o.total / people;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$paid de $people pagaram',
                  style: AppText.body(size: 11, weight: FontWeight.w700, color: AppColors.dangerText)),
              Text('${money(paid * share)} de ${money(o.total)}',
                  style: AppText.body(size: 11, weight: FontWeight.w700, color: AppColors.dangerText)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: people == 0 ? 0 : paid / people,
              minHeight: 6,
              backgroundColor: AppColors.dangerBg,
              valueColor: const AlwaysStoppedAnimation(AppColors.rose),
            ),
          ),
          const SizedBox(height: 5),
          Text('Não vai à cozinha até o pagamento ser concluído.',
              style: AppText.body(size: 10, weight: FontWeight.w600, color: AppColors.danger)),
        ],
      ),
    );
  }
}
