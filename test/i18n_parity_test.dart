import 'package:flutter_test/flutter_test.dart';
import 'package:jurandir/l10n/i18n.dart';
import 'package:jurandir/l10n/registry.dart';

void main() {
  test('todo namespace tem as mesmas chaves em pt, en e es', () {
    for (final ns in appNamespaces) {
      final pt = ns.pt.keys.toSet();
      expect(ns.en.keys.toSet(), pt, reason: '${ns.name}: chaves en ≠ pt');
      expect(ns.es.keys.toSet(), pt, reason: '${ns.name}: chaves es ≠ pt');
    }
  });

  test('placeholders {x} iguais nos 3 idiomas', () {
    for (final ns in appNamespaces) {
      for (final k in ns.pt.keys) {
        final p = I18n.placeholdersOf(ns.pt[k]!);
        expect(I18n.placeholdersOf(ns.en[k] ?? ''), p, reason: '${ns.name}.$k (en)');
        expect(I18n.placeholdersOf(ns.es[k] ?? ''), p, reason: '${ns.name}.$k (es)');
      }
    }
  });

  test('nomes de namespace únicos', () {
    final names = appNamespaces.map((n) => n.name).toList();
    expect(names.toSet().length, names.length);
  });
}
