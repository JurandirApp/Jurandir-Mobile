import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/data/public_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_toggle.dart';
import '../../../core/widgets/segmented_control.dart';
import '../../auth/auth_controller.dart';
import '../spot_labels.dart';
import '../../../l10n/i18n.dart';

/// Resultado do cadastro em lote (pra tela mostrar "X criadas, Y já existiam").
typedef SpotsBatchResult = ({int created, int skipped});

/// Abre a folha "Adicionar várias" mesas. Devolve o resultado do servidor, ou
/// null se o usuário fechou sem cadastrar.
Future<SpotsBatchResult?> showSpotsBatchSheet(BuildContext context) {
  return showModalBottomSheet<SpotsBatchResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.canvas,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => const _SpotsBatchSheet(),
  );
}

class _SpotsBatchSheet extends ConsumerStatefulWidget {
  const _SpotsBatchSheet();

  @override
  ConsumerState<_SpotsBatchSheet> createState() => _SpotsBatchSheetState();
}

class _SpotsBatchSheetState extends ConsumerState<_SpotsBatchSheet> {
  int _mode = 0; // 0 = faixa, 1 = lista colada
  final _prefix = TextEditingController(text: 'Mesa');
  final _from = TextEditingController(text: '1');
  final _to = TextEditingController(text: '30');
  final _list = TextEditingController();
  bool _zeroPad = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final c in [_prefix, _from, _to, _list]) {
      c.addListener(_refresh);
    }
  }

  void _refresh() => setState(() => _error = null);

  @override
  void dispose() {
    for (final c in [_prefix, _from, _to, _list]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Nomes que serão cadastrados + motivo de bloqueio (null = pode cadastrar).
  ({List<String> labels, String? problem}) _build() {
    if (_mode == 0) {
      final from = int.tryParse(_from.text.trim());
      final to = int.tryParse(_to.text.trim());
      if (from == null || to == null) return (labels: const [], problem: tr('estabOps.batchFromTo'));
      // Conta antes de gerar: evita montar uma lista gigante por engano.
      if (rangeCount(from, to) > maxSpotBatch) {
        return (labels: const [], problem: tr('estabOps.batchMax', {'max': maxSpotBatch}));
      }
      final labels = rangeSpotLabels(prefix: _prefix.text, from: from, to: to, zeroPad: _zeroPad);
      return (labels: labels, problem: labels.isEmpty ? tr('estabOps.batchNone') : null);
    }
    final labels = parseSpotList(_list.text);
    if (labels.isEmpty) return (labels: labels, problem: tr('estabOps.batchPaste'));
    if (labels.length > maxSpotBatch) return (labels: labels, problem: tr('estabOps.batchMax', {'max': maxSpotBatch}));
    return (labels: labels, problem: null);
  }

  Future<void> _submit(List<String> labels) async {
    if (_saving) return;
    final token = ref.read(authProvider).token;
    if (token == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final r = await ref.read(publicApiProvider).addSpotsBatch(token, labels);
      if (!mounted) return;
      Navigator.pop<SpotsBatchResult>(context, (created: r.created, skipped: r.skipped));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = tr('estabOps.batchError');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final built = _build();
    final problem = _error ?? built.problem;
    final canSubmit = built.problem == null && !_saving;
    final bottom = MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 18 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('estabOps.addMany').toUpperCase(), style: AppText.display(size: 20, letterSpacing: -0.4)),
            const SizedBox(height: 4),
            Text(context.tr('estabOps.batchSub'),
                style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
            const SizedBox(height: 14),
            SegmentedControl(
              segments: [context.tr('estabOps.segSequence'), context.tr('estabOps.segPaste')],
              selected: _mode,
              onChanged: (i) => setState(() {
                _mode = i;
                _error = null;
              }),
            ),
            const SizedBox(height: 14),
            if (_mode == 0) _rangeForm() else _listForm(),
            const SizedBox(height: 14),
            _previewBox(built.labels),
            if (problem != null) ...[
              const SizedBox(height: 10),
              Text(problem, style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.dangerText)),
            ],
            const SizedBox(height: 14),
            AppButton.primary(
              label: _saving
                  ? context.tr('estabOps.registering')
                  : built.labels.isEmpty || built.problem != null
                      ? context.tr('estabOps.createTables')
                      : context.trn('estabOps.createN', built.labels.length),
              icon: Symbols.add,
              onPressed: canSubmit ? () => _submit(built.labels) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _rangeForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field(context.tr('estabOps.fName'), _prefix, hint: context.tr('estabOps.prefixHint')),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _field(context.tr('estabOps.from'), _from, numeric: true)),
            const SizedBox(width: 10),
            Expanded(child: _field(context.tr('estabOps.to'), _to, numeric: true)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(context.tr('estabOps.zeroPad'),
                  style: AppText.body(size: 13, weight: FontWeight.w700)),
            ),
            AppToggle(value: _zeroPad, onChanged: (v) => setState(() => _zeroPad = v)),
          ],
        ),
      ],
    );
  }

  Widget _listForm() => _field(context.tr('estabOps.onePerLine'), _list,
      hint: context.tr('estabOps.listHint'), maxLines: 7);

  Widget _field(String label, TextEditingController c,
      {String? hint, bool numeric = false, int maxLines = 1}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(maxLines > 1 ? 14 : 999),
      borderSide: const BorderSide(color: AppColors.ink, width: 2),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: AppText.body(size: 11, weight: FontWeight.w800, letterSpacing: 0.5, color: AppColors.inkA(0.5))),
        const SizedBox(height: 5),
        TextField(
          controller: c,
          maxLines: maxLines,
          minLines: maxLines > 1 ? 4 : 1,
          keyboardType: numeric ? TextInputType.number : (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
          inputFormatters: numeric ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)] : null,
          style: AppText.body(size: 13, weight: FontWeight.w600),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.inkA(0.35)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            enabledBorder: border,
            focusedBorder: border,
          ),
        ),
      ],
    );
  }

  /// Prévia dos nomes (até 40 chips + "+N").
  Widget _previewBox(List<String> labels) {
    const shown = 40;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inkA(0.12), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.trn('estabOps.preview', labels.length),
              style: AppText.body(size: 12, weight: FontWeight.w800, color: AppColors.inkA(0.6))),
          const SizedBox(height: 8),
          if (labels.isEmpty)
            Text('—', style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.inkA(0.4)))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final l in labels.take(shown)) _chip(l),
                if (labels.length > shown) _chip('+${labels.length - shown}', muted: true),
              ],
            ),
        ],
      ),
    );
  }

  Widget _chip(String text, {bool muted = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: muted ? AppColors.inkA(0.06) : AppColors.duneA(0.5),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text, style: AppText.body(size: 11.5, weight: FontWeight.w700, color: AppColors.inkA(0.8))),
      );
}
