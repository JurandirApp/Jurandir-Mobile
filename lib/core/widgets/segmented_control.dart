import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Controle segmentado (ex: "Pagar tudo / Dividir conta"). Trilho apagado,
/// segmento ativo em ink com texto areia.
class SegmentedControl extends StatelessWidget {
  final List<String> segments;
  final int selected;
  final ValueChanged<int> onChanged;

  const SegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.inkA(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (var i = 0; i < segments.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selected ? AppColors.ink : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    segments[i],
                    style: AppText.body(
                      size: 13,
                      weight: FontWeight.w700,
                      color: i == selected ? AppColors.dune : AppColors.inkA(0.55),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
