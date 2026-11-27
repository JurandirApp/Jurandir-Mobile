import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/data/models.dart';
import '../../../core/data/public_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/images.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../../core/widgets/filter_pill.dart';
import '../../../core/widgets/network_image.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/i18n.dart';

/// Buscar: header com busca + filtros de culinária + lista de estabelecimentos.
class BuscarScreen extends ConsumerStatefulWidget {
  const BuscarScreen({super.key});

  @override
  ConsumerState<BuscarScreen> createState() => _BuscarScreenState();
}

class _BuscarScreenState extends ConsumerState<BuscarScreen> {
  // Sentinela interna "todos" (o rótulo exibido é traduzido); as culinárias
  // vêm do servidor e não são traduzidas.
  static const _all = '__all__';
  String _cat = _all;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final estsAsync = ref.watch(establishmentsProvider);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          _header(context),
          Expanded(
            child: estsAsync.when(
              data: (ests) => _results(context, ests),
              loading: _skeletonList,
              error: (_, _) => _errorState(() => ref.invalidate(establishmentsProvider)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _results(BuildContext context, List<Establishment> ests) {
    final cuisines = <String>[_all, ...{for (final e in ests) e.cuisine}];
    final q = _query.trim().toLowerCase();
    final filtered = ests.where((e) {
      final matchCat = _cat == _all || e.cuisine == _cat;
      final matchQ = q.isEmpty ||
          '${e.name} ${e.location} ${e.cuisine}'.toLowerCase().contains(q);
      return matchCat && matchQ;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      children: [
        SizedBox(
          height: 40,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < cuisines.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  FilterPill(
                    label: cuisines[i] == _all ? context.tr('buscar.all') : cuisines[i],
                    selected: cuisines[i] == _cat,
                    onTap: () => setState(() => _cat = cuisines[i]),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
          child: Text(
            context.trn('buscar.resultsCount', filtered.length),
            style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.inkA(0.5)),
          ),
        ),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                  ests.isEmpty ? context.tr('buscar.noBars') : context.tr('buscar.nothingFound'),
                  style: AppText.body(size: 14, color: AppColors.inkA(0.45))),
            ),
          )
        else
          for (final e in filtered) _resultCard(e),
      ],
    );
  }

  Widget _skeletonList() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      children: [
        SizedBox(
          height: 40,
          child: Row(
            children: const [
              SkeletonBox(width: 70, height: 34, radius: 999),
              SizedBox(width: 8),
              SkeletonBox(width: 96, height: 34, radius: 999),
              SizedBox(width: 8),
              SkeletonBox(width: 80, height: 34, radius: 999),
            ],
          ),
        ),
        const SizedBox(height: 22),
        for (var i = 0; i < 6; i++) ...[
          _resultCardSkeleton(),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _resultCardSkeleton() {
    return BrutalCard(
      radius: 16,
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SkeletonBox(width: 72, height: 82, radius: 0),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBox(width: 140, height: 15),
                    SizedBox(height: 8),
                    SkeletonBox(width: 180, height: 11),
                    SizedBox(height: 8),
                    SkeletonBox(width: 90, height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState(VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('buscar.loadError'),
                style: AppText.body(size: 15, weight: FontWeight.w700, color: AppColors.inkA(0.7))),
            const SizedBox(height: 6),
            Text(context.tr('buscar.checkConnection'),
                textAlign: TextAlign.center,
                style: AppText.body(size: 13, color: AppColors.inkA(0.45))),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(999)),
                child: Text(context.tr('buscar.retry'),
                    style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.dune)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 20, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('buscar.title').toUpperCase(),
              style: AppText.display(size: 24, letterSpacing: -0.5, color: Colors.white)),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            style: AppText.body(size: 14, color: Colors.white),
            cursorColor: AppColors.dune,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: Icon(Symbols.search, size: 18, color: AppColors.duneA(0.45)),
              hintText: context.tr('buscar.searchHint'),
              hintStyle: AppText.body(size: 14, color: AppColors.duneA(0.45)),
              filled: true,
              fillColor: AppColors.duneA(0.1),
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: BorderSide(color: AppColors.duneA(0.2), width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: const BorderSide(color: AppColors.dune, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openEstablishment(Establishment e) {
    final slug = e.slug;
    if (slug == null) return; // item de seed sem slug real → não abre
    ref.read(selectedSlugProvider.notifier).set(slug);
    context.go('/menu');
  }

  Widget _resultCard(Establishment e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BrutalCard(
        radius: 16,
        padding: EdgeInsets.zero,
        onTap: () => _openEstablishment(e),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _thumb(e),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(e.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.display(size: 15, weight: FontWeight.w700, letterSpacing: -0.2)),
                        ),
                        const SizedBox(width: 6),
                        _openChip(e.isOpenNow),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('${e.cuisine} · ${e.location}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
                    if (e.closedLabel != null) ...[
                      const SizedBox(height: 3),
                      Text(e.closedLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(size: 11, weight: FontWeight.w700, color: AppColors.coralDeep)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Thumb do bar: tile quadrado FIXO (logo → capa → placeholder), pra toda linha
  // ter a logo do mesmo tamanho/formato — independe do aspecto da imagem.
  Widget _thumb(Establishment e) {
    // Normaliza o logo (Cloudinary) num quadrado consistente — o tile já é fixo,
    // e isto garante que o conteúdo preencha igual, sem depender da margem/tamanho
    // do arquivo enviado.
    final url = squareThumbUrl(e.imageUrl);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      child: Container(
        width: 58,
        height: 58,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.inkA(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.inkA(0.12)),
        ),
        child: url == null
            ? _thumbPlaceholder()
            : AppNetworkImage(
                url,
                errorWidget: _thumbPlaceholder(),
              ),
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Center(
      child: Icon(Symbols.storefront, size: 24, color: AppColors.inkA(0.3)),
    );
  }

  Widget _openChip(bool open) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: open ? AppColors.successBg : AppColors.inkA(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        (open ? context.tr('buscar.open') : context.tr('buscar.closed')).toUpperCase(),
        style: AppText.body(size: 9, weight: FontWeight.w700, color: open ? AppColors.successText : AppColors.inkA(0.5)),
      ),
    );
  }
}
