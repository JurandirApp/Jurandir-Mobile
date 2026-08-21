import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/data/models.dart';
import '../../../core/data/public_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_button.dart';
import '../../done/presentation/done_screen.dart';

/// Pagamento Pix: QR + copia-e-cola REAIS (Pagar.me). Faz polling do status —
/// quando o Pix cai, o backend reconcilia, o pedido vira "em produção" e a tela
/// avança pro /done. O pedido já foi criado no checkout (vem via `extra`).
class PixScreen extends ConsumerStatefulWidget {
  const PixScreen({super.key});

  @override
  ConsumerState<PixScreen> createState() => _PixScreenState();
}

class _PixScreenState extends ConsumerState<PixScreen> {
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
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.ink,
          content: Text(
            'Ainda não identificamos o pagamento. Assim que cair, seguimos.',
            style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.dune),
          ),
        ));
    }
  }

  void _copy(String payload) {
    Clipboard.setData(ClipboardData(text: payload));
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.pix,
        content: Text(
          'Código Pix copiado — cole no seu banco.',
          style: AppText.body(size: 13, weight: FontWeight.w700, color: Colors.white),
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final order = GoRouterState.of(context).extra as ClientOrder?;
    final id = order?.dbId;
    if (id != null) _startPolling(id);

    final payload = order?.pixPayload;
    final qr = order?.pixQrImage;

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
        title: Text('Pagar com Pix', style: AppText.display(size: 18)),
        centerTitle: false,
      ),
      body: order == null
          ? Center(child: Text('Pedido não encontrado.', style: AppText.body(size: 14)))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _amountRow(order),
                    const SizedBox(height: 16),
                    _qrCard(qr, payload),
                    const SizedBox(height: 16),
                    _statusRow(),
                    const SizedBox(height: 20),
                    if (payload != null)
                      AppButton.primary(
                        label: 'Copiar código Pix',
                        icon: Symbols.content_copy,
                        onPressed: () => _copy(payload),
                      ),
                    const SizedBox(height: 10),
                    AppButton.dark(
                      label: _checking ? 'Verificando…' : 'Já paguei',
                      icon: Symbols.check_circle,
                      onPressed: (_checking || id == null) ? null : () => _check(id),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'O pagamento é confirmado automaticamente. Você pode fechar '
                      'esta tela e acompanhar em Pedidos.',
                      textAlign: TextAlign.center,
                      style: AppText.body(size: 12, color: AppColors.inkA(0.55)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _amountRow(ClientOrder order) {
    return Column(
      children: [
        Text('Valor a pagar', style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.inkA(0.55))),
        const SizedBox(height: 2),
        Text(money(order.grand), style: AppText.display(size: 30, letterSpacing: -0.5)),
        const SizedBox(height: 2),
        Text('Pedido ${order.code}', style: AppText.body(size: 12, color: AppColors.inkA(0.5)).copyWith(fontFamily: 'monospace')),
      ],
    );
  }

  Widget _qrCard(String? qr, String? payload) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.ink, width: 2),
        boxShadow: const [BoxShadow(color: AppColors.ink, offset: Offset(4, 4))],
      ),
      child: Column(
        children: [
          if (qr != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                base64Decode(qr),
                width: 220,
                height: 220,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => _qrFallback(),
              ),
            )
          else
            _qrFallback(),
          if (payload != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.inkA(0.15)),
              ),
              child: Text(
                payload,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(size: 11, color: AppColors.inkA(0.7)).copyWith(fontFamily: 'monospace'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _qrFallback() {
    return Container(
      width: 220,
      height: 220,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Symbols.qr_code_2, size: 48, color: AppColors.pix),
          const SizedBox(height: 8),
          Text('Use o código copia-e-cola', style: AppText.body(size: 12, color: AppColors.inkA(0.6))),
        ],
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
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.pix),
        ),
        const SizedBox(width: 10),
        Text(
          'Aguardando pagamento',
          style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.pix),
        ),
      ],
    );
  }
}
