import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/data/public_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/nav_tab.dart';

/// Shell do estabelecimento: bottom nav (Pedidos · Cardápio · QR · KPIs ·
/// Conta), sem FAB.
class EstabScaffold extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const EstabScaffold({super.key, required this.navigationShell});

  static const _items = [
    (Symbols.receipt_long, 'Pedidos'),
    (Symbols.restaurant, 'Cardápio'),
    (Symbols.qr_code_2, 'QR'),
    (Symbols.trending_up, 'KPIs'),
    (Symbols.person, 'Conta'),
  ];

  // As telas ficam vivas no IndexedStack, então o `watch` fica preso no cache.
  // Ao entrar numa aba, revalidamos os dados dela pra refletir o que mudou na
  // plataforma. `skipLoadingOnRefresh` mantém o conteúdo antigo enquanto busca,
  // sem piscar spinner.
  void _refreshBranch(WidgetRef ref, int i) {
    if (i == 0 || i == 3) ref.invalidate(establishmentOrdersProvider); // Pedidos / KPIs
    if (i == 1) ref.invalidate(establishmentMenuProvider); // Cardápio
    if (i == 2) ref.invalidate(establishmentQrProvider); // QR
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final safe = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: navigationShell,
      bottomNavigationBar: Container(
        color: AppColors.ink,
        padding: EdgeInsets.only(top: 8, bottom: (safe > 0 ? safe : 16) + 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < _items.length; i++)
              NavTab(
                active: navigationShell.currentIndex == i,
                icon: _items[i].$1,
                label: _items[i].$2,
                onTap: () {
                  _refreshBranch(ref, i);
                  navigationShell.goBranch(i);
                },
              ),
          ],
        ),
      ),
    );
  }
}
