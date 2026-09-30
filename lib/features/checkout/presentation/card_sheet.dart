import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/payments/card_tokenizer.dart';
import '../../../core/payments/pagbank_encrypt.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money.dart';

/// Resultado da tela de cartão: o `card_token` + o endereço de cobrança
/// (billing) resolvido do CEP — o antifraude do Pagar.me exige o billing.
typedef CardSheetResult = ({String token, Map<String, dynamic> billing});

/// Abre a tela de cartão (bottom sheet). Coleta os dados, tokeniza DIRETO no
/// Pagar.me — ou, com `pagbankKey`, criptografa com a chave pública do PagBank
/// (o cartão cru não passa pelo nosso backend) —, resolve o CEP de cobrança e
/// devolve {token, billing} — ou null se cancelar/falhar.
Future<CardSheetResult?> showCardSheet(
  BuildContext context, {
  required double amount,
  required bool debit,
  String? pagbankKey,
}) {
  return showModalBottomSheet<CardSheetResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.canvas,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _CardSheet(amount: amount, debit: debit, pagbankKey: pagbankKey),
  );
}

class _CardSheet extends StatefulWidget {
  const _CardSheet({required this.amount, required this.debit, this.pagbankKey});
  final double amount;
  final bool debit;
  final String? pagbankKey;

  @override
  State<_CardSheet> createState() => _CardSheetState();
}

class _CardSheetState extends State<_CardSheet> {
  final _number = TextEditingController();
  final _name = TextEditingController();
  final _exp = TextEditingController();
  final _cvv = TextEditingController();
  final _cep = TextEditingController();
  final _addrNum = TextEditingController();
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    for (final c in [_number, _name, _exp, _cvv, _cep, _addrNum]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Resolve o CEP no ViaCEP (grátis, sem chave). null se inválido/sem rede.
  Future<Map<String, dynamic>?> _lookupCep(String cep) async {
    try {
      final res = await Dio().get<Map<String, dynamic>>('https://viacep.com.br/ws/$cep/json/');
      final d = res.data;
      if (d == null || d['erro'] == true) return null;
      return d;
    } on DioException {
      return null;
    }
  }

  Future<void> _pay() async {
    if (_busy) return;
    final num = _number.text.replaceAll(RegExp(r'\D'), '');
    final name = _name.text.trim();
    final exp = _exp.text.replaceAll(RegExp(r'\D'), '');
    final cvv = _cvv.text.trim();
    final cep = _cep.text.replaceAll(RegExp(r'\D'), '');
    final addrNum = _addrNum.text.trim();

    if (!_luhnOk(num)) return setState(() => _err = 'Número do cartão inválido.');
    if (name.isEmpty) return setState(() => _err = 'Informe o nome impresso no cartão.');
    if (exp.length != 4) return setState(() => _err = 'Validade no formato MM/AA.');
    final mm = int.tryParse(exp.substring(0, 2)) ?? 0;
    final yy = int.tryParse(exp.substring(2)) ?? 0;
    if (mm < 1 || mm > 12) return setState(() => _err = 'Mês da validade inválido.');
    final year = 2000 + yy;
    final now = DateTime.now();
    if (year < now.year || (year == now.year && mm < now.month)) {
      return setState(() => _err = 'Cartão vencido.');
    }
    if (cvv.length < 3) return setState(() => _err = 'CVV inválido.');
    if (cep.length != 8) return setState(() => _err = 'CEP de cobrança inválido (8 dígitos).');
    if (addrNum.isEmpty) return setState(() => _err = 'Informe o número do endereço de cobrança.');

    setState(() {
      _busy = true;
      _err = null;
    });
    final pagbankKey = widget.pagbankKey;
    final token = pagbankKey != null
        ? _pagbankEncrypt(pagbankKey, num, cvv, mm, year, name)
        : await tokenizeCard(
            number: num,
            holderName: name,
            expMonth: mm,
            expYear: year,
            cvv: cvv,
          );
    if (!mounted) return;
    if (token == null) {
      setState(() {
        _busy = false;
        _err = 'Não foi possível validar o cartão. Confira os dados.';
      });
      return;
    }
    // Antifraude do Pagar.me exige o endereço de cobrança — resolve o CEP.
    final via = await _lookupCep(cep);
    if (!mounted) return;
    if (via == null) {
      setState(() {
        _busy = false;
        _err = 'Não encontramos esse CEP. Confira o endereço de cobrança.';
      });
      return;
    }
    final parts = [addrNum, via['logradouro'], via['bairro']]
        .map((s) => (s ?? '').toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final billing = <String, dynamic>{
      'line_1': parts.isEmpty ? cep : parts.join(', '),
      'zip_code': cep,
      'city': (via['localidade'] ?? '').toString(),
      'state': (via['uf'] ?? '').toString(),
    };
    Navigator.pop(context, (token: token, billing: billing));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.inkA(0.2), borderRadius: BorderRadius.circular(999))),
            ),
            const SizedBox(height: 16),
            Text(widget.debit ? 'Cartão de débito' : 'Cartão de crédito',
                style: AppText.display(size: 20, letterSpacing: -0.3)),
            const SizedBox(height: 4),
            Text('Seus dados vão criptografados direto pro Pagar.me.',
                style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
            const SizedBox(height: 16),
            // AutofillGroup + autofillHints: o iOS oferece o cartão salvo /
            // "Escanear cartão" — número, nome e validade autopreenchem; o
            // cliente só digita o CVV (o CVV nunca é salvo, por segurança).
            AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _field(_number, 'Número do cartão',
                      keyboard: TextInputType.number,
                      formatters: [_CardNumFormatter()],
                      hint: '0000 0000 0000 0000',
                      autofill: const [AutofillHints.creditCardNumber]),
                  const SizedBox(height: 10),
                  _field(_name, 'Nome impresso no cartão',
                      textCap: TextCapitalization.characters,
                      hint: 'COMO ESTÁ NO CARTÃO',
                      autofill: const [AutofillHints.creditCardName]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: _field(_exp, 'Validade',
                          keyboard: TextInputType.number,
                          formatters: [_ExpFormatter()],
                          hint: 'MM/AA',
                          autofill: const [AutofillHints.creditCardExpirationDate]),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _field(_cvv, 'CVV',
                          keyboard: TextInputType.number,
                          formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                          hint: '123',
                          autofill: const [AutofillHints.creditCardSecurityCode]),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text('Endereço de cobrança do cartão',
                style: AppText.body(size: 12.5, weight: FontWeight.w700, color: AppColors.inkA(0.6))),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                flex: 2,
                child: _field(_cep, 'CEP',
                    keyboard: TextInputType.number,
                    formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
                    hint: '00000000',
                    autofill: const [AutofillHints.postalCode]),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: _field(_addrNum, 'Número',
                    keyboard: TextInputType.number,
                    formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                    hint: '123'),
              ),
            ]),
            if (_err != null) ...[
              const SizedBox(height: 10),
              Text(_err!, style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.danger)),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: Material(
                color: _busy ? AppColors.coral.withValues(alpha: 0.6) : AppColors.coral,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  onTap: _busy ? null : _pay,
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: Center(
                      child: _busy
                          ? const SizedBox(
                              width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                          : Text('Pagar ${money(widget.amount)}',
                              style: AppText.body(size: 15, weight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    TextCapitalization textCap = TextCapitalization.none,
    String? hint,
    Iterable<String>? autofill,
  }) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      inputFormatters: formatters,
      textCapitalization: textCap,
      autofillHints: autofill,
      style: AppText.body(size: 15, weight: FontWeight.w700),
      onChanged: (_) {
        if (_err != null) setState(() => _err = null);
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppText.body(size: 12.5, weight: FontWeight.w600, color: AppColors.inkA(0.55)),
        hintText: hint,
        hintStyle: AppText.body(size: 14, weight: FontWeight.w500, color: AppColors.inkA(0.3)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.inkA(0.15), width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.ink, width: 2)),
      ),
    );
  }
}

/// Criptografa o cartão com a chave do PagBank. Null se a chave for inválida.
String? _pagbankEncrypt(String key, String number, String cvv, int month, int year, String holder) {
  try {
    return pagbankEncryptCard(
      publicKey: key,
      number: number,
      securityCode: cvv,
      expMonth: month,
      expYear: year,
      holder: holder,
    );
  } on Object {
    return null;
  }
}

/// Luhn: valida o dígito verificador do número do cartão (13-19 dígitos).
bool _luhnOk(String raw) {
  final d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.length < 13 || d.length > 19) return false;
  var sum = 0;
  var alt = false;
  for (var i = d.length - 1; i >= 0; i--) {
    var n = int.parse(d[i]);
    if (alt) {
      n *= 2;
      if (n > 9) n -= 9;
    }
    sum += n;
    alt = !alt;
  }
  return sum % 10 == 0;
}

/// Agrupa o número do cartão em blocos de 4.
class _CardNumFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final trimmed = digits.length > 19 ? digits.substring(0, 19) : digits;
    final buf = StringBuffer();
    for (var i = 0; i < trimmed.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(trimmed[i]);
    }
    final text = buf.toString();
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

/// Formata a validade como MM/AA.
class _ExpFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final d = newValue.text.replaceAll(RegExp(r'\D'), '');
    final t = d.length > 4 ? d.substring(0, 4) : d;
    final text = t.length >= 3 ? '${t.substring(0, 2)}/${t.substring(2)}' : t;
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
