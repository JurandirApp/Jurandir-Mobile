// Tradução do app (pt padrão, en, es) — sem dependências novas.
//
// Como funciona (detalhes em docs/app-i18n.md):
// - Cada área do app tem um arquivo de namespace em `lib/l10n/ns/<area>.dart`
//   com um [I18nNamespace] (mapas pt/en/es lado a lado).
// - `lib/l10n/registry.dart` lista os namespaces. Adicionar área nova = criar o
//   arquivo e acrescentar UMA linha no registro.
// - Nos widgets: `context.tr('checkout.pay', {'value': money(x)})` e
//   `context.trn('pedidos.items', n)` (plural). Fora de widget (controllers,
//   exceções): `tr('ns.key')` usa o idioma atual global.
// - Chave faltando em en/es cai no pt; faltando no pt devolve a própria chave
//   (só avisa no console em debug).

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'registry.dart';

/// Um bloco de textos de uma área (ex.: 'checkout'). As chaves NÃO levam o
/// prefixo do namespace: em `checkout` a chave 'pay' é usada como
/// 'checkout.pay'. Plurais usam sufixos `.zero` (opcional), `.one`, `.other`.
class I18nNamespace {
  final String name;
  final Map<String, String> pt;
  final Map<String, String> en;
  final Map<String, String> es;
  const I18nNamespace(this.name, {required this.pt, required this.en, required this.es});

  Map<String, String> forCode(String code) => switch (code) {
        'en' => en,
        'es' => es,
        _ => pt,
      };
}

/// Estado global do idioma + lookup. O app liga isto ao `appLanguageProvider`
/// (ver `lib/app.dart`); testes podem chamar [I18n.setLanguage] direto.
class I18n {
  I18n._();

  static const supportedCodes = ['pt', 'en', 'es'];
  static const fallbackCode = 'pt';

  static String _code = fallbackCode;
  static Map<String, I18nNamespace>? _cache;
  static Map<String, I18nNamespace> get _namespaces =>
      _cache ??= {for (final ns in appNamespaces) ns.name: ns};

  /// Código do idioma atual ('pt' | 'en' | 'es').
  static String get code => _code;

  static void setLanguage(String code) {
    _code = supportedCodes.contains(code) ? code : fallbackCode;
  }

  /// Registra namespaces extras em tempo de execução (testes). Os do app vêm
  /// de `appNamespaces` (`registry.dart`) automaticamente.
  static void register(Iterable<I18nNamespace> namespaces) {
    for (final ns in namespaces) {
      _namespaces[ns.name] = ns;
    }
  }

  static Iterable<I18nNamespace> get namespaces => _namespaces.values;

  /// Texto cru (sem interpolação) para [key] = 'namespace.chave', ou null.
  static String? lookup(String key, {String? code}) {
    final dot = key.indexOf('.');
    if (dot <= 0) return null;
    final ns = _namespaces[key.substring(0, dot)];
    if (ns == null) return null;
    final k = key.substring(dot + 1);
    return ns.forCode(code ?? _code)[k] ?? ns.pt[k];
  }

  /// Traduz [key] no idioma atual (ou [code]) e preenche `{nome}` com [args].
  static String t(String key, [Map<String, Object?>? args, String? code]) {
    final raw = lookup(key, code: code);
    if (raw == null) {
      if (kDebugMode) debugPrint('[i18n] chave ausente: $key');
      return key;
    }
    return interpolate(raw, args);
  }

  /// Plural simples: usa `key.zero` (se existir e count == 0), `key.one`
  /// (count == 1) ou `key.other`. `{count}` fica disponível no texto.
  static String plural(String key, num count, [Map<String, Object?>? args, String? code]) {
    final all = {'count': count, ...?args};
    if (count == 0 && lookup('$key.zero', code: code) != null) return t('$key.zero', all, code);
    if (count == 1) return t('$key.one', all, code);
    return t('$key.other', all, code);
  }

  static final _placeholder = RegExp(r'\{(\w+)\}');

  static String interpolate(String raw, Map<String, Object?>? args) {
    if (args == null || args.isEmpty) return raw;
    return raw.replaceAllMapped(_placeholder, (m) {
      final name = m.group(1)!;
      return args.containsKey(name) ? '${args[name] ?? ''}' : m.group(0)!;
    });
  }

  /// Nomes de placeholder `{x}` usados num texto (para testes de consistência).
  static Set<String> placeholdersOf(String raw) =>
      _placeholder.allMatches(raw).map((m) => m.group(1)!).toSet();
}

/// Traduz fora de widgets (controllers, exceções, modelos).
String tr(String key, [Map<String, Object?>? args]) => I18n.t(key, args);

/// Plural fora de widgets.
String trn(String key, num count, [Map<String, Object?>? args]) => I18n.plural(key, count, args);

/// Publica o idioma atual na árvore: quem usa `context.tr` reconstrói quando
/// ele muda.
class I18nScope extends InheritedWidget {
  final String code;
  const I18nScope({super.key, required this.code, required super.child});

  @override
  bool updateShouldNotify(I18nScope oldWidget) => oldWidget.code != code;
}

extension I18nContext on BuildContext {
  String _langCode() =>
      dependOnInheritedWidgetOfExactType<I18nScope>()?.code ?? I18n.code;

  /// `context.tr('checkout.pay', {'value': 'R\$ 10,00'})`.
  String tr(String key, [Map<String, Object?>? args]) => I18n.t(key, args, _langCode());

  /// `context.trn('pedidos.items', 3)` → plural com `{count}`.
  String trn(String key, num count, [Map<String, Object?>? args]) =>
      I18n.plural(key, count, args, _langCode());

  /// Código do idioma atual ('pt' | 'en' | 'es'), registrando dependência.
  String get langCode => _langCode();
}

/// Força TODOS os widgets a reconstruírem (troca de idioma é rara): cobre textos
/// resolvidos com `tr()` global durante o build, que não registram dependência.
void rebuildAllWidgets(Element root) {
  void visit(Element e) {
    e.markNeedsBuild();
    e.visitChildren(visit);
  }

  root.visitChildren(visit);
}

// ── Datas (nomes de mês/dia) ─────────────────────────────────────────────────

const _months = {
  'pt': ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'],
  'en': ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'],
  'es': ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'],
};

const _monthsShort = {
  'pt': ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'],
  'en': ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
  'es': ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'],
};

// Índice 0 = segunda (DateTime.monday == 1).
const _weekdays = {
  'pt': ['segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'],
  'en': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
  'es': ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'],
};

/// Nome do mês (1–12) no idioma atual (ou [code]).
String monthName(int month, {bool short = false, String? code}) {
  final c = code ?? I18n.code;
  final list = (short ? _monthsShort : _months)[c] ?? (short ? _monthsShort : _months)['pt']!;
  return list[(month - 1).clamp(0, 11)];
}

/// Nome do dia da semana (DateTime.weekday, 1 = segunda) no idioma atual.
String weekdayName(int weekday, {String? code}) {
  final c = code ?? I18n.code;
  final list = _weekdays[c] ?? _weekdays['pt']!;
  return list[(weekday - 1).clamp(0, 6)];
}

/// "27 de novembro" / "November 27" / "27 de noviembre".
String dayMonth(DateTime d, {bool short = false, String? code}) {
  final c = code ?? I18n.code;
  final m = monthName(d.month, short: short, code: c);
  return c == 'en' ? '$m ${d.day}' : (short ? '${d.day} $m' : '${d.day} de $m');
}
