import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/data/public_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../auth/auth_controller.dart';
import 'admin_sub_header.dart';
import '../../../l10n/i18n.dart';

/// Admin · Pagamentos: ambiente (Teste/Produção) de cada gateway — global da
/// plataforma, vale na hora sem deploy. Os tokens ficam no servidor; aqui o
/// admin só escolhe qual usar.
class AdminPagamentosScreen extends ConsumerWidget {
  const AdminPagamentosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminPaymentModesProvider);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          AdminSubHeader(title: tr('admin.payments')),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.coral, strokeWidth: 3)),
              error: (_, _) => Center(
                child: GestureDetector(
                  onTap: () => ref.invalidate(adminPaymentModesProvider),
                  child: Text(tr('admin.loadErrorTap'),
                      style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.inkA(0.5))),
                ),
              ),
              data: (modes) => ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                children: [
                  Text(
                    tr('admin.envHint'),
                    style: AppText.body(size: 12, weight: FontWeight.w600, height: 1.4, color: AppColors.inkA(0.5)),
                  ),
                  const SizedBox(height: 14),
                  _GatewayCard(
                    gateway: 'pagarme',
                    title: 'Pagar.me',
                    mode: modes.pagarme,
                    productionWarn: tr('admin.pagarmeProd'),
                    testWarn:
                        tr('admin.pagarmeTest'),
                    tokenNote: tr('admin.pagarmeToken'),
                  ),
                  const SizedBox(height: 12),
                  _GatewayCard(
                    gateway: 'pagbank',
                    title: 'PagBank',
                    mode: modes.pagbank,
                    productionWarn: tr('admin.pagbankProd'),
                    testWarn:
                        tr('admin.pagbankTest'),
                    tokenNote: tr('admin.pagbankToken'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GatewayCard extends ConsumerStatefulWidget {
  final String gateway, title, mode, productionWarn, testWarn, tokenNote;
  const _GatewayCard({
    required this.gateway,
    required this.title,
    required this.mode,
    required this.productionWarn,
    required this.testWarn,
    required this.tokenNote,
  });

  @override
  ConsumerState<_GatewayCard> createState() => _GatewayCardState();
}

class _GatewayCardState extends ConsumerState<_GatewayCard> {
  String? _pending; // modo sendo salvo (mostra o loading no botão certo)

  Future<void> _setMode(String mode) async {
    if (mode == widget.mode || _pending != null) return;
    final token = ref.read(authProvider).token;
    if (token == null) return;
    setState(() => _pending = mode);
    try {
      await ref.read(publicApiProvider).setPaymentMode(token, widget.gateway, mode);
      ref.invalidate(adminPaymentModesProvider);
      _toast(tr('admin.envSwitched', {'gw': widget.title, 'env': mode == 'PRODUCTION' ? tr('admin.production') : tr('admin.test')}));
    } catch (_) {
      _toast(tr('admin.envError'));
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
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
    final live = widget.mode == 'PRODUCTION';
    return BrutalCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(widget.title, style: AppText.display(size: 16, weight: FontWeight.w700, letterSpacing: 0))),
              _chip(live),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _modeBtn('TEST', Symbols.science, tr('admin.test'), !live)),
              const SizedBox(width: 8),
              Expanded(child: _modeBtn('PRODUCTION', Symbols.rocket_launch, tr('admin.production'), live)),
            ],
          ),
          const SizedBox(height: 12),
          _banner(live),
          const SizedBox(height: 10),
          Text(widget.tokenNote,
              style: AppText.body(size: 10, weight: FontWeight.w600, height: 1.4, color: AppColors.inkA(0.4))),
        ],
      ),
    );
  }

  Widget _chip(bool live) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: live ? AppColors.successBg : AppColors.inkA(0.08),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(live ? tr('admin.production') : tr('admin.test'),
            style: AppText.body(size: 11, weight: FontWeight.w700, color: live ? AppColors.successText : AppColors.inkA(0.5))),
      );

  Widget _modeBtn(String mode, IconData icon, String label, bool active) {
    final loading = _pending == mode;
    return GestureDetector(
      onTap: () => _setMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.ink : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? AppColors.ink : AppColors.inkA(0.15), width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink))
            else
              Icon(active ? Symbols.check_circle : icon, size: 16, color: active ? AppColors.dune : AppColors.inkA(0.55)),
            const SizedBox(width: 6),
            Text(label, style: AppText.body(size: 13, weight: FontWeight.w700, color: active ? AppColors.dune : AppColors.inkA(0.6))),
          ],
        ),
      ),
    );
  }

  Widget _banner(bool live) {
    final bg = live ? AppColors.dangerBg : AppColors.warningBg;
    final fg = live ? AppColors.dangerText : AppColors.warningText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(live ? Symbols.warning : Symbols.info, size: 16, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(live ? widget.productionWarn : widget.testWarn,
                style: AppText.body(size: 11, weight: FontWeight.w600, height: 1.4, color: fg)),
          ),
        ],
      ),
    );
  }
}
