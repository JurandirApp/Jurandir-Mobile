import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../../core/widgets/dark_header.dart';
import '../../../core/widgets/language_selector.dart';
import '../../auth/auth_controller.dart';
import '../../../l10n/i18n.dart';

/// Estab · Conta: card da conta + menu (Auditoria/Perfil/Config) + sair.
class EstabContaScreen extends ConsumerWidget {
  const EstabContaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menu = [
      (Symbols.badge, context.tr('estabCfg.waiters'), '/estab/conta/garcons'),
      (Symbols.receipt_long, context.tr('estabCfg.tableTracking'), '/estab/conta/rastreio'),
      (Symbols.shield, context.tr('estabCfg.audit'), '/estab/conta/auditoria'),
      (Symbols.storefront, context.tr('estabCfg.profile'), '/estab/conta/perfil'),
      (Symbols.settings, context.tr('estabCfg.settings'), '/estab/conta/config'),
    ];

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          DarkHeader(title: context.tr('estabCfg.account')),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  BrutalCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(14)),
                          child: const Icon(Symbols.storefront, size: 24, color: AppColors.amber),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ref.watch(authProvider).name ?? context.tr('estab.venue'),
                                  style: AppText.display(size: 16, weight: FontWeight.w700, letterSpacing: 0)),
                              const SizedBox(height: 1),
                              Text(ref.watch(authProvider).email ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  BrutalCard(
                    padding: EdgeInsets.zero,
                    clip: true,
                    child: Column(
                      children: [
                        for (var i = 0; i < menu.length; i++)
                          _menuRow(context, menu[i].$1, menu[i].$2, menu[i].$3, last: i == menu.length - 1),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(context.tr('estabCfg.language').toUpperCase(), style: AppText.sectionTitle),
                    ),
                  ),
                  const LanguageSelector(),
                  const SizedBox(height: 18),
                  AppButton.dark(
                    label: context.tr('estabCfg.signOut'),
                    onPressed: () {
                      ref.read(authProvider.notifier).logout();
                      context.go('/home');
                    },
                  ),
                  const SizedBox(height: 10),
                  AppButton.ghost(label: context.tr('estabCfg.backToClient'), onPressed: () => context.go('/home')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuRow(BuildContext context, IconData icon, String label, String route, {required bool last}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.go(route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: AppColors.inkA(0.08))),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: AppColors.coralDeep),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: AppText.body(size: 14, weight: FontWeight.w700))),
            Icon(Symbols.chevron_right, size: 16, color: AppColors.inkA(0.35)),
          ],
        ),
      ),
    );
  }
}
