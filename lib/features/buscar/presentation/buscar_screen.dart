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
import '../../../core/widgets/filter_pill.dart';

/// Buscar: header com busca + filtros de culinária + lista de estabelecimentos.
class BuscarScreen extends ConsumerStatefulWidget {
  const BuscarScreen({super.key});

  @override
  ConsumerState<BuscarScreen> createState() => _BuscarScreenState();
}

class _BuscarScreenState extends ConsumerState<BuscarScreen> {
  String _cat = 'Todos';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final ests = ref.watch(establishmentsProvider).asData?.value ?? kEstablishments;
    final cuisines = <String>['Todos', ...{for (final e in ests) e.cuisine}];
    final q = _query.trim().toLowerCase();
    final filtered = ests.where((e) {
      final matchCat = _cat == 'Todos' || e.cuisine == _cat;
      final matchQ = q.isEmpty ||
          '${e.name} ${e.location} ${e.cuisine}'.toLowerCase().contains(q);
      return matchCat && matchQ;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          _header(context),
          Expanded(
            child: ListView(
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
                            label: cuisines[i],
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
                    '${filtered.length} ${filtered.length == 1 ? 'lugar' : 'lugares'} · ordenados por pedidos no app',
                    style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.inkA(0.5)),
                  ),
                ),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text('Nada encontrado por aqui.',
                          style: AppText.body(size: 14, color: AppColors.inkA(0.45))),
                    ),
                  )
                else
                  for (var i = 0; i < filtered.length; i++) _resultCard(filtered[i], i + 1),
              ],
            ),
          ),
        ],
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
          Text('Buscar'.toUpperCase(),
              style: AppText.display(size: 24, letterSpacing: -0.5, color: Colors.white)),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            style: AppText.body(size: 14, color: Colors.white),
            cursorColor: AppColors.dune,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: Icon(Symbols.search, size: 18, color: AppColors.duneA(0.45)),
              hintText: 'Bar, quiosque, praia ou produto…',
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

  Widget _resultCard(Establishment e, int rank) {
    final top3 = rank <= 3;
    return GestureDetector(
      onTap: () => _openEstablishment(e),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.ink, width: 2),
        boxShadow: const [BoxShadow(color: AppColors.ink, offset: Offset(4, 4))],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 56,
              alignment: Alignment.center,
              color: top3 ? AppColors.amber : AppColors.inkA(0.06),
              child: Text('$rankº',
                  style: AppText.display(size: 16, color: top3 ? AppColors.ink : AppColors.inkA(0.5))),
            ),
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
                        _openChip(e.open),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('${e.cuisine} · ${e.location}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Symbols.star, size: 13, color: AppColors.amber, fill: 1),
                        const SizedBox(width: 4),
                        Text(e.rating.toStringAsFixed(1), style: AppText.body(size: 12, weight: FontWeight.w700)),
                        const SizedBox(width: 4),
                        Text('· ${groupThousands(e.orders)} pedidos',
                            style: AppText.body(size: 12, weight: FontWeight.w500, color: AppColors.inkA(0.4))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
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
        (open ? 'aberto' : 'fechado').toUpperCase(),
        style: AppText.body(size: 9, weight: FontWeight.w700, color: open ? AppColors.successText : AppColors.inkA(0.5)),
      ),
    );
  }
}
