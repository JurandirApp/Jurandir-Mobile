import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/data/models.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/images.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/network_image.dart';
import '../../cart/cart_controller.dart';

/// Abre o detalhe do produto: foto, descrição, adicionais (com regras de
/// obrigatório/mín/máx) e quantidade. Adiciona ao carrinho — ou, se `editing`
/// for passado, substitui aquela linha (Editar item).
Future<void> showItemSheet(
  BuildContext context,
  MenuItem item, {
  CartLine? editing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.canvas,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ItemSheet(item: item, editing: editing),
  );
}

class _ItemSheet extends ConsumerStatefulWidget {
  final MenuItem item;
  final CartLine? editing;
  const _ItemSheet({required this.item, this.editing});

  @override
  ConsumerState<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends ConsumerState<_ItemSheet> {
  late int _qty;
  // groupId -> ids das opções escolhidas.
  final Map<String, Set<String>> _sel = {};

  MenuItem get _m => widget.item;
  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    _qty = widget.editing?.qty ?? 1;
    if (_isEdit) {
      for (final o in widget.editing!.options) {
        _sel.putIfAbsent(o.groupId, () => {}).add(o.optionId);
      }
    } else {
      // Pré-seleciona a 1ª opção de grupos obrigatórios de escolha única.
      for (final g in _m.groups) {
        if (g.required && g.single && g.options.isNotEmpty) {
          _sel[g.id] = {g.options.first.id};
        }
      }
    }
  }

  double get _unitPrice {
    var p = _m.price;
    for (final g in _m.groups) {
      final chosen = _sel[g.id] ?? const {};
      for (final o in g.options) {
        if (chosen.contains(o.id)) p += o.priceDelta;
      }
    }
    return p;
  }

  bool _groupValid(MenuOptionGroup g) {
    final n = _sel[g.id]?.length ?? 0;
    return n >= g.minRequired && n <= (g.maxSelect < 1 ? 1 : g.maxSelect);
  }

  bool get _valid => _m.groups.every(_groupValid);

  void _tap(MenuOptionGroup g, MenuOption o) {
    setState(() {
      final chosen = _sel.putIfAbsent(g.id, () => {});
      if (g.single) {
        // Rádio: seleciona; se opcional e já marcada, desmarca.
        if (chosen.contains(o.id) && !g.required) {
          chosen.clear();
        } else {
          _sel[g.id] = {o.id};
        }
      } else {
        // Múltipla escolha com teto no maxSelect.
        if (chosen.contains(o.id)) {
          chosen.remove(o.id);
        } else if (chosen.length < (g.maxSelect < 1 ? 1 : g.maxSelect)) {
          chosen.add(o.id);
        }
      }
    });
  }

  List<SelectedOption> _buildSelection() {
    final out = <SelectedOption>[];
    for (final g in _m.groups) {
      final chosen = _sel[g.id] ?? const {};
      for (final o in g.options) {
        if (chosen.contains(o.id)) {
          out.add(SelectedOption(
            groupId: g.id,
            groupName: g.name,
            optionId: o.id,
            name: o.name,
            priceDelta: o.priceDelta,
          ));
        }
      }
    }
    return out;
  }

  void _confirm() {
    final ctrl = ref.read(cartProvider.notifier);
    final opts = _buildSelection();
    if (_isEdit) {
      ctrl.updateLine(widget.editing!.lineId, _m, opts, _qty);
    } else {
      ctrl.addLine(_m, opts, qty: _qty);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: Container(
                    height: 220,
                    width: double.infinity,
                    color: const Color(0xFFE2E8F0),
                    child: AppNetworkImage(
                      cardImageUrl(_m.photoUrl, width: 900)!,
                      errorWidget: Center(
                        child: Icon(Symbols.restaurant, size: 40, color: AppColors.inkA(0.3)),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Symbols.close, size: 20, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_m.name, style: AppText.display(size: 22, letterSpacing: -0.3)),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (_m.oldPrice != null) ...[
                        Text(money(_m.oldPrice!),
                            style: AppText.body(size: 14, color: AppColors.inkA(0.35))
                                .copyWith(decoration: TextDecoration.lineThrough)),
                        const SizedBox(width: 8),
                      ],
                      Text(money(_m.price), style: AppText.display(size: 22, color: AppColors.coralDeep)),
                    ],
                  ),
                  if (_m.desc.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(_m.desc,
                        style: AppText.body(size: 14, height: 1.5, weight: FontWeight.w500, color: AppColors.inkA(0.7))),
                  ],
                  for (final g in _m.groups) _group(g),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Text('Quantidade', style: AppText.body(size: 14, weight: FontWeight.w700)),
                      const Spacer(),
                      _circleBtn(34, AppColors.duneA(0.6), Symbols.remove, AppColors.ink, () {
                        if (_qty > 1) setState(() => _qty--);
                      }),
                      SizedBox(width: 40, child: Text('$_qty', textAlign: TextAlign.center, style: AppText.body(size: 16, weight: FontWeight.w800))),
                      _circleBtn(34, AppColors.coral, Symbols.add, Colors.white, () => setState(() => _qty++)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _confirmBtn(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _group(MenuOptionGroup g) {
    final valid = _groupValid(g);
    final String hint;
    if (g.single) {
      hint = g.required ? 'Obrigatório' : 'Opcional';
    } else if (g.minRequired > 0) {
      hint = 'Escolha ${g.minRequired} a ${g.maxSelect}';
    } else {
      hint = 'Até ${g.maxSelect}';
    }
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(g.name.toUpperCase(),
                    style: AppText.display(size: 13, color: AppColors.inkA(0.7))),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: g.required && !valid ? AppColors.coral.withValues(alpha: 0.15) : AppColors.duneA(0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(hint,
                    style: AppText.body(
                        size: 10,
                        weight: FontWeight.w700,
                        color: g.required && !valid ? AppColors.coralDeep : AppColors.inkA(0.55))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final o in g.options) _optionRow(g, o),
        ],
      ),
    );
  }

  Widget _optionRow(MenuOptionGroup g, MenuOption o) {
    final chosen = (_sel[g.id] ?? const {}).contains(o.id);
    final IconData icon = g.single
        ? (chosen ? Symbols.radio_button_checked : Symbols.radio_button_unchecked)
        : (chosen ? Symbols.check_box : Symbols.check_box_outline_blank);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _tap(g, o),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: chosen ? AppColors.ink : AppColors.inkA(0.12), width: chosen ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: chosen ? AppColors.coral : AppColors.inkA(0.35)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(o.name, style: AppText.body(size: 14, weight: FontWeight.w600)),
            ),
            if (o.priceDelta > 0)
              Text('+ ${money(o.priceDelta)}',
                  style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.coralDeep)),
          ],
        ),
      ),
    );
  }

  Widget _confirmBtn() {
    final label = _isEdit ? 'Salvar' : 'Adicionar';
    final enabled = _valid;
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: enabled ? AppColors.coral : AppColors.inkA(0.25),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: enabled ? _confirm : null,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Center(
              child: Text('$label  •  ${money(_unitPrice * _qty)}',
                  style: AppText.body(size: 15, weight: FontWeight.w800, color: Colors.white)),
            ),
          ),
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
}
