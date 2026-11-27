import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_language.dart';
import 'brutal_card.dart';
import 'segmented_control.dart';

/// Card "Idioma" (Português / English / Español) — usado no perfil do cliente e
/// na conta do estabelecimento. Guarda no aparelho (SharedPreferences); o app
/// inteiro troca na hora.
class LanguageSelector extends ConsumerWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    const langs = AppLanguage.values;
    return BrutalCard(
      radius: 14,
      padding: const EdgeInsets.all(14),
      child: SegmentedControl(
        segments: [for (final l in langs) l.label],
        selected: langs.indexOf(lang),
        onChanged: (i) => ref.read(appLanguageProvider.notifier).set(langs[i]),
      ),
    );
  }
}
