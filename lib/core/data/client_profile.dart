import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'onboarding_controller.dart';

/// Perfil local do cliente: nome, telefone, CPF e ID anônimo.
/// Persiste em shared_preferences — não existe conta/login no servidor, mas
/// nome, telefone, CPF e clientId são enviados junto de cada pedido (o Pagar.me
/// exige o CPF do pagador; o CPF é pedido só na 1ª cobrança e reusado depois).
class ClientProfile {
  final String? name;
  final String? phone;
  final String? document; // CPF (só dígitos ou mascarado)
  final String clientId;

  /// Chave secreta do aparelho pros cartões salvos (Tuna): o servidor deriva
  /// dela o "dono" dos cartões. Gerada uma vez; NUNCA logar nem mandar pra
  /// outro lugar além de `/tuna/cards/session` e da cobrança.
  final String cardKey;

  const ClientProfile({
    this.name,
    this.phone,
    this.document,
    required this.clientId,
    required this.cardKey,
  });

  /// Verifica se o perfil está completo: nome não-vazio e telefone >= 8 dígitos.
  /// (O CPF NÃO entra aqui — não bloqueia navegar, só é pedido ao pagar.)
  bool get isComplete {
    final nameOk = (name ?? '').trim().isNotEmpty;
    final phoneOk = (phone ?? '').replaceAll(RegExp(r'\D'), '').length >= 8;
    return nameOk && phoneOk;
  }

  /// CPF só com dígitos (vazio se não houver).
  String get documentDigits => (document ?? '').replaceAll(RegExp(r'\D'), '');
}

/// Notifier que gerencia o perfil local do cliente.
/// Lê e escreve em shared_preferences; gera clientId uma única vez.
class ClientProfileController extends Notifier<ClientProfile> {
  static const _kName = 'client_name';
  static const _kPhone = 'client_phone';
  static const _kDocument = 'client_document';
  static const _kId = 'client_id';
  static const _kCardKey = 'client_card_key';

  @override
  ClientProfile build() {
    final prefs = ref.watch(sharedPrefsProvider);

    // Lê ou gera o clientId de forma inline (sem uuid package).
    var id = prefs.getString(_kId);
    if (id == null || id.isEmpty) {
      id = 'c_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(0x7fffffff)}';
      prefs.setString(_kId, id);
    }
    var cardKey = prefs.getString(_kCardKey);
    if (cardKey == null || !isValidCardKey(cardKey)) {
      cardKey = generateCardKey();
      prefs.setString(_kCardKey, cardKey);
    }

    return ClientProfile(
      name: prefs.getString(_kName),
      phone: prefs.getString(_kPhone),
      document: prefs.getString(_kDocument),
      clientId: id,
      cardKey: cardKey,
    );
  }

  /// Persiste nome e telefone (trimmed); mantém CPF e clientId.
  Future<void> save(String name, String phone) async {
    final prefs = ref.read(sharedPrefsProvider);
    final trimmedName = name.trim();
    final trimmedPhone = phone.trim();
    await prefs.setString(_kName, trimmedName);
    await prefs.setString(_kPhone, trimmedPhone);
    state = ClientProfile(
      name: trimmedName,
      phone: trimmedPhone,
      document: state.document,
      clientId: state.clientId,
      cardKey: state.cardKey,
    );
  }

  /// Persiste o CPF (guardado só com dígitos); mantém o resto.
  Future<void> saveDocument(String document) async {
    final prefs = ref.read(sharedPrefsProvider);
    final digits = document.replaceAll(RegExp(r'\D'), '');
    await prefs.setString(_kDocument, digits);
    state = ClientProfile(
      name: state.name,
      phone: state.phone,
      document: digits,
      clientId: state.clientId,
      cardKey: state.cardKey,
    );
  }
}

/// Provider que expõe o controlador de perfil local.
final clientProfileProvider =
    NotifierProvider<ClientProfileController, ClientProfile>(
  ClientProfileController.new,
);

/// Gera a chave secreta dos cartões salvos: 32 bytes de `Random.secure()` em
/// base64url sem `=` (43 chars). Nunca logar.
String generateCardKey([Random? random]) {
  final r = random ?? Random.secure();
  final bytes = List<int>.generate(32, (_) => r.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

/// Mesmo formato que o servidor aceita (base64url, 32–128 chars).
bool isValidCardKey(String key) => RegExp(r'^[A-Za-z0-9_-]{32,128}$').hasMatch(key);

/// Valida um CPF (11 dígitos + dígitos verificadores). Rejeita sequências
/// repetidas (000..., 111...). Usado antes de mandar pro Pagar.me.
bool isValidCpf(String raw) {
  final d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.length != 11) return false;
  if (RegExp(r'^(\d)\1{10}$').hasMatch(d)) return false;
  int calc(int len) {
    var sum = 0;
    for (var i = 0; i < len; i++) {
      sum += int.parse(d[i]) * (len + 1 - i);
    }
    final r = (sum * 10) % 11;
    return r == 10 ? 0 : r;
  }

  return calc(9) == int.parse(d[9]) && calc(10) == int.parse(d[10]);
}
