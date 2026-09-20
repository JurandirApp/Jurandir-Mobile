import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/data/models.dart';
import '../../../core/data/public_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_toggle.dart';
import '../../../core/widgets/filter_pill.dart';
import '../../auth/auth_controller.dart';

const _roundings = <(String, String)>[
  ('exact', 'Exato'),
  ('end90', ',90'),
  ('end99', ',99'),
  ('whole', 'Cheio'),
];

/// Abre o sheet de ajuste de preço em massa. Espelha o modal da web:
/// seleção flexível (categoria/subcategoria/1 a 1) → % (+/-) → arredondamento
/// → incluir adicionais → prévia obrigatória → aplicar.
Future<void> showBulkAdjustSheet(
    BuildContext context, WidgetRef ref, List<PanelMenuItem> items) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.canvas,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _BulkAdjustSheet(ref: ref, items: items),
  );
}

class _BulkAdjustSheet extends StatefulWidget {
  const _BulkAdjustSheet({required this.ref, required this.items});
  final WidgetRef ref;
  final List<PanelMenuItem> items;

  @override
  State<_BulkAdjustSheet> createState() => _BulkAdjustSheetState();
}

class _BulkAdjustSheetState extends State<_BulkAdjustSheet> {
  String _cat = '';
  String _sub = '';
  final Set<String> _selected = {};
  String _dir = 'up';
  final _percentCtrl = TextEditingController();
  String _rounding = 'exact';
  bool _includeAddons = false;
  List<Map<String, dynamic>>? _preview;
  bool _busy = false;

  @override
  void dispose() {
    _percentCtrl.dispose();
    super.dispose();
  }

  List<PanelMenuItem> get _persisted =>
      widget.items.where((m) => m.dbId.isNotEmpty).toList();

  List<String> get _cats =>
      (<String>{for (final m in _persisted) m.cat}..removeWhere((c) => c.isEmpty)).toList();

  List<String> get _subs => (<String>{
        for (final m in _persisted)
          if (_cat.isEmpty || m.cat == _cat) m.sub
      }..removeWhere((s) => s.isEmpty))
          .toList();

  List<PanelMenuItem> get _filtered => _persisted
      .where((m) => (_cat.isEmpty || m.cat == _cat) && (_sub.isEmpty || m.sub == _sub))
      .toList();

  double? get _percent {
    final n = double.tryParse(_percentCtrl.text.trim().replaceAll(',', '.'));
    if (n == null || n == 0) return null;
    return _dir == 'up' ? n.abs() : -n.abs();
  }

  void _invalidate() {
    if (_preview != null) setState(() => _preview = null);
  }

  Future<void> _run(bool dryRun) async {
    final percent = _percent;
    if (percent == null || _selected.isEmpty) return;
    final token = widget.ref.read(authProvider).token;
    if (token == null) return;
    setState(() => _busy = true);
    try {
      final res = await widget.ref.read(publicApiProvider).bulkAdjustPrices(token, {
        'itemIds': _selected.toList(),
        'percent': percent,
        'rounding': _rounding,
        'includeAddons': _includeAddons,
        'dryRun': dryRun,
      });
      final changes =
          ((res['changes'] as List?) ?? const []).cast<Map<String, dynamic>>();
      if (dryRun) {
        setState(() => _preview = changes);
      } else {
        widget.ref.invalidate(establishmentMenuProvider);
        if (mounted) {
          Navigator.pop(context);
          _toast('${changes.length} ${changes.length == 1 ? 'preço ajustado' : 'preços ajustados'}');
        }
      }
    } catch (_) {
      if (mounted) _toast('Não foi possível ajustar os preços.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        content: Text(msg,
            style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.dune)),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final canPreview = _selected.isNotEmpty && _percent != null && !_busy;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.9,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.inkA(0.2), borderRadius: BorderRadius.circular(999))),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Ajustar preços em massa',
                      style: AppText.display(size: 20, letterSpacing: -0.3)),
                  const SizedBox(height: 2),
                  Text('Aplique um percentual a vários itens de uma vez.',
                      style: AppText.body(
                          size: 12, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                children: [
                  _sectionTitle('1. Selecione os itens'),
                  _pillRow(['Todas', ..._cats], _cat.isEmpty ? 'Todas' : _cat, (v) {
                    setState(() {
                      _cat = v == 'Todas' ? '' : v;
                      _sub = '';
                    });
                    _invalidate();
                  }),
                  if (_subs.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _pillRow(['Todas', ..._subs], _sub.isEmpty ? 'Todas' : _sub, (v) {
                      setState(() => _sub = v == 'Todas' ? '' : v);
                      _invalidate();
                    }),
                  ],
                  const SizedBox(height: 10),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.inkA(0.15), width: 1.5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: _filtered.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text('Nenhum item neste filtro.',
                                style: AppText.body(
                                    size: 12,
                                    weight: FontWeight.w600,
                                    color: AppColors.inkA(0.45))))
                        : ListView(
                            shrinkWrap: true,
                            children: [
                              for (final m in _filtered) _itemCheck(m),
                            ],
                          ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        _selected.isEmpty
                            ? 'Nenhum item selecionado'
                            : '${_selected.length} ${_selected.length == 1 ? 'item selecionado' : 'itens selecionados'}',
                        style: AppText.body(
                            size: 12, weight: FontWeight.w700, color: AppColors.inkA(0.6)),
                      ),
                      const Spacer(),
                      _miniBtn('Todos', () {
                        setState(() => _selected.addAll(_filtered.map((m) => m.dbId)));
                        _invalidate();
                      }),
                      const SizedBox(width: 6),
                      _miniBtn('Limpar', () {
                        setState(_selected.clear);
                        _invalidate();
                      }),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _sectionTitle('2. Defina o ajuste'),
                  Row(children: [
                    Expanded(
                      child: _pillRow(const ['Aumentar', 'Diminuir'],
                          _dir == 'up' ? 'Aumentar' : 'Diminuir', (v) {
                        setState(() => _dir = v == 'Aumentar' ? 'up' : 'down');
                        _invalidate();
                      }),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 110,
                      child: TextField(
                        controller: _percentCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => _invalidate(),
                        style: AppText.body(size: 15, weight: FontWeight.w700),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: '20',
                          suffixText: '%',
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.ink, width: 2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.ink, width: 2),
                          ),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Text('Arredondamento',
                      style: AppText.body(
                          size: 12, weight: FontWeight.w700, color: AppColors.inkA(0.6))),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final r in _roundings)
                        FilterPill(
                          label: r.$2,
                          selected: _rounding == r.$1,
                          onTap: () {
                            setState(() => _rounding = r.$1);
                            _invalidate();
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Incluir adicionais neste ajuste',
                              style: AppText.body(size: 14, weight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                              'Aplica o mesmo percentual também nos adicionais com preço '
                              '(ex.: "Bacon +R\$ 3") dos itens selecionados. Desmarcado, '
                              'os adicionais ficam intactos.',
                              style: AppText.body(
                                  size: 11.5,
                                  weight: FontWeight.w500,
                                  color: AppColors.inkA(0.5))),
                        ]),
                      ),
                      const SizedBox(width: 10),
                      AppToggle(
                          value: _includeAddons,
                          onChanged: (v) {
                            setState(() => _includeAddons = v);
                            _invalidate();
                          }),
                    ],
                  ),
                  if (_preview != null) ...[
                    const SizedBox(height: 18),
                    _sectionTitle('3. Confira e aplique'),
                    for (final c in _preview!) _previewRow(c),
                  ],
                ],
              ),
            ),
            _footer(canPreview),
          ],
        ),
      ),
    );
  }

  Widget _footer(bool canPreview) {
    final showApply = _preview != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        border: Border(top: BorderSide(color: AppColors.inkA(0.1))),
      ),
      child: Row(children: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text('Cancelar',
              style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.inkA(0.6))),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Material(
            color: showApply
                ? (_busy ? AppColors.coral.withValues(alpha: 0.6) : AppColors.coral)
                : (canPreview ? AppColors.ink : AppColors.inkA(0.3)),
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: showApply
                  ? (_busy ? null : () => _run(false))
                  : (canPreview ? () => _run(true) : null),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: Center(
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : Text(showApply ? 'Aplicar ajuste' : 'Ver prévia',
                          style: AppText.body(
                              size: 15,
                              weight: FontWeight.w800,
                              color: showApply ? Colors.white : AppColors.dune)),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _sectionTitle(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(s,
            style: AppText.body(size: 13, weight: FontWeight.w800, color: AppColors.inkA(0.7))),
      );

  Widget _pillRow(List<String> options, String sel, ValueChanged<String> onTap) {
    return SizedBox(
      height: 36,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            FilterPill(
                label: options[i], selected: options[i] == sel, onTap: () => onTap(options[i])),
          ],
        ]),
      ),
    );
  }

  Widget _itemCheck(PanelMenuItem m) {
    final on = _selected.contains(m.dbId);
    return InkWell(
      onTap: () {
        setState(() => on ? _selected.remove(m.dbId) : _selected.add(m.dbId));
        _invalidate();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(children: [
          Icon(on ? Symbols.check_box : Symbols.check_box_outline_blank,
              size: 20, color: on ? AppColors.coral : AppColors.inkA(0.35)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(m.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(size: 13.5, weight: FontWeight.w600)),
          ),
          Text(money(m.price),
              style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
        ]),
      ),
    );
  }

  Widget _previewRow(Map<String, dynamic> c) {
    final oldP = (c['oldPrice'] as num).toDouble();
    final newP = (c['newPrice'] as num).toDouble();
    final options = ((c['options'] as List?) ?? const []).cast<Map<String, dynamic>>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('${c['name']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(size: 13.5, weight: FontWeight.w600)),
          ),
          Text(money(oldP),
              style: AppText.body(size: 12, weight: FontWeight.w500, color: AppColors.inkA(0.4))
                  .copyWith(decoration: TextDecoration.lineThrough)),
          const SizedBox(width: 6),
          const Icon(Symbols.arrow_forward, size: 14, color: AppColors.ink),
          const SizedBox(width: 6),
          Text(money(newP),
              style: AppText.body(size: 13, weight: FontWeight.w800, color: AppColors.successText)),
        ]),
        for (final o in options)
          Padding(
            padding: const EdgeInsets.only(left: 14, top: 2),
            child: Row(children: [
              Expanded(
                child: Text('adicional: ${o['name']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(
                        size: 11.5, weight: FontWeight.w500, color: AppColors.inkA(0.5))),
              ),
              Text('+${money((o['oldDelta'] as num).toDouble())}',
                  style: AppText.body(size: 11, weight: FontWeight.w500, color: AppColors.inkA(0.4))
                      .copyWith(decoration: TextDecoration.lineThrough)),
              const SizedBox(width: 6),
              Text('+${money((o['newDelta'] as num).toDouble())}',
                  style: AppText.body(
                      size: 11.5, weight: FontWeight.w700, color: AppColors.inkA(0.7))),
            ]),
          ),
      ]),
    );
  }

  Widget _miniBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration:
            BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), border: Border.all(color: AppColors.inkA(0.15), width: 1.5)),
        child: Text(label,
            style: AppText.body(size: 11.5, weight: FontWeight.w700, color: AppColors.inkA(0.7))),
      ),
    );
  }
}
