import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_language.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'brutal_card.dart';
import 'segmented_control.dart';

/// Card "Idioma" (Português / English) — usado no perfil do cliente e na conta
/// do estabelecimento. Guarda no aparelho (SharedPreferences).
class LanguageSelector extends ConsumerWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    const langs = AppLanguage.values;
    return BrutalCard(
      radius: 14,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedControl(
            segments: [for (final l in langs) l.label],
            selected: langs.indexOf(lang),
            onChanged: (i) => ref.read(appLanguageProvider.notifier).set(langs[i]),
          ),
          // O app ainda é só em português: avisa (em inglês) quem escolheu English.
          if (lang == AppLanguage.en) ...[
            const SizedBox(height: 10),
            Text('English translation is coming soon — the app is still in Portuguese for now.',
                style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
          ],
        ],
      ),
    );
  }
}
