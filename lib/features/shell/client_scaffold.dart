import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Shell do cliente: bottom nav (Início · Buscar · [FAB scan] · Pedidos ·
/// Perfil) sobre as 4 abas (IndexedStack do go_router).
class ClientScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ClientScaffold({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: navigationShell,
      bottomNavigationBar: _navBar(context),
    );
  }

  Widget _navBar(BuildContext context) {
    final safe = MediaQuery.paddingOf(context).bottom;
    return Container(
      color: AppColors.ink,
      padding: EdgeInsets.only(top: 8, bottom: (safe > 0 ? safe : 14) + 4),
      // Botão QR centralizado verticalmente no meio da barra (não levantado).
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _tab(0, Symbols.home, 'Início'),
          _tab(1, Symbols.search, 'Buscar'),
          _scanButton(context),
          _tab(2, Symbols.receipt_long, 'Pedidos'),
          _tab(3, Symbols.person, 'Perfil'),
        ],
      ),
    );
  }

  Widget _scanButton(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/scanner'),
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.coral,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.coralDeep.withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Symbols.qr_code_scanner, size: 26, color: Colors.white),
      ),
    );
  }

  Widget _tab(int index, IconData icon, String label) {
    final active = navigationShell.currentIndex == index;
    final color = active ? AppColors.ink : AppColors.duneA(0.55);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => navigationShell.goBranch(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.dune : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 3),
            Text(label, style: AppText.body(size: 10, weight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}
