import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/payments/card_tokenizer.dart';
import '../../../core/payments/pagbank_encrypt.dart';
import '../../../core/payments/threeds.dart';
import '../../../core/payments/tuna_tokenizer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money.dart';

/// Resultado da tela de cartão: o `card_token` + o endereço de cobrança
/// (billing) resolvido do CEP — o antifraude do Pagar.me exige o billing.
/// Com `wantRaw` (débito PagBank, 3DS) vêm também o cartão cru e o endereço
/// estruturado — SÓ em memória, pro SDK do banco; nunca logar/persistir — e
/// `freshToken`, que recriptografa o cartão (PagBank) na hora de cobrar: o
/// blob tem timestamp e o 3DS pode levar minutos depois da folha fechar.
/// Com `tuna` a folha NÃO tokeniza (`token` vazio, sem billing): a sessão da
/// Tuna é presa ao pedido, que só existe depois — `tunaTokenize` manda o cartão
/// (guardado só em memória, dentro da função) direto pra Tuna com a sessão.
/// Cartões salvos (Tuna): `tunaSavedCard` = pagar com um cartão salvo (o
/// `tunaTokenize` faz o Bind do CVV e devolve o token salvo); `tunaSaveNew` =
/// cartão novo que o cliente pediu pra salvar. Nos dois, quem chama usa a
/// sessão DO APARELHO e passa `device: true`; com `device: false` (sessão do
/// pedido) o cartão novo vai de uso único, como sempre. `authCode` (débito
/// Tuna, 3DS) vai no Generate/Bind e o token volta com os dados 3DS (`auth`).
typedef CardSheetResult = ({
  String token,
  Map<String, dynamic> billing,
  RawCard? raw,
  BillingParts? billingParts,
  String Function()? freshToken,
  Future<TunaToken?> Function(String tokenUrl, String sessionId, bool device, String? authCode)? tunaTokenize,
  bool tunaSavedCard,
  bool tunaSaveNew,
});

/// Sessão da Tuna do aparelho (cartões salvos) — `/tuna/cards/session`.
typedef TunaDeviceSession = ({String sessionId, String tokenUrl});

/// Abre a tela de cartão (bottom sheet). Coleta os dados, tokeniza DIRETO no
/// Pagar.me — ou, com `pagbankKey`, criptografa com a chave pública do PagBank
/// (o cartão cru não passa pelo nosso backend) —, resolve o CEP de cobrança e
/// devolve {token, billing} — ou null se cancelar/falhar. `wantRaw` também
/// devolve `raw`/`billingParts` (dados que a folha já coleta) pro 3DS. `tuna`
/// só valida e devolve `tunaTokenize` (nenhum outro gateway tokeniza; a Tuna
/// não usa o endereço de cobrança, então a folha nem pede).
/// `tunaCardsSession` (só Tuna): abre a sessão do aparelho pra listar/remover
/// cartões salvos e liga o "Salvar este cartão". Falhar nunca impede pagar com
/// um cartão novo.
Future<CardSheetResult?> showCardSheet(
  BuildContext context, {
  required double amount,
  required bool debit,
  String? pagbankKey,
  bool wantRaw = false,
  bool tuna = false,
  Future<TunaDeviceSession?> Function()? tunaCardsSession,
}) {
  return showModalBottomSheet<CardSheetResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.canvas,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _CardSheet(
      amount: amount,
      debit: debit,
      pagbankKey: pagbankKey,
      wantRaw: wantRaw,
      tuna: tuna,
      tunaCardsSession: tuna ? tunaCardsSession : null,
    ),
  );
}

class _CardSheet extends StatefulWidget {
  const _CardSheet({
    required this.amount,
    required this.debit,
    this.pagbankKey,
    this.wantRaw = false,
    this.tuna = false,
    this.tunaCardsSession,
  });
  final double amount;
  final bool debit;
  final String? pagbankKey;
  final bool wantRaw;
  final bool tuna;
  final Future<TunaDeviceSession?> Function()? tunaCardsSession;

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

  // Cartões salvos (Tuna). Tokens só em memória; nunca logar.
  TunaDeviceSession? _deviceSession;
  List<TunaSavedCard> _saved = const [];
  bool _savedLoading = false;
  TunaSavedCard? _selected; // null = cartão novo
  bool _saveNew = false; // consentimento (LGPD): desmarcado por padrão

  @override
  void initState() {
    super.initState();
    if (widget.tunaCardsSession != null) _loadSaved();
  }

  /// Abre a sessão do aparelho e lista os cartões salvos. Qualquer falha → sem
  /// lista (o cartão novo segue normal).
  Future<void> _loadSaved() async {
    setState(() => _savedLoading = true);
    final s = await widget.tunaCardsSession!();
    final list = s == null ? null : await tunaListCards(tokenUrl: s.tokenUrl, sessionId: s.sessionId);
    if (!mounted) return;
    setState(() {
      _savedLoading = false;
      _deviceSession = s;
      _saved = list ?? const [];
    });
  }

  /// Remove o cartão salvo na Tuna (com confirmação).
  Future<void> _remove(TunaSavedCard c) async {
    final s = _deviceSession;
    if (s == null || _busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.canvas,
        title: Text('Remover cartão?', style: AppText.display(size: 18)),
        content: Text('${c.label} será apagado deste aparelho.',
            style: AppText.body(size: 14, color: AppColors.inkA(0.75))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar', style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.inkA(0.6))),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Remover', style: AppText.body(size: 14, weight: FontWeight.w800, color: AppColors.coralDeep)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final done = await tunaDeleteCard(tokenUrl: s.tokenUrl, sessionId: s.sessionId, token: c.token);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (done) {
        _saved = _saved.where((x) => x.token != c.token).toList();
        if (_selected?.token == c.token) _selected = null;
        _err = null;
      } else {
        _err = 'Não foi possível remover o cartão agora.';
      }
    });
  }

  /// Pagar com o cartão salvo: só o CVV; o Bind é feito na hora da cobrança,
  /// com a sessão do aparelho (o CVV fica só dentro da função, em memória).
  void _paySaved(TunaSavedCard c) {
    final cvv = _cvv.text.trim();
    if (cvv.length < 3) return setState(() => _err = 'CVV inválido.');
    final CardSheetResult result = (
      token: '',
      billing: const <String, dynamic>{},
      raw: null,
      billingParts: null,
      freshToken: null,
      tunaTokenize: (tokenUrl, sessionId, device, authCode) async {
        if (!device) return null; // cartão salvo só com a sessão do aparelho
        final r = await tunaBind(
            tokenUrl: tokenUrl, sessionId: sessionId, token: c.token, cvv: cvv, authCode: authCode);
        return r.ok ? (token: c.token, brand: c.brand, auth: r.auth) : null;
      },
      tunaSavedCard: true,
      tunaSaveNew: false,
    );
    Navigator.pop(context, result);
  }

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
    final selected = _selected;
    if (widget.tuna && selected != null) return _paySaved(selected);
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
    if (widget.tuna) {
      // Tuna: tokeniza depois, com a sessão do pedido. O cartão fica só dentro
      // da função (memória); nunca logar/persistir. Salvar (opt-in): com a
      // sessão do aparelho, Generate com `singleUse: false`.
      final card = TunaCard(number: num, holder: name, expMonth: mm, expYear: year, cvv: cvv);
      final save = _saveNew && widget.tunaCardsSession != null;
      final CardSheetResult result = (
        token: '',
        billing: const <String, dynamic>{},
        raw: null,
        billingParts: null,
        freshToken: null,
        tunaTokenize: (tokenUrl, sessionId, device, authCode) => tunaGenerateToken(
            tokenUrl: tokenUrl, sessionId: sessionId, card: card, singleUse: !(save && device), authCode: authCode),
        tunaSavedCard: false,
        tunaSaveNew: save,
      );
      Navigator.pop(context, result);
      return;
    }
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
    String viaStr(String k) => (via[k] ?? '').toString().trim();
    final wantRaw = widget.wantRaw;
    final CardSheetResult result = (
      token: token,
      billing: billing,
      raw: wantRaw ? RawCard(number: num, expMonth: mm, expYear: year, holder: name) : null,
      billingParts: wantRaw
          ? BillingParts(
              street: viaStr('logradouro'),
              number: addrNum,
              complement: viaStr('bairro'),
              city: viaStr('localidade'),
              state: viaStr('uf'),
              postalCode: cep,
            )
          : null,
      // Recriptografa com a mesma chave (e o CVV, só em memória) na hora da
      // cobrança; se falhar, fica o token original.
      freshToken: wantRaw && pagbankKey != null
          ? () => _pagbankEncrypt(pagbankKey, num, cvv, mm, year, name) ?? token
          : null,
      tunaTokenize: null,
      tunaSavedCard: false,
      tunaSaveNew: false,
    );
    Navigator.pop(context, result);
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
            Text('Seus dados são criptografados no celular e enviados direto pro processador do pagamento.',
                style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
            const SizedBox(height: 16),
            // Cartões salvos deste aparelho (Tuna). Carregando/falhou → nada
            // aparece além da linha de "carregando"; o cartão novo segue normal.
            if (_savedLoading)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(children: [
                  SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.inkA(0.4))),
                  const SizedBox(width: 8),
                  Text('Buscando cartões salvos…',
                      style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
                ]),
              ),
            if (_saved.isNotEmpty) ...[
              Text('Cartões salvos',
                  style: AppText.body(size: 12.5, weight: FontWeight.w700, color: AppColors.inkA(0.6))),
              const SizedBox(height: 8),
              for (final c in _saved) ...[
                _savedTile(c),
                const SizedBox(height: 8),
              ],
              _optionTile(
                selected: _selected == null,
                onTap: () => setState(() {
                  _selected = null;
                  _err = null;
                }),
                icon: Icons.add_card_rounded,
                label: 'Usar um cartão novo',
              ),
              const SizedBox(height: 14),
            ],
            // AutofillGroup + autofillHints: o iOS oferece o cartão salvo /
            // "Escanear cartão" — número, nome e validade autopreenchem; o
            // cliente só digita o CVV (o CVV nunca é salvo, por segurança).
            if (_selected != null)
              _field(_cvv, 'CVV do cartão salvo',
                  keyboard: TextInputType.number,
                  formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                  hint: '123',
                  autofill: const [AutofillHints.creditCardSecurityCode])
            else
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
            // Salvar o cartão novo (Tuna, opt-in): só com a sessão do aparelho disponível.
            if (widget.tunaCardsSession != null && _selected == null && !_savedLoading && _deviceSession != null) ...[
              const SizedBox(height: 6),
              InkWell(
                onTap: () => setState(() => _saveNew = !_saveNew),
                borderRadius: BorderRadius.circular(10),
                child: Row(children: [
                  Checkbox(
                    value: _saveNew,
                    onChanged: (v) => setState(() => _saveNew = v ?? false),
                    activeColor: AppColors.ink,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  Expanded(
                    child: Text('Salvar este cartão para as próximas compras',
                        style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.inkA(0.75))),
                  ),
                ]),
              ),
            ],
            // A Tuna não usa o endereço de cobrança — não pede.
            if (!widget.tuna) ...[
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
            ],
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

  /// Linha de um cartão salvo: toca pra escolher; "Remover" apaga na Tuna.
  Widget _savedTile(TunaSavedCard c) {
    return _optionTile(
      selected: _selected?.token == c.token,
      onTap: () => setState(() {
        _selected = c;
        _err = null;
      }),
      icon: Icons.credit_card_rounded,
      label: c.label,
      trailing: TextButton(
        onPressed: _busy ? null : () => _remove(c),
        style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 32)),
        child: Text('Remover', style: AppText.body(size: 12.5, weight: FontWeight.w700, color: AppColors.coralDeep)),
      ),
    );
  }

  Widget _optionTile({
    required bool selected,
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    Widget? trailing,
  }) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? AppColors.ink : AppColors.inkA(0.15), width: selected ? 2 : 1.5),
      ),
      child: InkWell(
        onTap: _busy ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, trailing == null ? 12 : 4, trailing == null ? 14 : 4, trailing == null ? 12 : 4),
          child: Row(children: [
            Icon(icon, size: 20, color: AppColors.inkA(selected ? 0.9 : 0.5)),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: AppText.body(size: 14, weight: FontWeight.w700))),
            ?trailing,
          ]),
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
