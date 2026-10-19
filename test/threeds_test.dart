import 'package:flutter_test/flutter_test.dart';
import 'package:jurandir/core/payments/threeds.dart';

void main() {
  final session = ThreeDsSession.fromJson({
    'session': 'sess_abc',
    'env': 'SANDBOX',
    'amount': 1550,
    'customer': {'name': 'Fulano', 'email': 'f@x.com'},
  });
  const card = RawCard(number: '4111111111111111', expMonth: 2, expYear: 2027, holder: 'FULANO');
  const billing = BillingParts(
    street: 'Rua A',
    number: '10',
    complement: 'Ap 1',
    city: 'Sao Paulo',
    state: 'SP',
    postalCode: '01001000',
  );

  group('buildThreeDsData', () {
    test('monta o payload', () {
      final d = buildThreeDsData(session: session, card: card, billing: billing);
      final pm = d['paymentMethod'] as Map<String, dynamic>;
      final c = pm['card'] as Map<String, dynamic>;
      expect(pm['type'], 'DEBIT_CARD');
      expect(pm['installments'], 1);
      expect(c['number'], '4111111111111111');
      expect(c['expMonth'], '02');
      expect(c['expYear'], '2027');
      expect(c['holder'], {'name': 'FULANO'});
      expect(d['amount'], {'value': 1550, 'currency': 'BRL'});
      expect(d['customer'], session.customer);
      expect(d['dataOnly'], false);
      final b = d['billingAddress'] as Map<String, dynamic>;
      expect(b['regionCode'], 'SP');
      expect(b['country'], 'BRA');
      expect(b['complement'], 'Ap 1');
    });

    test('street vazio vira "Não informado" e complement vazio é omitido', () {
      final d = buildThreeDsData(
        session: session,
        card: card,
        billing: const BillingParts(
            street: '', number: '1', complement: '', city: 'X', state: 'SP', postalCode: '1'),
      );
      final b = d['billingAddress'] as Map<String, dynamic>;
      expect(b['street'], 'Não informado');
      expect(b.containsKey('complement'), false);
    });
  });

  group('parseThreeDsMessage', () {
    test('AUTH_FLOW_COMPLETED com id', () {
      final o = parseThreeDsMessage('{"type":"result","status":"AUTH_FLOW_COMPLETED","id":"3DS_1"}');
      expect(o, isA<ThreeDsAuthenticated>());
      expect((o as ThreeDsAuthenticated).id, '3DS_1');
    });
    test('AUTH_FLOW_COMPLETED sem id', () {
      final o = parseThreeDsMessage('{"type":"result","status":"AUTH_FLOW_COMPLETED","id":null}');
      expect((o as ThreeDsFailed).code, 'NO_ID');
    });
    test('AUTH_NOT_SUPPORTED', () {
      expect(parseThreeDsMessage('{"type":"result","status":"AUTH_NOT_SUPPORTED","id":"x"}'),
          isA<ThreeDsNotSupported>());
    });
    test('CHANGE_PAYMENT_METHOD', () {
      expect(parseThreeDsMessage('{"type":"result","status":"CHANGE_PAYMENT_METHOD","id":null}'),
          isA<ThreeDsDenied>());
    });
    test('error', () {
      final o = parseThreeDsMessage('{"type":"error","code":"E1","message":"m"}');
      expect((o as ThreeDsFailed).code, 'E1');
    });
    test('não-terminais e inválido', () {
      expect(parseThreeDsMessage('{"type":"ready"}'), isNull);
      expect(parseThreeDsMessage('{"type":"challenge"}'), isNull);
      expect(parseThreeDsMessage('not json'), isNull);
    });
  });
}
