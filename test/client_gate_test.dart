import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jurandir/core/router/app_router.dart';
import 'package:jurandir/features/auth/auth_controller.dart';
import 'package:jurandir/features/shell/client_mode.dart';

void main() {
  group('needsClientProfile', () {
    test('cliente comum: telas do cliente exigem perfil', () {
      expect(needsClientProfile('/home', staffSession: false), isTrue);
      expect(needsClientProfile('/menu', staffSession: false), isTrue);
      expect(needsClientProfile('/perfil', staffSession: false), isTrue);
      expect(needsClientProfile('/estab/pedidos', staffSession: false), isFalse);
      expect(needsClientProfile('/login', staffSession: false), isFalse);
    });

    test('equipe navega no cardápio/perfil sem perfil, mas não paga', () {
      expect(needsClientProfile('/menu', staffSession: true), isFalse);
      expect(needsClientProfile('/perfil', staffSession: true), isFalse);
      expect(needsClientProfile('/checkout', staffSession: true), isTrue);
      expect(needsClientProfile('/home', staffSession: true), isTrue);
    });

    test('modo visualização: nenhuma tela do cliente exige perfil', () {
      for (final loc in ['/home', '/menu', '/checkout', '/pedidos', '/perfil', '/buscar']) {
        expect(needsClientProfile(loc, staffSession: true, preview: true), isFalse, reason: loc);
      }
      expect(needsClientProfile('/estab/pedidos', staffSession: true, preview: true), isFalse);
    });
  });

  group('modo visualização', () {
    const estab = AuthState(role: 'estab', email: 'a@b');
    test('isPreviewActive: flag + sessão de equipe', () {
      expect(isPreviewActive(flag: true, auth: estab), isTrue);
      expect(isPreviewActive(flag: true, auth: const AuthState(role: 'waiter', email: 'a@b')), isTrue);
      expect(isPreviewActive(flag: false, auth: estab), isFalse);
      expect(isPreviewActive(flag: true, auth: const AuthState()), isFalse); // deslogou
      expect(isPreviewActive(flag: true, auth: const AuthState(role: 'admin', email: 'a@b')), isFalse);
    });

    test('previewModeProvider liga/desliga pela flag e cai sem sessão', () {
      final c = ProviderContainer(overrides: [
        authProvider.overrideWith(() => _FakeAuth(estab)),
      ]);
      addTearDown(c.dispose);
      expect(c.read(previewModeProvider), isFalse);
      c.read(previewModeFlagProvider.notifier).set(true);
      expect(c.read(previewModeProvider), isTrue);
      c.read(previewModeFlagProvider.notifier).set(false);
      expect(c.read(previewModeProvider), isFalse);
    });
  });

  group('panelReturnFor', () {
    test('estab → painel; garçom → fila; cliente/sem sessão → nada', () {
      expect(panelReturnFor(const AuthState(role: 'estab', email: 'a@b'))?.route, '/estab/pedidos');
      expect(panelReturnFor(const AuthState(role: 'waiter', email: 'a@b'))?.route, '/waiter');
      expect(panelReturnFor(const AuthState(role: 'admin', email: 'a@b')), isNull);
      expect(panelReturnFor(const AuthState(role: 'estab')), isNull); // sem e-mail = deslogado
    });
  });
}

/// Auth fixo pro teste (sem shared_preferences).
class _FakeAuth extends AuthController {
  _FakeAuth(this._s);
  final AuthState _s;
  @override
  AuthState build() => _s;
}
