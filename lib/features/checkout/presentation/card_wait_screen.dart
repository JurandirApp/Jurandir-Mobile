import 'dart:async';

import '../../../core/utils/backoff_poller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/data/models.dart';
import '../../../core/data/public_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_button.dart';
import '../../cart/cart_controller.dart';
import '../../done/presentation/done_screen.dart';
import '../../../l10n/i18n.dart';

/// Argumentos passados pelo Checkout via `go('/pagamento', extra: ...)`.
/// `checkoutUrl` vazio/nulo = pagamento **in-app** já submetido (cartão/carteira
/// tokenizado, em análise do antifraude) → só esperamos a confirmação. Com URL =
/// fluxo antigo de checkout hospedado (abre o navegador).
class CardWaitArgs {
  final ClientOrder order;
  final String? checkoutUrl;
  const CardWaitArgs({required this.order, this.checkoutUrl});
}

/// Espera do pagamento de cartão / carteira. Faz polling do status do pedido e,
/// quando cai, vai pro /done — assim o cliente NÃO fica travado na tela de
/// pagamento (o antifraude do cartão é assíncrono e leva alguns segundos). Se
/// demorar demais, avisa que o pedido aparece em Pedidos assim que confirmar.
class CardWaitScreen extends ConsumerStatefulWidget {
  const CardWaitScreen({super.key});

  @override
  ConsumerState<CardWaitScreen> createState() => _CardWaitScreenState();
}

class _CardWaitScreenState extends ConsumerState<CardWaitScreen> {
  // Espera máxima antes de mostrar "ainda processando" (as consultas espaçam
  // com o tempo — ver cardWaitPollSchedule).
  static const _maxWait = Duration(seconds: 90);

  BackoffPoller? _poll;
  bool _checking = false;
  bool _done = false;
  bool _timedOut = false;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _startPolling(String id) {
    _poll ??= BackoffPoller(() {
      _check(id, silent: true);
      if ((_poll?.elapsed ?? Duration.zero) >= _maxWait && !_done && mounted) {
        _poll?.cancel();
        _poll = null;
        setState(() => _timedOut = true);
      }
    }, schedule: cardWaitPollSchedule)
      ..start();
  }

  Future<void> _check(String id, {bool silent = false}) async {
    if (_done) return;
    if (!silent && mounted) setState(() => _checking = true);
    ClientOrder? o;
    try {
      final list = await ref.read(publicApiProvider).myOrders([id]);
      o = list.isNotEmpty ? list.first : null;
    } catch (_) {}
    if (!mounted) return;
    if (o != null && (o.status == 'producao' || o.status == 'entregue')) {
      _done = true;
      _poll?.cancel();
      // Pago → encerra o carrinho e a pendência (não dá mais pra editar).
      ref.read(cartProvider.notifier).clear();
      ref.read(pendingOrderProvider.notifier).set(null);
      context.go('/done', extra: DoneArgs(incomplete: false, code: o.code));
      return;
    }
    if (!silent) {
      setState(() => _checking = false);
      if (!_timedOut) _snack(context.tr('checkout.stillProcessing'));
    }
  }

  Future<void> _openCheckout(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) _snack(context.tr('checkout.cantOpenPaymentPage'));
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        content: Text(msg, style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.dune)),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final args = GoRouterState.of(context).extra as CardWaitArgs?;
    final order = args?.order;
    final id = order?.dbId;
    final inApp = (args?.checkoutUrl ?? '').isEmpty;
    if (id != null && !_timedOut) _startPolling(id);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back, color: AppColors.ink),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: Text(inApp ? context.tr('checkout.processingPayment') : context.tr('checkout.payment'),
            style: AppText.display(size: 18)),
        centerTitle: false,
      ),
      body: args == null
          ? Center(child: Text(context.tr('checkout.orderNotFound'), style: AppText.body(size: 14)))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      children: [
                        Text(context.tr('checkout.amount'), style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.inkA(0.55))),
                        const SizedBox(height: 2),
                        Text(money(order!.grand), style: AppText.display(size: 30, letterSpacing: -0.5)),
                        const SizedBox(height: 2),
                        Text(context.tr('checkout.orderCode', {'code': order.code}), style: AppText.body(size: 12, color: AppColors.inkA(0.5)).copyWith(fontFamily: 'monospace')),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.ink, width: 2),
                        boxShadow: const [BoxShadow(color: AppColors.ink, offset: Offset(4, 4))],
                      ),
                      child: Column(
                        children: [
                          Icon(_timedOut ? Symbols.schedule : (inApp ? Symbols.credit_card : Symbols.open_in_new),
                              size: 40, color: AppColors.credit),
                          const SizedBox(height: 12),
                          Text(
                            _timedOut
                                ? context.tr('checkout.waitTimedOut')
                                : inApp
                                    ? context.tr('checkout.waitInApp')
                                    : context.tr('checkout.waitExternal'),
                            textAlign: TextAlign.center,
                            style: AppText.body(size: 13, color: AppColors.inkA(0.65)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!_timedOut) _statusRow(),
                    const SizedBox(height: 20),
                    if (_timedOut) ...[
                      AppButton.primary(
                        label: context.tr('checkout.seeMyOrders'),
                        icon: Symbols.receipt_long,
                        onPressed: () => context.go('/pedidos'),
                      ),
                      const SizedBox(height: 10),
                      AppButton.dark(
                        label: context.tr('checkout.backHome'),
                        icon: Symbols.home,
                        onPressed: () => context.go('/home'),
                      ),
                    ] else ...[
                      if (!inApp)
                        AppButton.primary(
                          label: context.tr('checkout.reopenPayment'),
                          icon: Symbols.open_in_new,
                          onPressed: () => _openCheckout(args.checkoutUrl ?? ''),
                        ),
                      if (!inApp) const SizedBox(height: 10),
                      AppButton.dark(
                        label: _checking ? context.tr('checkout.checking') : context.tr('checkout.checkNow'),
                        icon: Symbols.check_circle,
                        onPressed: (_checking || id == null) ? null : () => _check(id),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _statusRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.credit),
        ),
        const SizedBox(width: 10),
        Text(
          context.tr('checkout.awaitingConfirmation'),
          style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.credit),
        ),
      ],
    );
  }
}
