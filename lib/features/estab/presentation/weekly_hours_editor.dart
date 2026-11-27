import 'package:flutter/material.dart';

import '../../../core/data/kitchen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Editor de horário semanal (7 dias × até 2 turnos `{o,c}`), o mesmo formato
/// do `weeklyHours` do bar. Usado no horário de funcionamento e no da cozinha.
/// Edita a lista [week] NO LUGAR e chama [onChanged] a cada mudança.
class WeeklyHoursEditor extends StatelessWidget {
  final WeeklyHours week;
  final VoidCallback onChanged;

  /// Texto quando o dia não tem turno (ex.: "Fechado", "Sem cozinha").
  final String closedText;

  const WeeklyHoursEditor({
    super.key,
    required this.week,
    required this.onChanged,
    this.closedText = 'Fechado',
  });

  // Ordem de exibição começando na segunda; rótulos indexados por dia (0 = Dom).
  static const _order = [1, 2, 3, 4, 5, 6, 0];
  static const _labels = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];

  static String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static TimeOfDay _parse(String hhmm) {
    final p = hhmm.split(':');
    return TimeOfDay(hour: int.tryParse(p.first) ?? 0, minute: int.tryParse(p.length > 1 ? p[1] : '0') ?? 0);
  }

  Future<void> _pickTime(BuildContext context, int day, int win, String key) async {
    final current = _parse(week[day][win][key] ?? '00:00');
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !context.mounted) return;
    week[day][win][key] = _fmt(picked);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final d in _order) _dayRow(context, d)],
    );
  }

  Widget _dayRow(BuildContext context, int day) {
    final windows = week[day];
    void addWindow() {
      windows.add({'o': '18:00', 'c': '23:00'});
      onChanged();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_labels[day], style: AppText.body(size: 14, weight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: windows.isEmpty
                ? Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(closedText,
                            style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.inkA(0.4))),
                      ),
                      const Spacer(),
                      _smallBtn('Abrir', addWindow),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var w = 0; w < windows.length; w++) _windowRow(context, day, w),
                      if (windows.length < 2)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: _smallBtn('+ 2º turno', addWindow),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _windowRow(BuildContext context, int day, int win) {
    final w = week[day][win];
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          _timeChip(w['o'] ?? '00:00', () => _pickTime(context, day, win, 'o')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('–', style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.inkA(0.5))),
          ),
          _timeChip(w['c'] ?? '00:00', () => _pickTime(context, day, win, 'c')),
          const Spacer(),
          GestureDetector(
            onTap: () {
              week[day].removeAt(win);
              onChanged();
            },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.close, size: 18, color: AppColors.inkA(0.45)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.ink, width: 1.5),
        ),
        child: Text(label, style: AppText.body(size: 15, weight: FontWeight.w800)),
      ),
    );
  }

  Widget _smallBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: AppColors.duneA(0.6), borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: AppText.body(size: 12, weight: FontWeight.w800, color: AppColors.ink)),
      ),
    );
  }
}
