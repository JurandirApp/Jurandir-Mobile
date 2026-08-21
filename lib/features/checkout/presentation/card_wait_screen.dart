import 'dart:async';

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
import '../../done/presentation/done_screen.dart';

/// Argumentos passados pelo Checkout via `go('/pagamento', extra: ...)`.
class CardWaitArgs {
  final ClientOrder order;
  final String checkoutUrl;
  const CardWaitArgs({required this.order, required this.checkoutUrl});
}

/// Espera do pagamento de cartão (checkout hospedado da Pagar.me). O navegador
/// abre a página de pagamento; esta tela faz polling do status e, quando o
/// pagamento cai, vai pro /done. O cliente pode reabrir a página se fechou.
class CardWaitScreen extends ConsumerStatefulWidget {
  const CardWaitScreen({super.key});

  @override
  ConsumerState<CardWaitScreen> createState() => _CardWaitScreenState();
}

class _CardWaitScreenState extends ConsumerState<CardWaitScreen> {
  Timer? _poll;
  bool _checking = false;
  bool _done = false;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _startPolling(String id) {
    _poll ??= Timer.periodic(
      const Duration(seconds: 4),
      (_) => _check(id, silent: true),
    );
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
      context.go('/done', extra: DoneArgs(incomplete: false, code: o.code));
      return;
    }
    if (!silent) {
      setState(() => _checking = false);
      _snack('Ainda não identificamos o pagamento. Conclua no navegador e volte.');
    }
  }

  Future<void> _openCheckout(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) _snack('Não foi possível abrir a página de pagamento.');
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
    if (id != null) _startPolling(id);

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
        title: Text('Pagamento no cartão', style: AppText.display(size: 18)),
        centerTitle: false,
      ),
      body: args == null
          ? Center(child: Text('Pedido não encontrado.', style: AppText.body(size: 14)))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      children: [
                        Text('Valor a pagar', style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.inkA(0.55))),
                        const SizedBox(height: 2),
                        Text(money(order!.grand), style: AppText.display(size: 30, letterSpacing: -0.5)),
                        const SizedBox(height: 2),
                        Text('Pedido ${order.code}', style: AppText.body(size: 12, color: AppColors.inkA(0.5)).copyWith(fontFamily: 'monospace')),
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
                          const Icon(Symbols.open_in_new, size: 40, color: AppColors.credit),
                          const SizedBox(height: 12),
                          Text(
                            'Abrimos a página segura da Pagar.me pra você pagar com cartão. '
                            'Conclua lá e volte — a confirmação chega aqui sozinha.',
                            textAlign: TextAlign.center,
                            style: AppText.body(size: 13, color: AppColors.inkA(0.65)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _statusRow(),
                    const SizedBox(height: 20),
                    AppButton.primary(
                      label: 'Reabrir pagamento',
                      icon: Symbols.open_in_new,
                      onPressed: () => _openCheckout(args.checkoutUrl),
                    ),
                    const SizedBox(height: 10),
                    AppButton.dark(
                      label: _checking ? 'Verificando…' : 'Já paguei',
                      icon: Symbols.check_circle,
                      onPressed: (_checking || id == null) ? null : () => _check(id),
                    ),
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
          'Aguardando confirmação',
          style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.credit),
        ),
      ],
    );
  }
}
