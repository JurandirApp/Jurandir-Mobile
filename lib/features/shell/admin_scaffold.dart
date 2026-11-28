import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/nav_tab.dart';
import '../../l10n/i18n.dart';

/// Shell do admin: bottom nav (Dashboard · Faturamento · Buscas · Backlog ·
/// Conta), sem FAB.
class AdminScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AdminScaffold({super.key, required this.navigationShell});

  static const _items = [
    (Symbols.space_dashboard, 'admin.tabDashboard'),
    (Symbols.trending_up, 'admin.tabRevenue'),
    (Symbols.search, 'admin.tabSearches'),
    (Symbols.receipt_long, 'admin.tabBacklog'),
    (Symbols.person, 'admin.tabAccount'),
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
                label: context.tr(_items[i].$2),
                onTap: () => navigationShell.goBranch(i),
              ),
          ],
        ),
      ),
    );
  }
}
