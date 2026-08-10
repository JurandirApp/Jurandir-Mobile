import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Estado de autenticação: papel (client/estab/admin) + nome/e-mail.
/// Sem e-mail = não autenticado.
class AuthState {
  final String role; // client | estab | admin
  final String? name;
  final String? email;
  final String? establishmentId; // preenchido no login de estabelecimento
  final String? token; // JWT p/ rotas protegidas dos painéis

  const AuthState({this.role = 'client', this.name, this.email, this.establishmentId, this.token});

  bool get isAuthed => email != null;

  AuthState copyWith({String? role, String? name, String? email, String? establishmentId, String? token}) =>
      AuthState(
        role: role ?? this.role,
        name: name ?? this.name,
        email: email ?? this.email,
        establishmentId: establishmentId ?? this.establishmentId,
        token: token ?? this.token,
      );
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  void login({
    required String role,
    String? name,
    required String email,
    String? establishmentId,
    String? token,
  }) => state = AuthState(role: role, name: name, email: email, establishmentId: establishmentId, token: token);

  void logout() => state = const AuthState();

  void setName(String name) => state = state.copyWith(name: name);
}

final authProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
