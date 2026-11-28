import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/data/kitchen.dart';
import '../../../core/data/models.dart';
import '../../../core/data/public_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../auth/auth_controller.dart';
import 'weekly_hours_editor.dart';
import '../../../l10n/i18n.dart';

/// Categorias distintas do cardápio do bar (na ordem em que aparecem), mais as
/// já marcadas como cozinha que não existem mais no cardápio — pra não sumirem
/// sem o dono ver. Pura, testável.
List<String> kitchenCategoryOptions(List<PanelMenuItem> menu, List<String> saved) {
  final out = <String>[];
  for (final c in [...menu.map((m) => m.cat.trim()), ...saved]) {
    if (c.isNotEmpty && !out.contains(c)) out.add(c);
  }
  return out;
}

/// Estab · Perfil · Horário da cozinha: quais categorias são comida e em que
/// horário a cozinha funciona. Fora do horário, os itens dessas categorias
/// ficam "Cozinha fechada" pro cliente; bebidas seguem normais.
/// Salva em `POST /establishment/kitchen`; se falhar, volta ao último salvo.
class EstabKitchenCard extends ConsumerStatefulWidget {
  const EstabKitchenCard({super.key});

  @override
  ConsumerState<EstabKitchenCard> createState() => _EstabKitchenCardState();
}

class _EstabKitchenCardState extends ConsumerState<EstabKitchenCard> {
  KitchenConfig? _saved; // último estado confirmado pelo servidor
  WeeklyHours? _week; // cópia em edição (null = formato desconhecido)
  Set<String> _cats = {};
  bool _saving = false;

  void _load(KitchenConfig cfg) {
    _saved = cfg;
    _week = cfg.hours == null ? null : copyWeek(cfg.hours!);
    _cats = cfg.categories.toSet();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        content: Text(msg, style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.dune)),
      ));
  }

  Future<void> _save(List<String> options) async {
    final saved = _saved;
    final token = ref.read(authProvider).token;
    if (_saving || saved == null || token == null) return;
    // Mantém a ordem do cardápio nas categorias enviadas.
    final next = saved.copyWith(
      hours: _week == null ? null : copyWeek(_week!),
      categories: [for (final c in options) if (_cats.contains(c)) c],
    );
    setState(() => _saving = true);
    try {
      await ref.read(publicApiProvider).saveEstablishmentKitchen(token, next);
      if (!mounted) return;
      setState(() => _saved = next);
      _toast(tr('estabOps.kitchenSaved'));
    } catch (_) {
      if (!mounted) return;
      // Rollback: a tela volta a mostrar o que está de fato no servidor.
      setState(() => _load(saved));
      _toast(tr('estabOps.kitchenSaveError'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(establishmentKitchenProvider);
    final menu = ref.watch(establishmentMenuProvider).asData?.value ?? const <PanelMenuItem>[];
    return BrutalCard(
      padding: const EdgeInsets.all(16),
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: CircularProgressIndicator(color: AppColors.coral, strokeWidth: 3)),
        ),
        // Servidor antigo (sem a rota) ou falha: não deixa editar às cegas.
        error: (_, _) => _unavailable(),
        data: (cfg) {
          if (_saved == null) _load(cfg);
          return _form(kitchenCategoryOptions(menu, _saved!.categories));
        },
      ),
    );
  }

  Widget _title() => Row(
        children: [
          const Icon(Symbols.skillet, size: 18, color: AppColors.coralDeep),
          const SizedBox(width: 8),
          Text(context.tr('estabOps.kitchenTitle'),
              style: AppText.body(size: 11, weight: FontWeight.w800, color: AppColors.inkA(0.55), letterSpacing: 0.4)),
        ],
      );

  Widget _unavailable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(),
        const SizedBox(height: 8),
        Text(context.tr('estabOps.kitchenLoadError'),
            style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => ref.invalidate(establishmentKitchenProvider),
          child: Text(context.tr('estabOps.retry'),
              style: AppText.body(size: 13, weight: FontWeight.w800, color: AppColors.coralDeep)),
        ),
      ],
    );
  }

  Widget _form(List<String> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(),
        const SizedBox(height: 4),
        Text(context.tr('estabOps.kitchenHint'),
            style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.4))),
        const SizedBox(height: 12),
        Text(context.tr('estabOps.kitchenCats'),
            style: AppText.body(size: 13, weight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (options.isEmpty)
          Text(context.tr('estabOps.kitchenCatsEmpty'),
              style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.inkA(0.45)))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final c in options) _catChip(c)],
          ),
        const SizedBox(height: 16),
        Text(context.tr('estabOps.hours'), style: AppText.body(size: 13, weight: FontWeight.w800)),
        const SizedBox(height: 4),
        if (_week != null)
          WeeklyHoursEditor(
            week: _week!,
            closedText: context.tr('estabOps.noKitchen'),
            onChanged: () => setState(() {}),
          )
        else
          // Formato que o app não conhece: não edita nem sobrescreve.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(context.tr('estabOps.kitchenUnknownFmt'),
                style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
          ),
        const SizedBox(height: 14),
        AppButton.primary(
          label: _saving ? context.tr('estabOps.saving') : context.tr('estabOps.saveKitchen'),
          onPressed: () => _save(options),
        ),
      ],
    );
  }

  Widget _catChip(String c) {
    final on = _cats.contains(c);
    return GestureDetector(
      onTap: () => setState(() => on ? _cats.remove(c) : _cats.add(c)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: on ? AppColors.ink : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? AppColors.ink : AppColors.inkA(0.2), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (on) ...[
              const Icon(Symbols.check, size: 14, color: AppColors.dune),
              const SizedBox(width: 4),
            ],
            Text(c,
                style: AppText.body(
                    size: 12, weight: FontWeight.w800, color: on ? AppColors.dune : AppColors.inkA(0.7))),
          ],
        ),
      ),
    );
  }
}
