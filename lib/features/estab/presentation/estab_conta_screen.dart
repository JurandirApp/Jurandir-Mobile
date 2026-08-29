import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../../core/widgets/dark_header.dart';
import '../../auth/auth_controller.dart';

/// Estab · Conta: card da conta + menu (Auditoria/Perfil/Config) + sair.
class EstabContaScreen extends ConsumerWidget {
  const EstabContaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menu = [
      (Symbols.shield, 'Auditoria', '/estab/conta/auditoria'),
      (Symbols.storefront, 'Perfil', '/estab/conta/perfil'),
      (Symbols.settings, 'Configurações', '/estab/conta/config'),
    ];

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          const DarkHeader(title: 'Conta'),
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
                              Text(ref.watch(authProvider).name ?? 'Estabelecimento',
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
                  const SizedBox(height: 14),
                  AppButton.dark(
                    label: 'Sair da conta',
                    onPressed: () {
                      ref.read(authProvider.notifier).logout();
                      context.go('/home');
                    },
                  ),
                  const SizedBox(height: 10),
                  AppButton.ghost(label: 'Voltar ao modo cliente', onPressed: () => context.go('/home')),
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
