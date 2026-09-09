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

/// Tela do garçom: fila de trabalho em duas seções —
///  • **Prontos p/ retirada** (bar/cozinha concluiu): PEGAR abre a confirmação.
///  • **Em entrega** (já pegos, aguardando código): reabre a confirmação. Cobre
///    o caso do garçom que pegou e saiu da tela sem confirmar (código errado /
///    cliente ausente) — sem isso as unidades ficariam "a caminho" pra sempre.
///
/// Faz polling a cada ~4s (mesmo padrão de `pix_screen.dart`). Pensada pra uso
/// com uma mão só: cards grandes, botões de largura cheia, stepper só quando há
/// mais de 1 unidade pronta.
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

  /// Abre a confirmação de entrega (`/waiter/deliver`) de `qty` unidades de
  /// `item`. Ao voltar, recarrega a lista (o polling também cobre).
  void _openDeliver(ReadyItem item, int qty) {
    context.push('/waiter/deliver', extra: <String, dynamic>{
      'orderItemId': item.orderItemId,
      'name': item.name,
      'mesa': item.mesa,
      'cliente': item.cliente,
      'qty': qty,
    }).then((_) {
      if (mounted) _load(silent: true);
    });
  }

  /// Pega `qty` unidades de `item`. Em sucesso, abre a confirmação de entrega;
  /// em `taken` avisa que outro garçom já pegou; em `error` avisa falha de rede.
  Future<void> _pick(ReadyItem item, int qty) async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    setState(() => _busy.add(item.orderItemId));
    PickResult r;
    try {
      r = await ref.read(publicApiProvider).waiterPick(token, item.orderItemId, qty);
    } catch (_) {
      r = PickResult.error;
    }
    if (!mounted) return;
    setState(() => _busy.remove(item.orderItemId));
    switch (r) {
      case PickResult.ok:
        _qtyN.remove(item.orderItemId);
        _openDeliver(item, qty);
        _load(silent: true);
      case PickResult.taken:
        _toast('Outro garçom já pegou', bg: AppColors.danger, fg: Colors.white);
        _load(silent: true);
      case PickResult.error:
        _toast('Sem conexão. Tente de novo.', bg: AppColors.danger, fg: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          const DarkHeader(eyebrow: 'Garçom', title: 'Fila do garçom'),
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
    final prontos = list.where((i) => i.qtyReady > 0).toList();
    final emEntrega = list.where((i) => i.qtyOutForDelivery > 0).toList();
    if (prontos.isEmpty && emEntrega.isEmpty) {
      return _emptyState();
    }
    return RefreshIndicator(
      color: AppColors.coral,
      onRefresh: () => _load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          if (prontos.isNotEmpty) ...[
            _sectionLabel('Prontos p/ retirada', prontos.length),
            for (final it in prontos)
              Padding(padding: const EdgeInsets.only(bottom: 14), child: _readyCard(it)),
          ],
          if (emEntrega.isNotEmpty) ...[
            if (prontos.isNotEmpty) const SizedBox(height: 10),
            _sectionLabel('Em entrega', emEntrega.length),
            for (final it in emEntrega)
              Padding(padding: const EdgeInsets.only(bottom: 14), child: _deliveringCard(it)),
          ],
        ],
      ),
    );
  }

  Widget _emptyState() {
    return LayoutBuilder(
      builder: (_, c) => RefreshIndicator(
        color: AppColors.coral,
        onRefresh: () => _load(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Symbols.task_alt, size: 44, color: AppColors.inkA(0.35)),
                    const SizedBox(height: 12),
                    Text('Nenhum pedido na fila agora',
                        style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.inkA(0.5))),
                  ],
                ),
              ),
            ),
          ),
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

  Widget _sectionLabel(String text, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 2),
      child: Row(
        children: [
          Text(text.toUpperCase(),
              style: AppText.body(
                  size: 12, weight: FontWeight.w800, color: AppColors.inkA(0.55), letterSpacing: 0.4)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(999)),
            child: Text('$count',
                style: AppText.body(size: 11, weight: FontWeight.w800, color: AppColors.dune)),
          ),
        ],
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
          _infoRow(Symbols.table_restaurant, item.mesa),
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

  /// Card de item já em entrega (pego, aguardando confirmação por código).
  /// Reabre a tela de confirmação com as unidades que ainda estão "a caminho".
  Widget _deliveringCard(ReadyItem item) {
    final qty = item.qtyOutForDelivery;
    return BrutalCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$qty× ${item.name}', style: AppText.display(size: 22, letterSpacing: -0.4)),
          const SizedBox(height: 10),
          _infoRow(Symbols.table_restaurant, item.mesa),
          const SizedBox(height: 4),
          _infoRow(Symbols.person, item.cliente),
          const SizedBox(height: 6),
          _infoRow(Symbols.schedule, 'Aguardando código do cliente'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: Material(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _openDeliver(item, qty),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Symbols.check_circle, size: 20, color: AppColors.dune),
                      const SizedBox(width: 8),
                      Text(
                        'CONFIRMAR ENTREGA',
                        style: AppText.body(
                            size: 16, weight: FontWeight.w800, color: AppColors.dune, letterSpacing: 0.3),
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
