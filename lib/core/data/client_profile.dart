import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'onboarding_controller.dart';

/// Perfil local do cliente: nome, telefone e ID anônimo.
/// Persiste em shared_preferences — nunca enviado para o servidor.
class ClientProfile {
  final String? name;
  final String? phone;
  final String clientId;

  const ClientProfile({
    this.name,
    this.phone,
    required this.clientId,
  });

  /// Verifica se o perfil está completo: nome não-vazio e telefone >= 8 dígitos.
  bool get isComplete {
    final nameOk = (name ?? '').trim().isNotEmpty;
    final phoneOk = (phone ?? '').replaceAll(RegExp(r'\D'), '').length >= 8;
    return nameOk && phoneOk;
  }
}

/// Notifier que gerencia o perfil local do cliente.
/// Lê e escreve em shared_preferences; gera clientId uma única vez.
class ClientProfileController extends Notifier<ClientProfile> {
  static const _kName = 'client_name';
  static const _kPhone = 'client_phone';
  static const _kId = 'client_id';

  @override
  ClientProfile build() {
    final prefs = ref.watch(sharedPrefsProvider);

    // Lê ou gera o clientId de forma inline (sem uuid package).
    var id = prefs.getString(_kId);
    if (id == null || id.isEmpty) {
      id = 'c_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(0x7fffffff)}';
      prefs.setString(_kId, id);
    }

    // Lê nome e telefone do storage.
    final name = prefs.getString(_kName);
    final phone = prefs.getString(_kPhone);

    return ClientProfile(
      name: name,
      phone: phone,
      clientId: id,
    );
  }

  /// Persiste nome e telefone (trimmed) em shared_preferences e atualiza state.
  Future<void> save(String name, String phone) async {
    final prefs = ref.read(sharedPrefsProvider);

    final trimmedName = name.trim();
    final trimmedPhone = phone.trim();

    await prefs.setString(_kName, trimmedName);
    await prefs.setString(_kPhone, trimmedPhone);

    // Atualiza estado mantendo o mesmo clientId.
    state = ClientProfile(
      name: trimmedName,
      phone: trimmedPhone,
      clientId: state.clientId,
    );
  }
}

/// Provider que expõe o controlador de perfil local.
final clientProfileProvider =
    NotifierProvider<ClientProfileController, ClientProfile>(
  ClientProfileController.new,
);
