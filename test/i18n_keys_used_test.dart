import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jurandir/l10n/i18n.dart';

/// Toda chave literal usada no código (`tr('ns.key')`, `context.tr(...)`,
/// `trn(...)`, ou guardada em listas como 'ns.key') precisa existir no pt.
void main() {
  test('chaves usadas no código existem', () {
    final re = RegExp(r"""(?:tr|trn)\(\s*'([a-zA-Z]+\.[a-zA-Z0-9_.]+)'""");
    final listRe = RegExp(r"""'((?:estab|estabMenu|estabCfg|estabOps|estabStats|admin|waiter|data|shell|menu|checkout)\.[a-zA-Z0-9_]+)'""");
    final missing = <String>{};
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.contains('l10n')) continue;
      final src = f.readAsStringSync();
      for (final m in [...re.allMatches(src), ...listRe.allMatches(src)]) {
        final key = m.group(1)!;
        final isPlural = RegExp(r"trn\(\s*'" + RegExp.escape(key) + "'").hasMatch(src);
        final ok = isPlural ? I18n.lookup('$key.other') != null : I18n.lookup(key) != null;
        if (!ok) missing.add('${f.path}: $key');
      }
    }
    expect(missing, isEmpty);
  });
}
