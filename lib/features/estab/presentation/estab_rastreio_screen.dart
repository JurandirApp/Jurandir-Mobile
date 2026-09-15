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
import 'estab_sub_header.dart';

/// Estab · Conta → Rastreio: grid de mesas do dia (resumo). Tocar numa mesa
/// abre a tela dedicada dela (`/estab/conta/rastreio/mesa`), com os pedidos
/// pagos agrupados por cliente — feito pra rolar centenas de pedidos num dia
/// cheio sem estourar a tela.
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

  void _openTable(TrackedTable t) {
    context.push('/estab/conta/rastreio/mesa', extra: {'label': t.label, 'day': _dayApi(_day)}).then((_) {
      if (mounted) _load(); // volta da mesa → atualiza os contadores
    });
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
    final sub = empty
        ? 'Sem pedidos'
        : '${t.customers} ${t.customers == 1 ? 'cliente' : 'clientes'} · ${t.orderCount} ${t.orderCount == 1 ? 'pedido' : 'pedidos'} · ${_brl(t.revenue)}';
    return BrutalCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: empty ? null : () => _openTable(t),
      child: Row(
        children: [
          Icon(t.registered ? Symbols.table_restaurant : Symbols.smartphone, size: 18, color: AppColors.inkA(0.6)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.display(size: 16, letterSpacing: -0.2)),
                const SizedBox(height: 3),
                Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(size: 12.5, weight: FontWeight.w700, color: empty ? AppColors.inkA(0.4) : AppColors.successText)),
              ],
            ),
          ),
          if (!empty) Icon(Symbols.chevron_right, size: 22, color: AppColors.inkA(0.4)),
        ],
      ),
    );
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
