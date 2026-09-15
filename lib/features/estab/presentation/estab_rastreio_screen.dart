import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/data/public_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../auth/auth_controller.dart';
import '../data/tracking_models.dart';
import 'estab_sub_header.dart';

/// Estab · Conta → Rastreio: backlog de pedidos por mesa, filtrado por dia.
/// Mostra todas as mesas cadastradas (mesmo vazias) + labels avulsos, com nº de
/// clientes, e por pedido: cliente, itens, horário do pedido e da entrega + garçom.
class EstabRastreioScreen extends ConsumerStatefulWidget {
  const EstabRastreioScreen({super.key});

  @override
  ConsumerState<EstabRastreioScreen> createState() => _EstabRastreioScreenState();
}

class _EstabRastreioScreenState extends ConsumerState<EstabRastreioScreen> {
  static const _diasSemana = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
  late DateTime _day = _brToday();
  List<TrackedTable>? _tables;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Hoje no fuso do Brasil (UTC-3) — só a data.
  static DateTime _brToday() {
    final br = DateTime.now().toUtc().subtract(const Duration(hours: 3));
    return DateTime(br.year, br.month, br.day);
  }

  String _dayApi(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool get _isToday => _dayApi(_day) == _dayApi(_brToday());

  Future<void> _load() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final t = await ref.read(publicApiProvider).establishmentTracking(token, _dayApi(_day));
      if (!mounted) return;
      setState(() {
        _tables = t;
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

  void _shiftDay(int days) {
    final next = _day.add(Duration(days: days));
    if (next.isAfter(_brToday())) return; // não deixa ir pro futuro
    setState(() => _day = next);
    _load();
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2025, 1, 1),
      lastDate: _brToday(),
    );
    if (picked == null) return;
    setState(() => _day = DateTime(picked.year, picked.month, picked.day));
    _load();
  }

  /// UTC (do backend) → horário BR "HH:MM".
  String _hhmm(DateTime? d) {
    if (d == null) return '—';
    final br = d.toUtc().subtract(const Duration(hours: 3));
    return '${br.hour.toString().padLeft(2, '0')}:${br.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          const EstabSubHeader(title: 'Rastreio'),
          _dayBar(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _dayBar() {
    final wd = _diasSemana[(_day.weekday - 1) % 7];
    final label = _isToday
        ? 'Hoje · ${_day.day.toString().padLeft(2, '0')}/${_day.month.toString().padLeft(2, '0')}'
        : '$wd · ${_day.day.toString().padLeft(2, '0')}/${_day.month.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          _arrow(Symbols.chevron_left, () => _shiftDay(-1), true),
          Expanded(
            child: GestureDetector(
              onTap: _pickDay,
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.inkA(0.12))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Symbols.calendar_month, size: 16, color: AppColors.inkA(0.6)),
                    const SizedBox(width: 8),
                    Text(label, style: AppText.body(size: 14, weight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ),
          _arrow(Symbols.chevron_right, () => _shiftDay(1), !_isToday),
        ],
      ),
    );
  }

  Widget _arrow(IconData icon, VoidCallback onTap, bool enabled) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: enabled ? AppColors.ink : AppColors.inkA(0.15), width: 1.5),
        ),
        child: Icon(icon, size: 20, color: enabled ? AppColors.ink : AppColors.inkA(0.25)),
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
    final tables = _tables ?? const <TrackedTable>[];
    if (tables.isEmpty) {
      return Center(
        child: Text('Nenhuma mesa cadastrada ainda.',
            style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
      );
    }
    return RefreshIndicator(
      color: AppColors.coral,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: tables.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _tableCard(tables[i]),
        ),
      ),
    );
  }

  Widget _tableCard(TrackedTable t) {
    final empty = t.orderCount == 0;
    return BrutalCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          title: Row(
            children: [
              Icon(t.registered ? Symbols.table_restaurant : Symbols.smartphone, size: 18, color: AppColors.inkA(0.6)),
              const SizedBox(width: 8),
              Expanded(child: Text(t.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.display(size: 16, letterSpacing: -0.2))),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              empty ? 'Sem pedidos' : '${t.customers} ${t.customers == 1 ? 'cliente' : 'clientes'} · ${t.orderCount} ${t.orderCount == 1 ? 'pedido' : 'pedidos'}',
              style: AppText.body(size: 12.5, weight: FontWeight.w700, color: empty ? AppColors.inkA(0.4) : AppColors.successText),
            ),
          ),
          // Sem pedidos → não expande (nada dentro).
          trailing: empty ? const SizedBox(width: 1, height: 1) : null,
          enabled: !empty,
          children: [for (final o in t.orders) _orderRow(o)],
        ),
      ),
    );
  }

  Widget _orderRow(TrackedOrder o) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.duneA(0.35), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Symbols.person, size: 15, color: AppColors.inkA(0.55)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  [o.customerName.isEmpty ? 'Cliente' : o.customerName, if (o.customerPhone.isNotEmpty) o.customerPhone].join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(size: 13, weight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            o.items.map((i) => '${i.qty}× ${i.name}').join(', '),
            style: AppText.body(size: 12.5, weight: FontWeight.w600, color: AppColors.inkA(0.7)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _chip(Symbols.schedule, 'Pedido ${_hhmm(o.placedAt)}'),
              const SizedBox(width: 6),
              _chip(Symbols.check_circle, o.deliveredAt == null ? 'Não entregue' : 'Entregue ${_hhmm(o.deliveredAt)}'),
              if (o.waiter != null && o.waiter!.isNotEmpty) ...[
                const SizedBox(width: 6),
                _chip(Symbols.room_service, o.waiter!),
              ],
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
}
