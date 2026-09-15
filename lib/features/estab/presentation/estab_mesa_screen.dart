import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/data/public_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../auth/auth_controller.dart';
import '../data/tracking_models.dart';

/// Tela dedicada de UMA mesa: os pedidos pagos do dia agrupados por cliente.
/// Chega via `context.push('/estab/conta/rastreio/mesa', extra: {label, day})`.
class EstabMesaScreen extends ConsumerStatefulWidget {
  const EstabMesaScreen({super.key});

  @override
  ConsumerState<EstabMesaScreen> createState() => _EstabMesaScreenState();
}

class _EstabMesaScreenState extends ConsumerState<EstabMesaScreen> {
  String _label = '';
  String _day = '';
  bool _initFromExtra = false;

  TableDetail? _detail;
  bool _loading = true;
  bool _error = false;
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initFromExtra) return;
    final extra = GoRouterState.of(context).extra;
    if (extra is Map) {
      _label = (extra['label'] as String?) ?? '';
      _day = (extra['day'] as String?) ?? '';
      _initFromExtra = true;
      _load();
    }
  }

  Future<void> _load() async {
    final token = ref.read(authProvider).token;
    if (token == null || _label.isEmpty) return;
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final d = await ref.read(publicApiProvider).establishmentTableDetail(token, _day, _label);
      if (!mounted) return;
      setState(() {
        _detail = d;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  List<TrackedClient> get _clients {
    final all = _detail?.clients ?? const <TrackedClient>[];
    final term = _q.trim().toLowerCase();
    if (term.isEmpty) return all;
    return all
        .where((c) => c.name.toLowerCase().contains(term) || c.phone.toLowerCase().contains(term))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          _header(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _header() {
    final estName = (ref.watch(authProvider).name ?? '').trim();
    final d = _detail;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 18, 20, 18),
      decoration: const BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Symbols.arrow_back, size: 16, color: AppColors.duneA(0.7)),
                const SizedBox(width: 6),
                Text('Rastreio', style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.duneA(0.7))),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text((estName.isEmpty ? 'Estabelecimento' : estName).toUpperCase(), style: AppText.eyebrow),
          const SizedBox(height: 3),
          Row(
            children: [
              Icon((d?.registered ?? true) ? Symbols.table_restaurant : Symbols.smartphone, size: 22, color: AppColors.dune),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_label.toUpperCase(),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.pageTitle.copyWith(color: AppColors.dune)),
              ),
            ],
          ),
          if (d != null && d.orderCount > 0) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _headChip(Symbols.group, '${d.customers} ${d.customers == 1 ? 'cliente' : 'clientes'}'),
                _headChip(Symbols.receipt_long, '${d.orderCount} ${d.orderCount == 1 ? 'pedido' : 'pedidos'}'),
                _headChip(Symbols.payments, _brl(d.total)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _headChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.duneA(0.12), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.duneA(0.85)),
          const SizedBox(width: 5),
          Text(text, style: AppText.body(size: 12, weight: FontWeight.w800, color: AppColors.dune)),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.coral, strokeWidth: 3));
    if (_error) {
      return Center(
        child: GestureDetector(
          onTap: _load,
          child: Text('Erro ao carregar. Toque para tentar de novo.',
              style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.inkA(0.5))),
        ),
      );
    }
    final d = _detail;
    if (d == null || d.orderCount == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Symbols.receipt_long, size: 44, color: AppColors.inkA(0.3)),
              const SizedBox(height: 12),
              Text('Sem pedidos nessa mesa hoje.',
                  style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.inkA(0.5))),
            ],
          ),
        ),
      );
    }
    final clients = _clients;
    return RefreshIndicator(
      color: AppColors.coral,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          if (d.clients.length > 1) _searchBox(),
          if (clients.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Text('Nenhum cliente encontrado.',
                    style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
              ),
            )
          else
            for (final c in clients)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _clientBlock(c),
              ),
        ],
      ),
    );
  }

  Widget _searchBox() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.inkA(0.12))),
        child: Row(
          children: [
            Icon(Symbols.search, size: 18, color: AppColors.inkA(0.4)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: (v) => setState(() => _q = v),
                style: AppText.body(size: 14, weight: FontWeight.w600),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Buscar cliente por nome ou telefone',
                  hintStyle: AppText.body(size: 14, weight: FontWeight.w500, color: AppColors.inkA(0.4)),
                ),
              ),
            ),
            if (_q.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _search.clear();
                  setState(() => _q = '');
                },
                child: Icon(Symbols.close, size: 18, color: AppColors.inkA(0.45)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _clientBlock(TrackedClient c) {
    return BrutalCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          title: Text(c.name.isEmpty ? 'Cliente' : c.name,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.display(size: 16, letterSpacing: -0.2)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            // Telefone + nº de pedidos em preto; só o valor pago em verde.
            child: Text.rich(
              TextSpan(
                style: AppText.body(size: 12.5, weight: FontWeight.w700, color: AppColors.ink),
                children: [
                  if (c.phone.isNotEmpty) TextSpan(text: '${c.phone}  ·  '),
                  TextSpan(text: '${c.orderCount} ${c.orderCount == 1 ? 'pedido' : 'pedidos'}  ·  '),
                  TextSpan(text: _brl(c.total), style: const TextStyle(color: AppColors.successText)),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          children: [for (final o in c.orders) _orderRow(o)],
        ),
      ),
    );
  }

  Widget _orderRow(TrackedClientOrder o) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.duneA(0.35), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('#${o.number}', style: AppText.body(size: 12.5, weight: FontWeight.w800, color: AppColors.inkA(0.55))),
              const Spacer(),
              Text(_brl(o.total), style: AppText.display(size: 14, letterSpacing: -0.2)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            o.items.map((i) => '${i.qty}× ${i.name}').join(', '),
            style: AppText.body(size: 12.5, weight: FontWeight.w600, color: AppColors.inkA(0.72)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip(Symbols.schedule, 'Pedido ${_hhmm(o.placedAt)}'),
              _chip(Symbols.check_circle, o.deliveredAt == null ? 'Não entregue' : 'Entregue ${_hhmm(o.deliveredAt)}'),
              if (o.waiter != null && o.waiter!.isNotEmpty) _chip(Symbols.room_service, o.waiter!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.inkA(0.55)),
          const SizedBox(width: 4),
          Text(text, style: AppText.body(size: 11, weight: FontWeight.w700, color: AppColors.inkA(0.65))),
        ],
      ),
    );
  }

  /// UTC (do backend) → horário BR "HH:MM".
  String _hhmm(DateTime? d) {
    if (d == null) return '—';
    final br = d.toUtc().subtract(const Duration(hours: 3));
    return '${br.hour.toString().padLeft(2, '0')}:${br.minute.toString().padLeft(2, '0')}';
  }
}

/// "R$ 1.234,50" (pt-BR simples, sem intl).
String _brl(double v) {
  final neg = v < 0;
  final cents = (v.abs() * 100).round();
  final reais = (cents ~/ 100).toString();
  final dec = (cents % 100).toString().padLeft(2, '0');
  final buf = StringBuffer();
  for (var i = 0; i < reais.length; i++) {
    if (i > 0 && (reais.length - i) % 3 == 0) buf.write('.');
    buf.write(reais[i]);
  }
  return '${neg ? '-' : ''}R\$ $buf,$dec';
}
