import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/data/models.dart';
import '../../../core/data/public_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money.dart';
import '../../done/presentation/done_screen.dart';

/// Conta dividida: um Pix por pessoa (Pagar.me). O organizador paga o seu e
/// compartilha os outros no WhatsApp. Faz polling — quando TODAS as partes caem,
/// o pedido vai pra cozinha e a tela avança pro /done.
class SplitScreen extends ConsumerStatefulWidget {
  const SplitScreen({super.key});

  @override
  ConsumerState<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends ConsumerState<SplitScreen> {
  Timer? _poll;
  ClientOrder? _order;
  bool _done = false;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh(String id) async {
    if (_done) return;
    ClientOrder? o;
    try {
      final list = await ref.read(publicApiProvider).myOrders([id]);
      o = list.isNotEmpty ? list.first : null;
    } catch (_) {}
    if (!mounted || o == null) return;
    setState(() => _order = o);
    if (o.status == 'producao' || o.status == 'entregue') {
      _done = true;
      _poll?.cancel();
      context.go('/done', extra: DoneArgs(incomplete: false, code: o.code));
    }
  }

  void _copy(String payload) {
    Clipboard.setData(ClipboardData(text: payload));
    _snack('Código Pix copiado.', AppColors.pix);
  }

  Future<void> _shareWhats(ClientOrder order, int i, ClientShare s) async {
    final msg = 'Nossa conta no ${order.code} — sua parte é ${money(s.amount)}. '
        'Paga no Pix (copia e cola):\n\n${s.pixPayload}';
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(msg)}');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) _snack('Não foi possível abrir o WhatsApp.', AppColors.ink);
  }

  void _snack(String msg, Color bg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: bg,
        content: Text(msg, style: AppText.body(size: 13, weight: FontWeight.w700, color: Colors.white)),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final initial = GoRouterState.of(context).extra as ClientOrder?;
    if (initial == null) {
      return Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(backgroundColor: AppColors.canvas, elevation: 0),
        body: Center(child: Text('Pedido não encontrado.', style: AppText.body(size: 14))),
      );
    }
    _order ??= initial;
    final id = initial.dbId;
    if (id != null) _poll ??= Timer.periodic(const Duration(seconds: 4), (_) => _refresh(id));

    final order = _order!;
    final shares = order.splits ?? const <ClientShare>[];
    final paidN = shares.where((s) => s.paid).length;

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
        title: Text('Dividir a conta', style: AppText.display(size: 18)),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            _header(order, shares.length, paidN),
            const SizedBox(height: 16),
            for (var i = 0; i < shares.length; i++) ...[
              _shareCard(order, i, shares[i]),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header(ClientOrder order, int total, int paidN) {
    return Column(
      children: [
        Text('Total do pedido', style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.inkA(0.55))),
        const SizedBox(height: 2),
        Text(money(order.grand), style: AppText.display(size: 28, letterSpacing: -0.5)),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : paidN / total,
            minHeight: 8,
            backgroundColor: AppColors.inkA(0.08),
            valueColor: const AlwaysStoppedAnimation(AppColors.success),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          paidN == total ? 'Todos pagaram! Enviando pra cozinha…' : '$paidN de $total pagaram',
          style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.inkA(0.6)),
        ),
      ],
    );
  }

  Widget _shareCard(ClientOrder order, int i, ClientShare s) {
    final paid = s.paid;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.ink, width: 2),
        boxShadow: const [BoxShadow(color: AppColors.ink, offset: Offset(4, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Pessoa ${i + 1}', style: AppText.body(size: 14, weight: FontWeight.w800)),
              Text(money(s.amount), style: AppText.body(size: 14, weight: FontWeight.w800, color: AppColors.coralDeep)),
            ],
          ),
          const SizedBox(height: 10),
          if (paid)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Symbols.check_circle, size: 18, color: AppColors.successText),
                  const SizedBox(width: 6),
                  Text('Pago', style: AppText.body(size: 13, weight: FontWeight.w800, color: AppColors.successText)),
                ],
              ),
            )
          else ...[
            if (s.pixQrImage != null)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    base64Decode(s.pixQrImage!),
                    width: 150,
                    height: 150,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _smallBtn(Symbols.content_copy, 'Copiar', AppColors.ink,
                      s.pixPayload == null ? null : () => _copy(s.pixPayload!)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _smallBtn(Symbols.share, 'WhatsApp', const Color(0xFF25D366),
                      s.pixPayload == null ? null : () => _shareWhats(order, i, s)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _smallBtn(IconData icon, String label, Color bg, VoidCallback? onTap) {
    return Material(
      color: onTap == null ? AppColors.inkA(0.2) : bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(label, style: AppText.body(size: 13, weight: FontWeight.w700, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}
