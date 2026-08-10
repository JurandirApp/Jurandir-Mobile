import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/nav_tab.dart';

/// Shell do estabelecimento: bottom nav (Pedidos · Cardápio · QR · KPIs ·
/// Conta), sem FAB.
class EstabScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const EstabScaffold({super.key, required this.navigationShell});

  static const _items = [
    (Symbols.receipt_long, 'Pedidos'),
    (Symbols.restaurant, 'Cardápio'),
    (Symbols.qr_code_2, 'QR'),
    (Symbols.trending_up, 'KPIs'),
    (Symbols.person, 'Conta'),
  ];

  @override
  Widget build(BuildContext context) {
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
                onTap: () => navigationShell.goBranch(i),
              ),
          ],
        ),
      ),
    );
  }
}
