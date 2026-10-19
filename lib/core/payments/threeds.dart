import 'dart:convert';

/// Sessão 3DS do PagBank devolvida pelo backend.
class ThreeDsSession {
  final String session;
  final String env; // 'PROD' | 'SANDBOX'
  final int amount; // centavos
  final Map<String, dynamic> customer;

  const ThreeDsSession({
    required this.session,
    required this.env,
    required this.amount,
    required this.customer,
  });

  factory ThreeDsSession.fromJson(Map<String, dynamic> j) => ThreeDsSession(
        session: j['session'] as String,
        env: j['env'] as String,
        amount: (j['amount'] as num).toInt(),
        customer: Map<String, dynamic>.from(j['customer'] as Map),
      );
}

/// Dados crus do cartão — só em memória, nunca logar.
class RawCard {
  final String number;
  final int expMonth;
  final int expYear;
  final String holder;
  const RawCard({
    required this.number,
    required this.expMonth,
    required this.expYear,
    required this.holder,
  });
}

class BillingParts {
  final String street, number, complement, city, state, postalCode;
  const BillingParts({
    required this.street,
    required this.number,
    required this.complement,
    required this.city,
    required this.state,
    required this.postalCode,
  });
}

/// Monta o objeto de dados do `authenticate()` do SDK 3DS do PagBank.
Map<String, dynamic> buildThreeDsData({
  required ThreeDsSession session,
  required RawCard card,
  required BillingParts billing,
}) {
  return {
    'customer': session.customer,
    'paymentMethod': {
      'type': 'DEBIT_CARD',
      'installments': 1,
      'card': {
        'number': card.number,
        'expMonth': card.expMonth.toString().padLeft(2, '0'),
        'expYear': card.expYear.toString(),
        'holder': {'name': card.holder},
      },
    },
    'amount': {'value': session.amount, 'currency': 'BRL'},
    'billingAddress': {
      'street': billing.street.isEmpty ? 'Não informado' : billing.street,
      'number': billing.number,
      if (billing.complement.isNotEmpty) 'complement': billing.complement,
      'regionCode': billing.state,
      'country': 'BRA',
      'city': billing.city,
      'postalCode': billing.postalCode,
    },
    'dataOnly': false,
  };
}

sealed class ThreeDsOutcome {
  const ThreeDsOutcome();
}

class ThreeDsAuthenticated extends ThreeDsOutcome {
  final String id;
  const ThreeDsAuthenticated(this.id);
}

class ThreeDsNotSupported extends ThreeDsOutcome {
  const ThreeDsNotSupported();
}

class ThreeDsDenied extends ThreeDsOutcome {
  const ThreeDsDenied();
}

class ThreeDsFailed extends ThreeDsOutcome {
  final String code;
  const ThreeDsFailed(this.code);
}

class ThreeDsCancelled extends ThreeDsOutcome {
  const ThreeDsCancelled();
}

/// Interpreta uma mensagem da página 3DS. Null = não-terminal (ready/challenge)
/// ou JSON inválido.
ThreeDsOutcome? parseThreeDsMessage(String raw) {
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    return null;
  }
  if (decoded is! Map) return null;
  switch (decoded['type']) {
    case 'result':
      switch (decoded['status']) {
        case 'AUTH_FLOW_COMPLETED':
          final id = decoded['id'];
          if (id is String && id.isNotEmpty) return ThreeDsAuthenticated(id);
          return const ThreeDsFailed('NO_ID');
        case 'AUTH_NOT_SUPPORTED':
          return const ThreeDsNotSupported();
        case 'CHANGE_PAYMENT_METHOD':
          return const ThreeDsDenied();
      }
      return null;
    case 'error':
      final code = decoded['code'];
      return ThreeDsFailed(code is String && code.isNotEmpty ? code : 'UNKNOWN');
  }
  return null;
}
