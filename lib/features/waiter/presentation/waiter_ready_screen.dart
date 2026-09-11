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

/// Tela do garçom: fila de **pedidos** com algo pronto pra entregar. Tocar num
/// pedido abre o detalhe (`/waiter/order`), onde ele seleciona os itens prontos
/// e confirma a entrega com o código do cliente.
///
/// Faz polling a cada ~4s (mesmo padrão do `pix_screen.dart`) — sem push ainda.
class WaiterReadyScreen extends ConsumerStatefulWidget {
  const WaiterReadyScreen({super.key});

  @override
  ConsumerState<WaiterReadyScreen> createState() => _WaiterReadyScreenState();
}

class _WaiterReadyScreenState extends ConsumerState<WaiterReadyScreen> {
  Timer? _poll;
  List<WaiterOrder>? _orders; // null = carregando (primeira vez)
  bool _error = false;

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
      final orders = await ref.read(publicApiProvider).waiterOrders(token);
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _error = false;
      });
    } catch (_) {
      if (!mounted) return;
      if (!silent || _orders == null) setState(() => _error = true);
    }
  }

  /// Sai da conta do garçom (device pode ser compartilhado → confirma antes).
  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Sair da conta?', style: AppText.display(size: 17, letterSpacing: -0.2)),
        content: Text('Você volta pra tela de login.',
            style: AppText.body(size: 13, weight: FontWeight.w500, color: AppColors.inkA(0.6))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sair', style: AppText.body(size: 14, weight: FontWeight.w800, color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _poll?.cancel();
    ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  void _openOrder(WaiterOrder order) {
    context.push('/waiter/order', extra: order).then((_) {
      if (mounted) _load(silent: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          DarkHeader(
            eyebrow: 'Garçom',
            title: 'Fila do garçom',
            trailing: GestureDetector(
              onTap: _logout,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.duneA(0.12), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Symbols.logout, size: 20, color: AppColors.dune),
              ),
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    final orders = _orders;
    if (orders == null && !_error) {
      return const Center(child: CircularProgressIndicator(color: AppColors.coral, strokeWidth: 3));
    }
    if (_error && (orders == null || orders.isEmpty)) {
      return _errorState();
    }
    final list = orders ?? const <WaiterOrder>[];
    if (list.isEmpty) return _emptyState();
    return RefreshIndicator(
      color: AppColors.coral,
      onRefresh: () => _load(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        itemCount: list.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _orderCard(list[i]),
        ),
      ),
    );
  }

  Widget _orderCard(WaiterOrder order) {
    final ready = order.readyLines;
    final total = order.items.length;
    return BrutalCard(
      padding: const EdgeInsets.all(18),
      onTap: () => _openOrder(order),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(order.cliente.isEmpty ? 'Cliente' : order.cliente,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.display(size: 20, letterSpacing: -0.4)),
              ),
              Icon(Symbols.chevron_right, size: 24, color: AppColors.inkA(0.4)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Symbols.table_restaurant, size: 16, color: AppColors.inkA(0.5)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(order.mesa,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(size: 14, weight: FontWeight.w600, color: AppColors.inkA(0.65))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(999)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Symbols.check_circle, size: 16, color: AppColors.successText),
                const SizedBox(width: 6),
                Text(
                  ready == 1 ? '1 item pronto' : '$ready de $total itens prontos',
                  style: AppText.body(size: 13, weight: FontWeight.w800, color: AppColors.successText),
                ),
              ],
            ),
          ),
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
            Text('Não foi possível carregar a fila.',
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
}
