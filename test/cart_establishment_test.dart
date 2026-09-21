import 'package:flutter_test/flutter_test.dart';
import 'package:jurandir/features/cart/cart_controller.dart';

// Regra: um pedido é de UM estabelecimento só. Adicionar item de outro bar num
// carrinho que já tem itens deve conflitar (pedir pra limpar antes).
void main() {
  test('carrinho vazio nunca conflita (começa um pedido novo)', () {
    expect(cartConflictsWith(null, true, 'bar-a'), isFalse);
    expect(cartConflictsWith('bar-a', true, 'bar-b'), isFalse); // vazio ignora slug antigo
  });

  test('mesmo estabelecimento não conflita', () {
    expect(cartConflictsWith('bar-a', false, 'bar-a'), isFalse);
  });

  test('estabelecimento diferente com carrinho cheio CONFLITA', () {
    expect(cartConflictsWith('bar-a', false, 'bar-b'), isTrue);
  });

  test('carrinho cheio sem slug registrado não conflita (defensivo)', () {
    expect(cartConflictsWith(null, false, 'bar-b'), isFalse);
  });
}
