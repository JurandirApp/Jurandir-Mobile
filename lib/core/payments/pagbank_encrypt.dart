import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// Criptografia de cartão do PagBank (equivalente ao `PagSeguro.encryptCard` do
/// SDK JS), em Dart puro — sem dependência nativa.
///
/// A doc só diz "RSA". O formato abaixo foi lido do SDK oficial
/// (`pagseguro.min.js`): RSA **PKCS#1 v1.5** com a chave pública (base64 SPKI) e
/// texto `numero;cvv;mes(2);ano(4);titular;timestampMs`, saída em base64.
/// ⚠️ Validar no sandbox antes de produção (cartões de teste do PagBank).
String pagbankEncryptCard({
  required String publicKey,
  required String number,
  required String securityCode,
  required int expMonth,
  required int expYear,
  required String holder,
}) {
  final plain = [
    number.replaceAll(RegExp(r'\D'), ''),
    securityCode.trim(),
    expMonth.toString().padLeft(2, '0'),
    expYear.toString(),
    _cleanHolder(holder),
    DateTime.now().millisecondsSinceEpoch.toString(),
  ].join(';');
  final (n, e) = _parseSpki(base64.decode(publicKey.replaceAll(RegExp(r'\s'), '')));
  return base64.encode(_rsaPkcs1v15(n, e, utf8.encode(plain)));
}

/// Titular como o SDK manda: sem acento, só letras/espaços, até 30 caracteres.
String _cleanHolder(String s) {
  const from = 'ÀÁÂÃÄÅàáâãäåÈÉÊËèéêëÌÍÎÏìíîïÒÓÔÕÖòóôõöÙÚÛÜùúûüÇçÑñÝýÿ';
  const to = 'AAAAAAaaaaaaEEEEeeeeIIIIiiiiOOOOOoooooUUUUuuuuCcNnYyy';
  final buf = StringBuffer();
  for (final ch in s.trim().split('')) {
    final i = from.indexOf(ch);
    buf.write(i >= 0 ? to[i] : ch);
  }
  final clean = buf.toString().replaceAll(RegExp(r'[^A-Za-z ]'), '');
  return clean.length > 30 ? clean.substring(0, 30) : clean;
}

/// Extrai (módulo, expoente) de uma chave pública RSA em DER SubjectPublicKeyInfo:
/// SEQ { SEQ { algId }, BIT STRING { SEQ { INTEGER n, INTEGER e } } }.
(BigInt, BigInt) _parseSpki(Uint8List der) {
  final r = _Der(der);
  r.enter(0x30); // SubjectPublicKeyInfo
  r.skip(0x30); // AlgorithmIdentifier
  r.enter(0x03); // BIT STRING
  r.pos++; // bits não usados (0)
  r.enter(0x30); // RSAPublicKey
  final n = r.integer();
  final e = r.integer();
  return (n, e);
}

/// RSAES-PKCS1-v1_5: EM = 0x00 ‖ 0x02 ‖ PS (≥8 bytes aleatórios ≠ 0) ‖ 0x00 ‖ M.
Uint8List _rsaPkcs1v15(BigInt n, BigInt e, List<int> msg) {
  final k = (n.bitLength + 7) >> 3;
  if (msg.length > k - 11) throw ArgumentError('mensagem longa demais pra chave');
  final rnd = Random.secure();
  final em = Uint8List(k);
  em[1] = 0x02;
  final psEnd = k - msg.length - 1;
  for (var i = 2; i < psEnd; i++) {
    em[i] = rnd.nextInt(255) + 1; // 1..255
  }
  em[psEnd] = 0x00;
  em.setRange(psEnd + 1, k, msg);
  final c = _toBigInt(em).modPow(e, n);
  return _toBytes(c, k);
}

BigInt _toBigInt(List<int> bytes) {
  var r = BigInt.zero;
  for (final b in bytes) {
    r = (r << 8) | BigInt.from(b);
  }
  return r;
}

Uint8List _toBytes(BigInt v, int len) {
  final out = Uint8List(len);
  final mask = BigInt.from(0xff);
  for (var i = len - 1; i >= 0; i--) {
    out[i] = (v & mask).toInt();
    v = v >> 8;
  }
  return out;
}

/// Leitor DER mínimo (só o necessário pra SPKI RSA).
class _Der {
  _Der(this.b);
  final Uint8List b;
  int pos = 0;

  int _len() {
    final first = b[pos++];
    if (first < 0x80) return first;
    var len = 0;
    for (var i = 0; i < (first & 0x7f); i++) {
      len = (len << 8) | b[pos++];
    }
    return len;
  }

  void _expect(int tag) {
    if (b[pos++] != tag) throw const FormatException('chave pública inválida');
  }

  /// Entra no conteúdo do elemento (não pula o corpo).
  void enter(int tag) {
    _expect(tag);
    _len();
  }

  /// Pula o elemento inteiro.
  void skip(int tag) {
    _expect(tag);
    final len = _len();
    pos += len;
  }

  BigInt integer() {
    _expect(0x02);
    final len = _len();
    final v = _toBigInt(b.sublist(pos, pos + len));
    pos += len;
    return v;
  }
}
