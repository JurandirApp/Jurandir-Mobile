import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/data/location.dart';
import '../../../core/data/models.dart';
import '../../../core/data/public_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../../core/widgets/filter_pill.dart';
import '../../../core/widgets/skeleton.dart';

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
    final estsAsync = ref.watch(establishmentsProvider);
    final offersAsync = ref.watch(offersProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SingleChildScrollView(
        // A barra inferior já reserva o próprio espaço; aqui só uma folga curta.
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context, ref.watch(userPlaceProvider).asData?.value),
            const SizedBox(height: 16),
            _sectionHeader('Hypados perto de você', trailing: 'Ver todos', onTrailing: () => context.go('/buscar')),
            const SizedBox(height: 10),
            _hypadosSection(context, ref, estsAsync),
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
            _offersBlock(context, ref, offersAsync),
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
  Widget _header(BuildContext context, String? place) {
    final hasPlace = place != null && place.isNotEmpty;
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
              Expanded(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasPlace ? 'Você está em' : 'Bares',
                    style: AppText.body(size: 12, color: AppColors.duneA(0.55)),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Symbols.location_on, size: 16, color: AppColors.coral),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          hasPlace ? place : 'Perto de você',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.display(size: 17, letterSpacing: -0.2, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              )),
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
      child: Text('Ofertas do dia'.toUpperCase(), style: AppText.homeTitle),
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

  // Largura dos cards dos carrosséis: ~2 por tela + uma espiada limpa do
  // próximo (nada de card cortado no talo). Escala com a largura da tela.
  // Clamp evita largura negativa no 1º frame (quando a tela ainda mede 0).
  double _cardW(BuildContext context) =>
      ((MediaQuery.sizeOf(context).width - 80) / 2).clamp(120.0, 260.0).toDouble();

  // ---- Establishment card ----
  Widget _estCard(Establishment e, VoidCallback onTap, double width, {double? distKm}) {
    final img = e.imageUrl;
    return SizedBox(
      width: width,
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
                  child: img == null
                      ? _estImgPlaceholder()
                      : Image.network(
                          img,
                          height: 88,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _estImgPlaceholder(),
                        ),
                ),
                Positioned(top: 8, left: 8, child: _openChip(e.open)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.display(size: 15, weight: FontWeight.w700, letterSpacing: -0.2, height: 1.1),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    e.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.5)),
                  ),
                  if (distKm != null) ...[
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Icon(Symbols.near_me, size: 13, color: AppColors.coral),
                        const SizedBox(width: 4),
                        Text('a ${fmtDistance(distKm)}',
                            style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.inkA(0.55))),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _estImgPlaceholder() =>
      Center(child: Icon(Symbols.storefront, size: 26, color: AppColors.inkA(0.3)));

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

  // ---- Offer card ----
  Widget _offerCard(Offer o, VoidCallback onTap, double width) {
    final m = o.item;
    final off = ((1 - m.price / m.oldPrice!) * 100).round();
    return SizedBox(
      width: width,
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
                  child: m.photoUrl.isEmpty
                      ? null
                      : Image.network(
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
                  const SizedBox(height: 2),
                  Text(
                    o.estName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(size: 10, weight: FontWeight.w600, color: AppColors.inkA(0.45)),
                  ),
                  const SizedBox(height: 4),
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

  // ---- Seção "Hypados" (dados reais; skeleton/vazio/erro) ----
  Widget _hypadosSection(
      BuildContext context, WidgetRef ref, AsyncValue<List<Establishment>> async) {
    final w = _cardW(context);
    final userLoc = ref.watch(userLocationProvider).asData?.value;
    final data = async.asData?.value;
    if (data == null) {
      if (async.isLoading) {
        return _hscroll(children: [for (var i = 0; i < 3; i++) _estCardSkeleton(w)]);
      }
      return _inlineNote('Não foi possível carregar os bares.',
          onRetry: () => ref.invalidate(establishmentsProvider));
    }
    if (data.isEmpty) return _inlineNote('Nenhum bar por aqui ainda.');
    // Ordena por proximidade quando temos a posição do usuário.
    final ests = sortByDistance(data, userLoc).take(6).toList();
    return _hscroll(
      gap: 12,
      children: [
        for (final e in ests)
          _estCard(e, () {
            final s = e.slug;
            if (s != null) ref.read(selectedSlugProvider.notifier).set(s);
            context.go('/menu');
          }, w, distKm: userLoc == null ? null : distanceKm(userLoc, e)),
      ],
    );
  }

  // ---- Bloco "Ofertas do dia" (some em silêncio se vazio/erro) ----
  Widget _offersBlock(BuildContext context, WidgetRef ref, AsyncValue<List<Offer>> async) {
    final w = _cardW(context);
    final data = async.asData?.value;
    final loading = data == null && async.isLoading;
    final offers = (data ?? const <Offer>[]).take(8).toList();
    if (!loading && offers.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _offersHeader(),
        const SizedBox(height: 10),
        if (loading)
          _hscroll(children: [for (var i = 0; i < 3; i++) _offerCardSkeleton(w)])
        else
          _hscroll(children: [
            for (final o in offers)
              _offerCard(o, () {
                ref.read(selectedSlugProvider.notifier).set(o.estSlug);
                context.go('/menu');
              }, w),
          ]),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _inlineNote(String msg, {VoidCallback? onRetry}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          Flexible(
            child: Text(msg,
                style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onRetry,
              child: Text('Tentar de novo',
                  style: AppText.body(size: 13, weight: FontWeight.w800, color: AppColors.coralDeep)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _estCardSkeleton(double width) {
    return SizedBox(
      width: width,
      child: BrutalCard(
        radius: 18,
        clip: true,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 88, width: double.infinity, color: AppColors.inkA(0.10)),
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 96, height: 15),
                  SizedBox(height: 8),
                  SkeletonBox(width: 76, height: 11),
                  SizedBox(height: 12),
                  SkeletonBox(width: 64, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _offerCardSkeleton(double width) {
    return SizedBox(
      width: width,
      child: BrutalCard(
        radius: 18,
        clip: true,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 88, width: double.infinity, color: AppColors.inkA(0.10)),
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 100, height: 13),
                  SizedBox(height: 8),
                  SkeletonBox(width: 70, height: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
