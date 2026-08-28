import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/data/models.dart';
import '../../../core/data/public_api.dart';
import '../../../core/data/seed_data.dart'; // só o slug padrão (kDemoSlug)
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/filter_pill.dart';
import '../../../core/widgets/skeleton.dart';
import '../../cart/cart_controller.dart';

/// Cardápio: header do estabelecimento, barra de categorias fixa (sticky),
/// lista de itens (add / stepper) e barra de carrinho flutuante.
class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  String _cat = 'Todos';

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final ctrl = ref.read(cartProvider.notifier);
    final slug = ref.watch(selectedSlugProvider) ?? kDemoSlug;
    final menuAsync = ref.watch(menuProvider(slug));
    final menu = menuAsync.asData?.value ?? const <MenuItem>[];
    final ests = ref.watch(establishmentsProvider).asData?.value ?? const <Establishment>[];
    // Estabelecimento aberto pelo cliente; placeholder neutro (sem mock) até
    // a lista real chegar — a home/busca já deixam o provider em cache.
    final est = ests.firstWhere(
      (e) => e.slug == slug,
      orElse: () => Establishment(
        id: '', slug: slug, name: '', location: '', cuisine: '', orders: 0, rating: 0, open: true,
      ),
    );
    final cats = <String>['Todos', ...{for (final m in menu) m.category}];
    final items = _cat == 'Todos' ? menu : menu.where((m) => m.category == _cat).toList();
    final count = cartCount(cart);
    final total = ctrl.total;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _header(context, est)),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _CatBar(
                    cats: cats,
                    selected: _cat,
                    onTap: (c) => setState(() => _cat = c),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    12,
                    20,
                    (count > 0 ? 96 : 20) + bottomSafe,
                  ),
                  sliver: menuAsync.when(
                    loading: () => SliverList.separated(
                      itemCount: 6,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, _) => _itemRowSkeleton(),
                    ),
                    error: (_, _) => SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: _errorState(() => ref.invalidate(menuProvider(slug))),
                      ),
                    ),
                    data: (_) => items.isEmpty
                        ? SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 48),
                              child: Center(
                                child: Text('Cardápio em breve por aqui.',
                                    style: AppText.body(size: 14, color: AppColors.inkA(0.45))),
                              ),
                            ),
                          )
                        : SliverList.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final m = items[i];
                              return _itemRow(m, cart[m.id] ?? 0, ctrl);
                            },
                          ),
                  ),
                ),
              ],
            ),
            if (count > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _cartBar(context, count, total, bottomSafe),
              ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, Establishment est) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 20, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.go('/home'),
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.duneA(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Symbols.arrow_back, size: 19, color: AppColors.dune),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  est.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.display(size: 19, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Symbols.location_on, size: 12, color: AppColors.coral),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        est.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.duneA(0.6)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Row(
            children: [
              const Icon(Symbols.star, size: 14, color: AppColors.amber, fill: 1),
              const SizedBox(width: 4),
              Text(
                est.rating.toStringAsFixed(1),
                style: AppText.body(size: 13, weight: FontWeight.w700, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _itemRow(MenuItem m, int qty, CartController ctrl) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.ink, width: 2),
        boxShadow: const [BoxShadow(color: AppColors.ink, offset: Offset(4, 4))],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 58,
              height: 58,
              color: const Color(0xFFE2E8F0),
              child: Image.network(
                m.photoUrl,
                width: 58,
                height: 58,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(size: 14, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  m.desc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(size: 11, weight: FontWeight.w500, color: AppColors.inkA(0.5)),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (m.oldPrice != null) ...[
                      Text(
                        money(m.oldPrice!),
                        style: AppText.body(size: 11, color: AppColors.inkA(0.35))
                            .copyWith(decoration: TextDecoration.lineThrough),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      money(m.price),
                      style: AppText.body(size: 15, weight: FontWeight.w800, color: AppColors.coralDeep),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (qty == 0)
            _circleBtn(36, AppColors.coral, Symbols.add, Colors.white, () => ctrl.add(m))
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _circleBtn(30, AppColors.duneA(0.6), Symbols.remove, AppColors.ink, () => ctrl.dec(m.id)),
                SizedBox(
                  width: 28,
                  child: Text(
                    '$qty',
                    textAlign: TextAlign.center,
                    style: AppText.body(size: 14, weight: FontWeight.w800),
                  ),
                ),
                _circleBtn(30, AppColors.coral, Symbols.add, Colors.white, () => ctrl.add(m)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _itemRowSkeleton() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.ink, width: 2),
        boxShadow: const [BoxShadow(color: AppColors.ink, offset: Offset(4, 4))],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(width: 58, height: 58, color: AppColors.inkA(0.08)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SkeletonBox(width: 120, height: 14),
                SizedBox(height: 8),
                SkeletonBox(width: 170, height: 11),
                SizedBox(height: 10),
                SkeletonBox(width: 60, height: 15),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const SkeletonBox(width: 36, height: 36, radius: 999),
        ],
      ),
    );
  }

  Widget _errorState(VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Não foi possível carregar o cardápio.',
                textAlign: TextAlign.center,
                style: AppText.body(size: 15, weight: FontWeight.w700, color: AppColors.inkA(0.7))),
            const SizedBox(height: 6),
            Text('Verifique sua conexão e tente de novo.',
                textAlign: TextAlign.center,
                style: AppText.body(size: 13, color: AppColors.inkA(0.45))),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(999)),
                child: Text('Tentar de novo',
                    style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.dune)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleBtn(double size, Color bg, IconData icon, Color fg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, size: size * 0.5, color: fg),
      ),
    );
  }

  Widget _cartBar(BuildContext context, int count, double total, double bottomSafe) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 24, 16, 12 + bottomSafe),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            AppColors.canvas,
            AppColors.canvas,
            AppColors.canvas.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      child: Material(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: () => context.go('/checkout'),
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Symbols.shopping_cart, size: 18, color: AppColors.dune),
                    const SizedBox(width: 8),
                    Text('$count', style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.dune)),
                  ],
                ),
                Text(
                  'Ver pedido · ${money(total)}',
                  style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.dune),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra de categorias fixa (sticky) do cardápio.
class _CatBar extends SliverPersistentHeaderDelegate {
  final List<String> cats;
  final String selected;
  final ValueChanged<String> onTap;

  _CatBar({required this.cats, required this.selected, required this.onTap});

  @override
  double get minExtent => 56;

  @override
  double get maxExtent => 56;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.canvas,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < cats.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              FilterPill(
                label: cats[i],
                selected: cats[i] == selected,
                onTap: () => onTap(cats[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_CatBar oldDelegate) => oldDelegate.selected != selected;
}
