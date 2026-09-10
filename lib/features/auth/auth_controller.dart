import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/onboarding_controller.dart' show sharedPrefsProvider;

/// Estado de autenticação: papel (client/estab/admin/waiter) + nome/e-mail +
/// establishmentId e token JWT (para as rotas protegidas dos painéis).
/// Sem e-mail = não autenticado.
class AuthState {
  final String role; // client | estab | admin | waiter
  final String? name;
  final String? email;
  final String? establishmentId;
  final String? token;

  /// Estabelecimento tem o módulo do garçom habilitado? (só faz sentido p/ role
  /// estab/waiter). Gate de UI: "marcar pronto"/fila/rastreio só aparecem quando true.
  final bool waiterModule;

  const AuthState(
      {this.role = 'client', this.name, this.email, this.establishmentId, this.token, this.waiterModule = false});

  bool get isAuthed => email != null;

  AuthState copyWith(
          {String? role, String? name, String? email, String? establishmentId, String? token, bool? waiterModule}) =>
      AuthState(
        role: role ?? this.role,
        name: name ?? this.name,
        email: email ?? this.email,
        establishmentId: establishmentId ?? this.establishmentId,
        token: token ?? this.token,
        waiterModule: waiterModule ?? this.waiterModule,
      );

  Map<String, dynamic> toJson() => {
        'role': role,
        'name': name,
        'email': email,
        'establishmentId': establishmentId,
        'token': token,
        'waiterModule': waiterModule,
      };

  factory AuthState.fromJson(Map<String, dynamic> j) => AuthState(
        role: (j['role'] as String?) ?? 'client',
        name: j['name'] as String?,
        email: j['email'] as String?,
        establishmentId: j['establishmentId'] as String?,
        token: j['token'] as String?,
        waiterModule: (j['waiterModule'] as bool?) ?? false,
      );
}

/// Sessão persistida — sobrevive a fechar o app (estab/admin/waiter não
/// deslogam ao reabrir). O token é reusado nas chamadas autenticadas dos
/// painéis.
class AuthController extends Notifier<AuthState> {
  static const _key = 'auth_session';

  @override
  AuthState build() {
    final raw = ref.watch(sharedPrefsProvider).getString(_key);
    if (raw == null) return const AuthState();
    try {
      return AuthState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AuthState();
    }
  }

  void login({
    required String role,
    String? name,
    required String email,
    String? establishmentId,
    String? token,
    bool waiterModule = false,
  }) {
    state = AuthState(
        role: role,
        name: name,
        email: email,
        establishmentId: establishmentId,
        token: token,
        waiterModule: waiterModule);
    _persist();
  }

  void logout() {
    ref.read(sharedPrefsProvider).remove(_key);
    state = const AuthState();
  }

  void setName(String name) {
    state = state.copyWith(name: name);
    _persist();
  }

  void _persist() {
    final prefs = ref.read(sharedPrefsProvider);
    if (state.email == null) {
      prefs.remove(_key);
    } else {
      prefs.setString(_key, jsonEncode(state.toJson()));
    }
  }
}

final authProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
