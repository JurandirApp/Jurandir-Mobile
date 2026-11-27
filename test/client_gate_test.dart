import 'package:flutter_test/flutter_test.dart';
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
