import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/data/models.dart';
import '../../../core/data/public_api.dart';
import '../../../core/data/seed_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../../core/widgets/filter_pill.dart';

const _homeCats = [
  'Cervejas',
  'Caipirinhas',
  'Petiscos',
  'Porções',
  'Drinks',
  'Sobremesas',
];

/// Home do cliente: header + "Hypados perto de você" + categorias +
/// "Ofertas do dia" + card promo. Fiel ao design.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _soon(BuildContext context, String label) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.ink,
          content: Text(
            'Filtro "$label" — em breve nesta prévia',
            style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.dune),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ests = (ref.watch(establishmentsProvider).asData?.value ?? kEstablishments).take(5).toList();
    final offers = (ref.watch(menuProvider(kDemoSlug)).asData?.value ?? kMenu)
        .where((m) => m.hasOffer)
        .take(5)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SingleChildScrollView(
        // A barra inferior já reserva o próprio espaço; aqui só uma folga curta.
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context),
            const SizedBox(height: 16),
            _sectionHeader('Hypados perto de você', trailing: 'Ver todos', onTrailing: () => context.go('/buscar')),
            const SizedBox(height: 10),
            _hscroll(
              gap: 12,
              children: [
                for (var i = 0; i < ests.length; i++)
                  _estCard(ests[i], i + 1, () => context.go('/menu')),
              ],
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('O que vai ser hoje?'.toUpperCase(), style: AppText.homeTitle),
            ),
            const SizedBox(height: 10),
            _hscroll(
              gap: 8,
              children: [
                for (final c in _homeCats) FilterPill(label: c, onTap: () => _soon(context, c)),
              ],
            ),
            const SizedBox(height: 16),
            _offersHeader(),
            const SizedBox(height: 10),
            _hscroll(
              gap: 12,
              children: [
                for (final m in offers) _offerCard(m, () => context.go('/menu')),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Jurandir · seu garçom digital'.toUpperCase(),
                style: AppText.body(
                  size: 10,
                  weight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: AppColors.inkA(0.3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Header ----
  Widget _header(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 18, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Você está em',
                    style: AppText.body(size: 12, color: AppColors.duneA(0.55)),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Symbols.location_on, size: 16, color: AppColors.coral),
                      const SizedBox(width: 6),
                      Text(
                        'Praia Brava, Itajaí',
                        style: AppText.display(size: 17, letterSpacing: -0.2, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
              GestureDetector(onTap: () => context.go('/perfil'), child: const Avatar('?')),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => context.go('/buscar'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.duneA(0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  Icon(Symbols.search, size: 17, color: AppColors.duneA(0.6)),
                  const SizedBox(width: 10),
                  Text(
                    'Buscar bar, quiosque ou produto…',
                    style: AppText.body(size: 14, weight: FontWeight.w600, color: AppColors.duneA(0.6)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Section header ----
  Widget _sectionHeader(String title, {String? trailing, VoidCallback? onTrailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title.toUpperCase(), style: AppText.homeTitle),
          if (trailing != null)
            GestureDetector(
              onTap: onTrailing,
              child: Text(
                trailing,
                style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.coralDeep),
              ),
            ),
        ],
      ),
    );
  }

  Widget _offersHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Ofertas do dia'.toUpperCase(), style: AppText.homeTitle),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.amber,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Quiosque do Mar'.toUpperCase(),
              style: AppText.body(size: 11, weight: FontWeight.w700, color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Horizontal scroller ----
  Widget _hscroll({required List<Widget> children, double gap = 12}) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            children[i],
          ],
        ],
      ),
    );
  }

  // ---- Establishment card (200px) ----
  Widget _estCard(Establishment e, int rank, VoidCallback onTap) {
    final top3 = rank <= 3;
    return SizedBox(
      width: 200,
      child: BrutalCard(
        radius: 18,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: top3 ? AppColors.amber : AppColors.inkA(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$rankº',
                    style: AppText.display(size: 14, color: top3 ? AppColors.ink : AppColors.inkA(0.5)),
                  ),
                ),
                _openChip(e.open),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              e.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.display(size: 16, weight: FontWeight.w700, letterSpacing: -0.2, height: 1.1),
            ),
            const SizedBox(height: 3),
            Text(
              e.location,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.5)),
            ),
            const SizedBox(height: 8),
            _ratingRow(e),
          ],
        ),
      ),
    );
  }

  Widget _openChip(bool open) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: open ? AppColors.successBg : AppColors.inkA(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        (open ? 'aberto' : 'fechado').toUpperCase(),
        style: AppText.body(
          size: 10,
          weight: FontWeight.w700,
          color: open ? AppColors.successText : AppColors.inkA(0.5),
        ),
      ),
    );
  }

  Widget _ratingRow(Establishment e) {
    return Row(
      children: [
        const Icon(Symbols.star, size: 14, color: AppColors.amber, fill: 1),
        const SizedBox(width: 4),
        Text(e.rating.toStringAsFixed(1), style: AppText.body(size: 12, weight: FontWeight.w700)),
        const SizedBox(width: 4),
        Text(
          '· ${groupThousands(e.orders)} pedidos',
          style: AppText.body(size: 12, weight: FontWeight.w500, color: AppColors.inkA(0.4)),
        ),
      ],
    );
  }

  // ---- Offer card (150px) ----
  Widget _offerCard(MenuItem m, VoidCallback onTap) {
    final off = ((1 - m.price / m.oldPrice!) * 100).round();
    return SizedBox(
      width: 150,
      child: BrutalCard(
        radius: 18,
        clip: true,
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 88,
                  width: double.infinity,
                  color: const Color(0xFFE2E8F0),
                  child: Image.network(
                    m.photoUrl,
                    height: 88,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.coralDeep,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '-$off%',
                      style: AppText.body(size: 10, weight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(size: 13, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        money(m.oldPrice!),
                        style: AppText.body(size: 10, color: AppColors.inkA(0.35))
                            .copyWith(decoration: TextDecoration.lineThrough),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        money(m.price),
                        style: AppText.body(size: 14, weight: FontWeight.w800, color: AppColors.coralDeep),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}
