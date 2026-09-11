import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/data/public_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../../core/widgets/dark_header.dart';
import '../../auth/auth_controller.dart';
import '../data/waiter_models.dart';

/// Detalhe do pedido pro garçom: mostra todas as linhas (prontas selecionáveis,
/// preparando só informativas), o garçom marca as que está levando e confirma
/// tudo com o código que o cliente mostra no app dele (4 últimos do telefone).
///
/// Chega via `context.push('/waiter/order', extra: <WaiterOrder>)`.
class WaiterOrderScreen extends ConsumerStatefulWidget {
  const WaiterOrderScreen({super.key});

  @override
  ConsumerState<WaiterOrderScreen> createState() => _WaiterOrderScreenState();
}

class _WaiterOrderScreenState extends ConsumerState<WaiterOrderScreen> {
  WaiterOrder? _order;
  final Set<String> _selected = {}; // orderItemIds marcados
  final Map<String, int> _qty = {}; // quantidade escolhida por item
  final _code = TextEditingController();
  bool _busy = false;
  String? _codeError;
  bool _initFromExtra = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initFromExtra) return;
    final extra = GoRouterState.of(context).extra;
    if (extra is WaiterOrder) {
      _order = extra;
      _initFromExtra = true;
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

  /// Recarrega o pedido do servidor (pull-to-refresh) e reconcilia a seleção:
  /// tira itens que sumiram ou não estão mais prontos e limita a quantidade.
  Future<void> _refresh() async {
    final token = ref.read(authProvider).token;
    final id = _order?.orderId;
    if (token == null || id == null) return;
    try {
      final orders = await ref.read(publicApiProvider).waiterOrders(token);
      if (!mounted) return;
      WaiterOrder? match;
      for (final o in orders) {
        if (o.orderId == id) {
          match = o;
          break;
        }
      }
      final found = match; // final → promove pra não-nulo dentro do closure
      setState(() {
        _order = found;
        if (found == null) {
          _selected.clear();
          _qty.clear();
        } else {
          for (final item in found.items) {
            if (_qty.containsKey(item.orderItemId) && _qty[item.orderItemId]! > item.qtyReady) {
              _qty[item.orderItemId] = item.qtyReady < 1 ? 1 : item.qtyReady;
            }
          }
          _selected.removeWhere((oid) => !found.items.any((i) => i.orderItemId == oid && i.qtyReady > 0));
        }
      });
    } catch (_) {/* silencioso; o snapshot atual segue válido */}
  }

  void _toggle(WaiterOrderItem item) {
    setState(() {
      if (_selected.contains(item.orderItemId)) {
        _selected.remove(item.orderItemId);
      } else {
        _selected.add(item.orderItemId);
        _qty[item.orderItemId] = item.qtyReady; // default: todas as prontas
      }
    });
  }

  void _setQty(WaiterOrderItem item, int n) {
    setState(() => _qty[item.orderItemId] = n.clamp(1, item.qtyReady));
  }

  Future<void> _confirm() async {
    final order = _order;
    if (order == null || _busy) return;
    final code = _code.text.trim();
    if (code.length != 4) {
      setState(() => _codeError = 'Digite os 4 dígitos do código');
      return;
    }
    final token = ref.read(authProvider).token;
    if (token == null) return;
    final items = _selected
        .map((oid) => (orderItemId: oid, qty: _qty[oid] ?? 1))
        .where((e) => e.qty > 0)
        .toList();
    if (items.isEmpty) return;

    setState(() {
      _busy = true;
      _codeError = null;
    });
    final r = await ref.read(publicApiProvider).waiterDeliverOrder(token, order.orderId, items, code);
    if (!mounted) return;

    if (r.ok) {
      _toast(r.orderDone ? '✅ ENTREGUE — pedido concluído' : '✅ ENTREGUE', bg: AppColors.success, fg: Colors.white);
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      context.pop();
      return;
    }

    setState(() => _busy = false);
    if (r.error == 'code') {
      setState(() => _codeError = 'Código inválido, confira com o cliente');
    } else if (r.error == 'qty') {
      _toast('Algum item mudou. Confira a seleção.', bg: AppColors.danger, fg: Colors.white);
      _refresh();
    } else {
      _toast('Não foi possível confirmar. Tente de novo.', bg: AppColors.danger, fg: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          DarkHeader(
            eyebrow: 'Garçom',
            title: order == null ? 'Pedido' : 'Entrega — ${order.mesa}',
          ),
          Expanded(child: order == null ? _goneState() : _body(order)),
        ],
      ),
    );
  }

  Widget _goneState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.check_circle, size: 44, color: AppColors.inkA(0.35)),
            const SizedBox(height: 12),
            Text('Pedido concluído ou não disponível.',
                textAlign: TextAlign.center,
                style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
            const SizedBox(height: 14),
            SizedBox(
              height: 56,
              child: AppButton.dark(label: 'VOLTAR PARA A FILA', onPressed: () => context.pop()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(WaiterOrder order) {
    final ready = order.items.where((i) => i.qtyReady > 0).toList();
    final preparing = order.items.where((i) => i.qtyReady == 0 && i.qtyPreparing > 0).toList();
    final hasSelection = _selected.isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: AppColors.coral,
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: [
                Row(
                  children: [
                    Icon(Symbols.person, size: 16, color: AppColors.inkA(0.5)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(order.cliente.isEmpty ? 'Cliente' : order.cliente,
                          style: AppText.body(size: 15, weight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (ready.isNotEmpty) ...[
                  _label('Prontos — toque pra selecionar'),
                  for (final it in ready) _readyRow(it),
                ],
                if (preparing.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _label('Ainda preparando'),
                  for (final it in preparing) _preparingRow(it),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        if (hasSelection) _codeBar(),
      ],
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 2),
      child: Text(text.toUpperCase(),
          style: AppText.body(size: 12, weight: FontWeight.w800, color: AppColors.inkA(0.55), letterSpacing: 0.4)),
    );
  }

  Widget _readyRow(WaiterOrderItem item) {
    final selected = _selected.contains(item.orderItemId);
    final n = (_qty[item.orderItemId] ?? item.qtyReady).clamp(1, item.qtyReady);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BrutalCard(
        padding: const EdgeInsets.all(16),
        onTap: () => _toggle(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(selected ? Symbols.check_box : Symbols.check_box_outline_blank,
                    size: 26, color: selected ? AppColors.coral : AppColors.inkA(0.35)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('${item.qtyReady}× ${item.name}',
                      style: AppText.display(size: 18, letterSpacing: -0.3)),
                ),
              ],
            ),
            if (selected && item.qtyReady > 1) ...[
              const SizedBox(height: 12),
              _stepperRow(item, n),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stepperRow(WaiterOrderItem item, int n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: AppColors.duneA(0.5), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: Text('Quantidade a entregar',
                style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.inkA(0.55))),
          ),
          _stepBtn(Symbols.remove, n <= 1 ? null : () => _setQty(item, n - 1)),
          SizedBox(width: 30, child: Text('$n', textAlign: TextAlign.center, style: AppText.display(size: 16))),
          _stepBtn(Symbols.add, n >= item.qtyReady ? null : () => _setQty(item, n + 1)),
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

  Widget _preparingRow(WaiterOrderItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.inkA(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.inkA(0.08)),
        ),
        child: Row(
          children: [
            Icon(Symbols.schedule, size: 20, color: AppColors.inkA(0.35)),
            const SizedBox(width: 12),
            Expanded(
              child: Text('${item.qtyPreparing}× ${item.name}',
                  style: AppText.body(size: 15, weight: FontWeight.w700, color: AppColors.inkA(0.45))),
            ),
            Text('preparando',
                style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.inkA(0.4))),
          ],
        ),
      ),
    );
  }

  /// Barra fixa embaixo com o campo de código + confirmar (aparece quando há
  /// itens selecionados). O cliente mostra o código no app dele; o garçom digita.
  Widget _codeBar() {
    final count = _selected.length;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.paddingOf(context).bottom + 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [BoxShadow(color: AppColors.inkA(0.12), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CÓDIGO DO CLIENTE · $count ${count == 1 ? 'item' : 'itens'}', style: AppText.sectionTitle),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: AppText.display(size: 30, letterSpacing: 10),
                  onChanged: (_) {
                    if (_codeError != null) setState(() => _codeError = null);
                  },
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.canvas,
                    hintText: '••••',
                    hintStyle: AppText.display(size: 30, letterSpacing: 10, color: AppColors.inkA(0.2)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: _codeError != null ? AppColors.danger : AppColors.inkA(0.15), width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: _codeError != null ? AppColors.danger : AppColors.ink, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 130,
                height: 56,
                child: Material(
                  color: _busy ? AppColors.coral.withValues(alpha: 0.6) : AppColors.coral,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _busy ? null : _confirm,
                    child: Center(
                      child: _busy
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                          : Text('ENTREGAR',
                              style: AppText.body(size: 15, weight: FontWeight.w800, color: Colors.white, letterSpacing: 0.3)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_codeError != null) ...[
            const SizedBox(height: 6),
            Text(_codeError!, style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.danger)),
          ],
        ],
      ),
    );
  }
}
