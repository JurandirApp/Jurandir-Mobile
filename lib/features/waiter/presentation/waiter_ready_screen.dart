import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/data/public_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../../core/widgets/dark_header.dart';
import '../../auth/auth_controller.dart';
import '../data/waiter_models.dart';

/// Tela do garçom: itens prontos para retirada (bar/cozinha concluiu).
/// Faz polling a cada ~4s (mesmo padrão de `pix_screen.dart`) e, ao pegar,
/// abre automaticamente a confirmação de entrega (`/waiter/deliver`).
///
/// Pensada pra uso com uma mão só: cards grandes, botão PEGAR de largura
/// cheia com alvo de toque generoso, stepper opcional só quando há mais de
/// 1 unidade pronta.
class WaiterReadyScreen extends ConsumerStatefulWidget {
  const WaiterReadyScreen({super.key});

  @override
  ConsumerState<WaiterReadyScreen> createState() => _WaiterReadyScreenState();
}

class _WaiterReadyScreenState extends ConsumerState<WaiterReadyScreen> {
  Timer? _poll;
  List<ReadyItem>? _items; // null = ainda carregando (primeira vez)
  bool _error = false;
  final Set<String> _busy = {}; // orderItemIds sendo pegos agora
  final Map<String, int> _qtyN = {}; // stepper local por orderItemId

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    try {
      final items = await ref.read(publicApiProvider).waiterReady(token);
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = false;
        // Realinha steppers ao novo teto (a lista pode ter mudado entre polls).
        _qtyN.removeWhere((id, _) => items.every((i) => i.orderItemId != id));
        for (final i in items) {
          final n = _qtyN[i.orderItemId];
          if (n != null && n > i.qtyReady) _qtyN[i.orderItemId] = i.qtyReady;
        }
      });
    } catch (_) {
      if (!mounted) return;
      // Erro silencioso durante o polling — só mostra estado de erro se ainda
      // não tínhamos nada carregado.
      if (!silent || _items == null) setState(() => _error = true);
    }
  }

  void _toast(String msg, {Color bg = AppColors.ink, Color fg = AppColors.dune}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: bg,
        content: Text(msg, style: AppText.body(size: 13, weight: FontWeight.w600, color: fg)),
      ));
  }

  /// Pega `qty` unidades de `item`. Em sucesso, abre a confirmação de
  /// entrega automaticamente; em `false` (outro garçom já pegou) ou falha,
  /// avisa e recarrega a lista.
  Future<void> _pick(ReadyItem item, int qty) async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    setState(() => _busy.add(item.orderItemId));
    bool ok;
    try {
      ok = await ref.read(publicApiProvider).waiterPick(token, item.orderItemId, qty);
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _busy.remove(item.orderItemId));
    if (ok) {
      _qtyN.remove(item.orderItemId);
      context.push('/waiter/deliver', extra: <String, dynamic>{
        'orderItemId': item.orderItemId,
        'name': item.name,
        'mesa': item.mesa,
        'cliente': item.cliente,
        'qty': qty,
      });
      _load(silent: true);
    } else {
      _toast('Outro garçom já pegou', bg: AppColors.danger, fg: Colors.white);
      _load(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          const DarkHeader(eyebrow: 'Garçom', title: 'Prontos p/ retirada'),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    final items = _items;
    if (items == null && !_error) {
      return const Center(child: CircularProgressIndicator(color: AppColors.coral, strokeWidth: 3));
    }
    if (_error && (items == null || items.isEmpty)) {
      return _errorState();
    }
    final list = items ?? const <ReadyItem>[];
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Symbols.task_alt, size: 44, color: AppColors.inkA(0.35)),
              const SizedBox(height: 12),
              Text('Nenhum pedido pronto agora',
                  style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.inkA(0.5))),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.coral,
      onRefresh: () => _load(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        itemCount: list.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _readyCard(list[i]),
        ),
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
            Text('Não foi possível carregar os pedidos prontos.',
                textAlign: TextAlign.center,
                style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => _load(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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

  Widget _readyCard(ReadyItem item) {
    final max = item.qtyReady <= 0 ? 1 : item.qtyReady;
    final n = (_qtyN[item.orderItemId] ?? max).clamp(1, max);
    final busy = _busy.contains(item.orderItemId);
    return BrutalCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$n× ${item.name}', style: AppText.display(size: 22, letterSpacing: -0.4)),
          const SizedBox(height: 10),
          _infoRow(Symbols.table_restaurant, 'Mesa ${item.mesa}'),
          const SizedBox(height: 4),
          _infoRow(Symbols.person, item.cliente),
          if (max > 1) ...[
            const SizedBox(height: 14),
            _stepperRow(item, n, max, busy),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: Material(
              color: busy ? AppColors.coral.withValues(alpha: 0.6) : AppColors.coral,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: busy ? null : () => _pick(item, n),
                child: Center(
                  child: busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Symbols.back_hand, size: 20, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              'PEGAR PEDIDO',
                              style: AppText.body(
                                  size: 16, weight: FontWeight.w800, color: Colors.white, letterSpacing: 0.3),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.inkA(0.5)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.body(size: 14, weight: FontWeight.w600, color: AppColors.inkA(0.65)),
          ),
        ),
      ],
    );
  }

  Widget _stepperRow(ReadyItem item, int n, int max, bool busy) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: AppColors.duneA(0.5), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: Text('Quantidade a pegar',
                style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.inkA(0.55))),
          ),
          _stepBtn(Symbols.remove, busy || n <= 1 ? null : () => setState(() => _qtyN[item.orderItemId] = n - 1)),
          SizedBox(
            width: 30,
            child: Text('$n', textAlign: TextAlign.center, style: AppText.display(size: 16)),
          ),
          _stepBtn(Symbols.add, busy || n >= max ? null : () => setState(() => _qtyN[item.orderItemId] = n + 1)),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: enabled ? AppColors.ink : AppColors.inkA(0.2), width: 1.5),
        ),
        child: Icon(icon, size: 18, color: enabled ? AppColors.ink : AppColors.inkA(0.25)),
      ),
    );
  }
}
