import 'package:flutter/material.dart';

import '../../../core/data/seed_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_toggle.dart';
import '../../../core/widgets/dark_header.dart';
import '../../../core/widgets/filter_pill.dart';

/// Estab · Cardápio: itens com foto/preço + chave de disponibilidade.
class EstabCardapioScreen extends StatefulWidget {
  const EstabCardapioScreen({super.key});

  @override
  State<EstabCardapioScreen> createState() => _EstabCardapioScreenState();
}

class _EstabCardapioScreenState extends State<EstabCardapioScreen> {
  String _cat = 'Todos';
  final Set<int> _paused = {};

  @override
  Widget build(BuildContext context) {
    final cats = <String>['Todos', ...{for (final m in kMenu) m.category}];
    final items = _cat == 'Todos' ? kMenu : kMenu.where((m) => m.category == _cat).toList();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          const DarkHeader(eyebrow: 'Quiosque do Mar', title: 'Cardápio'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              children: [
                Text('Toque na chave para pausar um item esgotado.',
                    style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
                const SizedBox(height: 14),
                SizedBox(
                  height: 38,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var i = 0; i < cats.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          FilterPill(label: cats[i], selected: cats[i] == _cat, onTap: () => setState(() => _cat = cats[i])),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                for (final m in items) ...[
                  _itemRow(m.id, m.name, m.price, m.photoUrl),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemRow(int id, String name, double price, String photoUrl) {
    final paused = _paused.contains(id);
    return Opacity(
      opacity: paused ? 0.55 : 1,
      child: Container(
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
                width: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  image: DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.body(size: 14, weight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text.rich(TextSpan(children: [
                              TextSpan(text: money(price), style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.coralDeep)),
                              TextSpan(text: '  · ${paused ? 'Pausado' : 'À venda'}',
                                  style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.inkA(0.4))),
                            ])),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      AppToggle(
                        value: !paused,
                        onChanged: (v) => setState(() => v ? _paused.remove(id) : _paused.add(id)),
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
}
