import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/data/client_profile.dart';
import '../../../core/data/models.dart';
import '../../../core/data/orders_controller.dart';
import '../../../core/data/public_api.dart';
import '../../../core/payments/card_tokenizer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money.dart';
import '../../auth/auth_controller.dart';
import '../../cart/cart_controller.dart';
import '../../done/presentation/done_screen.dart';
import '../../menu/presentation/item_sheet.dart';
import 'card_sheet.dart';
import 'wallet_buttons.dart';

class _PayMethod {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  const _PayMethod(this.id, this.label, this.icon, this.color);
}

const _methods = [
  _PayMethod('pix', 'Pix', Symbols.qr_code_2, AppColors.pix),
  _PayMethod('credito', 'Crédito', Symbols.credit_card, AppColors.credit),
  _PayMethod('debito', 'Débito', Symbols.account_balance_wallet, AppColors.debit),
];

/// Checkout: resumo + observação + "Pagar tudo / Dividir conta" + métodos +
/// barra de pagar.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _payMode = 'full';
  int _people = 2;
  String? _selPay;
  bool _submitting = false;
  final _obsCtrl = TextEditingController();

  @override
  void dispose() {
    _obsCtrl.dispose();
    super.dispose();
  }

  void _setPeople(int n) {
    if (n < 2 || n > 8) return;
    setState(() => _people = n);
  }

  String _genCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random();
    return 'PED-${List.generate(8, (_) => chars[r.nextInt(chars.length)]).join()}';
  }

  Future<void> _pay(double grand) async {
    if (_submitting) return;
    if (_payMode == 'split') {
      _paySplit();
      return;
    }
    if (_selPay == null) return;
    // Se o cliente não veio de um QR (sem mesa), pergunta onde ele está antes
    // de gerar o pedido — assim o bar sabe pra onde levar.
    if ((ref.read(selectedLocalProvider) ?? '').trim().isEmpty) {
      final table = await _askTable();
      if (table == null || !mounted) return; // cancelou
      ref.read(selectedLocalProvider.notifier).set(table);
    }
    // Pix (pagar tudo) → cobrança real: gera o QR e vai pra tela do Pix.
    if (_selPay == 'pix') {
      _payPix();
      return;
    }
    // Crédito/Débito (pagar tudo) → tela de cartão + tokenização Pagar.me.
    if (_selPay == 'credito' || _selPay == 'debito') {
      _payCard(grand);
      return;
    }
    _finish(incomplete: false);
  }

  /// Pergunta a mesa/guarda-sol quando o cliente entrou sem QR. Retorna o texto
  /// digitado, ou null se ele cancelar.
  Future<String?> _askTable() async {
    final ctrl = TextEditingController();
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 18 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.inkA(0.2), borderRadius: BorderRadius.circular(999))),
              ),
              const SizedBox(height: 16),
              Text('Qual a sua mesa?', style: AppText.display(size: 20, letterSpacing: -0.3)),
              const SizedBox(height: 6),
              Text('Diga onde você está pra o pedido chegar no lugar certo.',
                  style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.inkA(0.55))),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) Navigator.pop(ctx, v.trim());
                },
                style: AppText.body(size: 15, weight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Ex: Mesa 5, Guarda-sol 12',
                  hintStyle: AppText.body(size: 15, weight: FontWeight.w500, color: AppColors.inkA(0.4)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.inkA(0.15), width: 1.5)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.ink, width: 2)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: Material(
                  color: AppColors.coral,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    onTap: () {
                      final v = ctrl.text.trim();
                      if (v.isNotEmpty) Navigator.pop(ctx, v);
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      child: Center(child: Text('Confirmar', style: AppText.body(size: 15, weight: FontWeight.w800, color: Colors.white))),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    ctrl.dispose();
    return result;
  }

  /// Garante um CPF válido pro pagador (o Pagar.me exige `customer.document`).
  /// Usa o do perfil; se não houver, pede uma vez num sheet, valida e guarda.
  /// Retorna false se o usuário cancelar.
  Future<bool> _ensureCpf() async {
    if (isValidCpf(ref.read(clientProfileProvider).documentDigits)) return true;
    final cpf = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _CpfSheet(),
    );
    if (cpf == null || !mounted) return false;
    await ref.read(clientProfileProvider.notifier).saveDocument(cpf);
    return true;
  }

  /// Cria o pedido Pix (cobrança real na Pagar.me) e abre a tela do QR.
  Future<void> _payPix() async {
    if (_submitting) return;
    if (!await _ensureCpf() || !mounted) return;
    final payload = _orderPayload(method: 'PIX');
    if (payload == null) {
      // Sem estabelecimento real (demo) → mantém o fluxo antigo.
      _finish(incomplete: false);
      return;
    }
    setState(() => _submitting = true);
    await _replacePending(); // descarta um Pix anterior deste carrinho, se houver
    ClientOrder? order;
    try {
      order = await ref.read(publicApiProvider).createOrder(payload);
    } catch (_) {
      order = null;
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    if (order == null) {
      _toast('Não foi possível gerar o Pix. Tente novamente.');
      return;
    }
    final id = order.dbId;
    if (id != null) await ref.read(myOrderIdsProvider.notifier).add(id);
    if (!mounted) return;
    // Sem cobrança Pix (gateway não-Pagar.me ou sem recebedor) → confirma como
    // pedido normal em vez de travar o cliente numa tela vazia.
    if (order.pixPayload == null && order.pixQrImage == null) {
      _markPending(null);
      ref.read(cartProvider.notifier).clear();
      context.go('/done', extra: DoneArgs(incomplete: false, code: order.code));
      return;
    }
    // Mantém o carrinho (permite "Editar pedido" na tela do Pix); limpa só quando
    // o pagamento cair.
    _markPending(id);
    context.go('/pix', extra: order);
  }

  /// Crédito/Débito → tela de cartão → tokeniza DIRETO no Pagar.me (o cartão cru
  /// não passa pelo nosso backend) → cobra via `card_token`. Aprovado → /done.
  Future<void> _payCard(double grand) async {
    if (_submitting) return;
    if (!await _ensureCpf() || !mounted) return;
    if (!pagarmeCardConfigured) {
      _toast('Pagamento no cartão indisponível no momento.');
      return;
    }
    final debit = _selPay == 'debito';
    final token = await showCardSheet(context, amount: grand, debit: debit);
    if (token == null || !mounted) return; // cancelou ou a tokenização falhou
    final payload = _orderPayload(method: _enumMethod(_selPay));
    if (payload == null) {
      _finish(incomplete: false);
      return;
    }
    setState(() => _submitting = true);
    await _replacePending(); // descarta um pedido anterior deste carrinho, se houver
    final r = await ref
        .read(publicApiProvider)
        .createCardOrder(payload, token, method: debit ? 'debit' : 'credit');
    if (!mounted) return;
    setState(() => _submitting = false);
    final order = r.order;
    if (order == null || r.status == 'failed') {
      _toast('Cartão recusado. Confira os dados ou tente outro.');
      return;
    }
    final id = order.dbId;
    if (id != null) await ref.read(myOrderIdsProvider.notifier).add(id);
    if (!mounted) return;
    _markPending(null);
    ref.read(cartProvider.notifier).clear();
    context.go('/done', extra: DoneArgs(incomplete: false, code: order.code));
  }

  /// Cria o pedido real (best-effort) e vai pra confirmação. Sem backend /
  /// estabelecimento real, mantém o comportamento de demonstração (stub).
  Future<void> _finish({required bool incomplete}) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    await _replacePending();
    final order = await _submitOrder();
    if (!mounted) return;
    _markPending(null);
    ref.read(cartProvider.notifier).clear();
    context.go('/done', extra: DoneArgs(incomplete: incomplete, code: order?.code ?? _genCode()));
  }

  Future<ClientOrder?> _submitOrder() async {
    final payload = _orderPayload(method: _enumMethod(_selPay));
    if (payload == null) return null;
    try {
      final order = await ref.read(publicApiProvider).createOrder(payload);
      final id = order.dbId;
      if (id != null) await ref.read(myOrderIdsProvider.notifier).add(id);
      return order;
    } catch (_) {
      return null;
    }
  }

  /// Editar pedido = descartar o pedido pendente (não pago) antes de criar o
  /// novo. Best-effort: se o cancelamento falhar, segue mesmo assim.
  Future<void> _replacePending() async {
    final pending = ref.read(pendingOrderProvider);
    if (pending == null) return;
    // Só tira da lista local se REALMENTE cancelou; se já tinha sido pago
    // (cancel devolve false), mantém pra o cliente ainda ver o pedido.
    final cancelled = await ref.read(publicApiProvider).cancelOrder(pending);
    if (cancelled) await ref.read(myOrderIdsProvider.notifier).remove(pending);
    ref.read(pendingOrderProvider.notifier).set(null);
  }

  /// Marca o pedido recém-criado como "pendente" deste carrinho (mantém o
  /// carrinho pra permitir editar). O carrinho só é limpo quando o pagamento cai.
  void _markPending(String? id) {
    ref.read(pendingOrderProvider.notifier).set(id);
  }

  /// Enum do backend a partir do método escolhido no app.
  String _enumMethod(String? sel) {
    switch (sel) {
      case 'pix':
        return 'PIX';
      case 'debito':
        return 'DEBIT';
      case 'usdc':
        return 'USDC';
      default:
        return 'CREDIT';
    }
  }

  /// Monta o payload do pedido (estabelecimento escolhido + carrinho). Null se
  /// não houver estabelecimento real ou o carrinho estiver vazio.
  Map<String, dynamic>? _orderPayload({required String method}) {
    final ests = ref.read(establishmentsProvider).asData?.value ?? const <Establishment>[];
    final slug = ref.read(selectedSlugProvider);
    Establishment? est;
    // 1) o estabelecimento que o cliente abriu (slug); 2) senão, o primeiro real.
    for (final e in ests) {
      if (slug != null && e.slug == slug) {
        est = e;
        break;
      }
    }
    if (est == null) {
      for (final e in ests) {
        if (e.slug != null) {
          est = e;
          break;
        }
      }
    }
    if (est == null) return null;
    final lines = ref.read(cartProvider.notifier).lines;
    if (lines.isEmpty) return null;
    // Nome preferencial: perfil local do cliente (Task 2); cai pro authProvider
    // só se o perfil ainda não tiver nome preenchido.
    final profile = ref.read(clientProfileProvider);
    final authName = ref.read(authProvider).name;
    final name = (profile.name ?? '').isNotEmpty ? profile.name : authName;
    final phone = profile.phone ?? '';
    final note = _obsCtrl.text.trim();
    final table = (ref.read(selectedLocalProvider) ?? '').trim();
    return <String, dynamic>{
      'establishmentId': est.id,
      'locationLabel': table.isEmpty ? 'Pedido pelo app' : table,
      if (name != null && name.isNotEmpty) 'customerName': name,
      if (phone.isNotEmpty) 'customerPhone': phone,
      if (profile.documentDigits.isNotEmpty) 'customerDocument': profile.documentDigits,
      'clientId': profile.clientId,
      if (note.isNotEmpty) 'note': note,
      'items': [
        for (final l in lines)
          <String, dynamic>{
            if (l.item.dbId != null) 'menuItemId': l.item.dbId,
            'name': l.item.name,
            'qty': l.qty,
            'unitPrice': l.unitPrice,
            if (l.options.isNotEmpty)
              'options': [
                for (final o in l.options)
                  {'group': o.groupName, 'name': o.name, 'priceDelta': o.priceDelta},
              ],
          },
      ],
      'payment': {'kind': 'full', 'method': method, 'installments': 1},
    };
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        content: Text(msg, style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.dune)),
      ));
  }

  /// Extrai o token da carteira do resultado do plugin `pay`.
  String? _walletToken(Map<String, dynamic> result) {
    try {
      // Google Pay: paymentMethodData.tokenizationData.token (string JSON).
      final pmd = result['paymentMethodData'];
      if (pmd is Map) {
        final td = pmd['tokenizationData'];
        if (td is Map && td['token'] is String) return td['token'] as String;
      }
      // Apple Pay: chave 'token' (finalizar quando o iOS estiver de pé).
      final t = result['token'];
      if (t is String) return t;
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(cartProvider);
    final ctrl = ref.read(cartProvider.notifier);
    final ests = ref.watch(establishmentsProvider).asData?.value ?? const <Establishment>[];
    final selSlug = ref.watch(selectedSlugProvider);
    final est = ests.firstWhere(
      (e) => e.slug == selSlug,
      orElse: () => ests.firstWhere(
        (e) => e.slug != null,
        // Sem estabelecimento real ainda → placeholder neutro (sem mock). O
        // pagamento só é montado com um estabelecimento real (_orderPayload).
        orElse: () => const Establishment(
          id: '', name: '', location: '', cuisine: '', orders: 0, rating: 0, open: true,
        ),
      ),
    );
    final total = ctrl.total;
    // Taxas REAIS do bar (vêm da API; fallback 8%/10% no seed).
    final fee = total * est.platformFeePct / 100;
    final estFee = total * est.serviceFeePct / 100;
    final grand = total + fee + estFee;
    final isSplit = _payMode == 'split';
    final share = _people == 0 ? 0.0 : grand / _people;
    final canPay = isSplit ? true : _selPay != null;
    final topSafe = MediaQuery.paddingOf(context).top;

    final String payLabel;
    final Color payBg;
    if (isSplit) {
      payLabel = 'Gerar Pix da divisão — ${money(grand)}';
      payBg = AppColors.coral;
    } else {
      payLabel = 'Pagar ${money(grand)}';
      payBg = canPay ? AppColors.coral : AppColors.inkA(0.25);
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, topSafe + 20, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => context.go('/menu'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Symbols.arrow_back, size: 16, color: AppColors.inkA(0.55)),
                      const SizedBox(width: 6),
                      Text('Voltar ao cardápio',
                          style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.inkA(0.55))),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text('Confirmar pedido'.toUpperCase(), style: AppText.display(size: 22, letterSpacing: -0.5)),
                const SizedBox(height: 14),
                _summary(ctrl.lines, est, total, fee, estFee, grand),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text('Observação do pedido'.toUpperCase(),
                        style: AppText.display(size: 13, color: AppColors.inkA(0.6))),
                    const SizedBox(width: 6),
                    Text('(opcional)',
                        style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.inkA(0.35))),
                  ],
                ),
                const SizedBox(height: 10),
                _obsField(),
                const SizedBox(height: 18),
                _modeToggle(),
                const SizedBox(height: 12),
                if (!isSplit) ...[
                  // Carteira nativa só quando o bar aceita (crédito via Pagar.me);
                  // senão o token não teria como ser cobrado.
                  if (est.walletPay) _walletSection(grand),
                  _payGrid(),
                ] else
                  _splitCard(grand, share),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _payBar(context, payLabel, payBg, canPay, grand),
          ),
        ],
      ),
    );
  }

  BoxDecoration get _brutal => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.ink, width: 2),
    boxShadow: const [BoxShadow(color: AppColors.ink, offset: Offset(4, 4))],
  );

  Widget _summary(List<CartLine> cartLines, dynamic est, double total, double fee, double estFee, double grand) {
    final ctrl = ref.read(cartProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _brutal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Symbols.location_on, size: 13, color: AppColors.coral),
              const SizedBox(width: 4),
              Flexible(
                child: Text('${est.location} · ${est.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(size: 11, weight: FontWeight.w700, color: AppColors.inkA(0.5))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Linhas editáveis: +/- na quantidade, lápis (adicionais) e lixeira.
          for (final l in cartLines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(l.item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 13, weight: FontWeight.w700)),
                            ),
                            if (l.options.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => showItemSheet(context, l.item, editing: l),
                                child: Icon(Symbols.edit, size: 14, color: AppColors.coralDeep),
                              ),
                            ],
                          ],
                        ),
                        if (l.optionsLabel.isNotEmpty)
                          Text(l.optionsLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.55))),
                        Text(money(l.unitPrice), style: AppText.body(size: 11, weight: FontWeight.w500, color: AppColors.inkA(0.45))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _cartStep(Symbols.remove, () => ctrl.decLine(l.lineId)),
                  SizedBox(width: 26, child: Text('${l.qty}', textAlign: TextAlign.center, style: AppText.body(size: 13, weight: FontWeight.w800))),
                  _cartStep(Symbols.add, () => ctrl.incLine(l.lineId)),
                  const SizedBox(width: 10),
                  SizedBox(width: 58, child: Text(money(l.lineTotal), textAlign: TextAlign.right, style: AppText.body(size: 13, weight: FontWeight.w700))),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => ctrl.removeLine(l.lineId),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(Symbols.delete, size: 16, color: AppColors.inkA(0.4)),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.inkA(0.08))),
            ),
            child: Column(
              children: [
                _sumRow('Subtotal', money(total)),
                const SizedBox(height: 5),
                _sumRow('Taxa Jurandir', money(fee)),
                const SizedBox(height: 5),
                _sumRow('Taxa de serviço', money(estFee)),
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  padding: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.inkA(0.08))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total', style: AppText.body(size: 15, weight: FontWeight.w800)),
                      Text(money(grand), style: AppText.body(size: 15, weight: FontWeight.w800, color: AppColors.coralDeep)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cartStep(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.duneA(0.5), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 15, color: AppColors.ink),
      ),
    );
  }

  Widget _sumRow(String label, String value) {
    final s = AppText.body(size: 12, color: AppColors.inkA(0.6));
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: s), Text(value, style: s)],
    );
  }

  Widget _obsField() {
    return Container(
      decoration: _brutal,
      child: TextField(
        controller: _obsCtrl,
        maxLines: 2,
        maxLength: 140,
        style: AppText.body(size: 13, weight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'Ex: caipirinha sem açúcar, alergia a camarão…',
          hintStyle: AppText.body(size: 13, weight: FontWeight.w500, color: AppColors.inkA(0.4)),
          border: InputBorder.none,
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _modeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.inkA(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(child: _modeBtn('Pagar tudo', 'full', null)),
          Expanded(child: _modeBtn('Dividir conta', 'split', Symbols.group)),
        ],
      ),
    );
  }

  Widget _modeBtn(String label, String mode, IconData? icon) {
    final active = _payMode == mode;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _payMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: active ? AppColors.dune : AppColors.inkA(0.55)),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: AppText.body(
                    size: 13,
                    weight: FontWeight.w800,
                    color: active ? AppColors.dune : AppColors.inkA(0.55))),
          ],
        ),
      ),
    );
  }

  /// Recebe o resultado do Google/Apple Pay, cria o pedido e cobra na hora
  /// (POST /orders/wallet → Pagar.me). Aprovado → confirmação "em produção".
  Future<void> _onWallet(Map<String, dynamic> result) async {
    if (_submitting) return;
    final token = _walletToken(result);
    if (token == null) {
      _toast('Não foi possível ler o pagamento da carteira.');
      return;
    }
    final payload = _orderPayload(method: 'CREDIT');
    if (payload == null) {
      // Sem estabelecimento real (demo) → mantém o comportamento antigo.
      _finish(incomplete: false);
      return;
    }
    final walletType =
        defaultTargetPlatform == TargetPlatform.iOS ? 'apple_pay' : 'google_pay';
    setState(() => _submitting = true);
    await _replacePending(); // descarta um pedido anterior deste carrinho, se houver
    try {
      final r = await ref
          .read(publicApiProvider)
          .createWalletOrder(payload, walletType, token);
      if (!mounted) return;
      if (r.ok && r.status == 'paid') {
        final id = r.order?.dbId;
        if (id != null) await ref.read(myOrderIdsProvider.notifier).add(id);
        if (!mounted) return;
        _markPending(null);
        ref.read(cartProvider.notifier).clear();
        context.go('/done',
            extra: DoneArgs(incomplete: false, code: r.order?.code ?? _genCode()));
      } else {
        setState(() => _submitting = false);
        _toast(r.status == 'pending'
            ? 'Pagamento em processamento — acompanhe em Pedidos.'
            : 'Pagamento não aprovado. Tente outro método.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        _toast('Não foi possível concluir o pagamento.');
      }
    }
  }

  Widget _walletSection(double amount) {
    if (kIsWeb) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pagar rápido'.toUpperCase(), style: AppText.display(size: 13, color: AppColors.inkA(0.6))),
        const SizedBox(height: 10),
        WalletButtons(amount: amount, onToken: _onWallet),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: Divider(color: AppColors.inkA(0.12))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('ou pague com',
                  style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.4))),
            ),
            Expanded(child: Divider(color: AppColors.inkA(0.12))),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _payGrid() {
    // Uma coluna por método (dinâmico) — evita índices fixos e não estoura
    // quando a lista muda (ex.: USDC removido deixou 3 métodos).
    return Row(
      children: [
        for (var i = 0; i < _methods.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _payOption(_methods[i])),
        ],
      ],
    );
  }

  Widget _payOption(_PayMethod pm) {
    final selected = _selPay == pm.id;
    return GestureDetector(
      onTap: () => setState(() => _selPay = pm.id),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.duneA(0.45) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.ink : AppColors.inkA(0.12), width: 2),
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: pm.color, shape: BoxShape.circle),
              child: Icon(pm.icon, size: 18, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(pm.label, textAlign: TextAlign.center, style: AppText.body(size: 13, weight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _splitCard(double grand, double share) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _brutal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Quantas pessoas?', style: AppText.body(size: 13, weight: FontWeight.w700)),
              Row(
                children: [
                  _stepBtn(Symbols.remove, AppColors.inkA(0.08), AppColors.ink, () => _setPeople(_people - 1)),
                  SizedBox(
                    width: 24,
                    child: Text('$_people', textAlign: TextAlign.center, style: AppText.body(size: 15, weight: FontWeight.w800)),
                  ),
                  _stepBtn(Symbols.add, AppColors.coral, Colors.white, () => _setPeople(_people + 1)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.inkA(0.5)),
              children: [
                const TextSpan(text: 'Dividido igualmente · '),
                TextSpan(text: money(share), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.coralDeep)),
                const TextSpan(text: ' por pessoa (com taxas)'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.pix.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.pix.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Symbols.qr_code_2, size: 16, color: AppColors.pix),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Geramos um Pix por pessoa. Você paga o seu e compartilha os '
                    'outros no WhatsApp — o pedido vai pra cozinha quando todos pagarem.',
                    style: AppText.body(size: 11, weight: FontWeight.w600, height: 1.4, color: AppColors.inkA(0.7)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Gera o pedido dividido (N cobranças Pix, uma por pessoa) e abre a tela de split.
  Future<void> _paySplit() async {
    if (_submitting) return;
    if (!await _ensureCpf() || !mounted) return;
    final payload = _orderPayload(method: 'PIX');
    if (payload == null) {
      _finish(incomplete: false);
      return;
    }
    payload['payment'] = {
      'kind': 'split',
      'shares': List.generate(_people, (_) => <String, dynamic>{'method': null}),
    };
    setState(() => _submitting = true);
    await _replacePending(); // descarta um pedido anterior deste carrinho, se houver
    ClientOrder? order;
    try {
      order = await ref.read(publicApiProvider).createOrder(payload);
    } catch (_) {
      order = null;
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    if (order == null || order.splits == null || order.splits!.isEmpty) {
      _toast('Não foi possível gerar as cobranças da divisão. Tente de novo.');
      return;
    }
    final id = order.dbId;
    if (id != null) await ref.read(myOrderIdsProvider.notifier).add(id);
    if (!mounted) return;
    _markPending(null);
    ref.read(cartProvider.notifier).clear();
    context.go('/split', extra: order);
  }

  Widget _stepBtn(IconData icon, Color bg, Color fg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, size: 15, color: fg),
      ),
    );
  }

  Widget _payBar(BuildContext context, String label, Color bg, bool canPay, double grand) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    // Enquanto envia, o botão vira spinner e trava — assim o cliente vê que
    // está processando e não fica tocando de novo (era o que fazia o Pix
    // "precisar de 2-3 cliques").
    final enabled = canPay && !_submitting;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 24, 16, 20 + bottomSafe),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [AppColors.canvas, AppColors.canvas, AppColors.canvas.withValues(alpha: 0)],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      child: Material(
        color: _submitting ? AppColors.coral.withValues(alpha: 0.6) : bg,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: enabled ? () => _pay(grand) : null,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Center(
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : Text(label, style: AppText.body(size: 15, weight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sheet pra coletar o CPF do pagador (1ª cobrança). StatefulWidget próprio pra
/// descartar o controller no dispose() (evita o crash de controller disposto na
/// animação de saída). Devolve o CPF (só dígitos) no pop, ou null se cancelar.
class _CpfSheet extends StatefulWidget {
  const _CpfSheet();

  @override
  State<_CpfSheet> createState() => _CpfSheetState();
}

class _CpfSheetState extends State<_CpfSheet> {
  final _ctrl = TextEditingController();
  String? _err;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!isValidCpf(_ctrl.text)) {
      setState(() => _err = 'CPF inválido — confira os números.');
      return;
    }
    Navigator.pop(context, _ctrl.text.replaceAll(RegExp(r'\D'), ''));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
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
          Text('CPF do pagador', style: AppText.display(size: 20, letterSpacing: -0.3)),
          const SizedBox(height: 6),
          Text('Obrigatório para o pagamento. Pedimos só uma vez — depois fica salvo.',
              style: AppText.body(size: 13, weight: FontWeight.w500, color: AppColors.inkA(0.55))),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 11,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: AppText.body(size: 18, weight: FontWeight.w700, letterSpacing: 1),
            onChanged: (_) {
              if (_err != null) setState(() => _err = null);
            },
            decoration: InputDecoration(
              counterText: '',
              hintText: 'Somente números',
              hintStyle: AppText.body(size: 15, weight: FontWeight.w500, color: AppColors.inkA(0.35)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _err != null ? AppColors.danger : AppColors.inkA(0.15), width: 1.5)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _err != null ? AppColors.danger : AppColors.ink, width: 2)),
            ),
          ),
          if (_err != null) ...[
            const SizedBox(height: 6),
            Text(_err!, style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.danger)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: Material(
              color: AppColors.coral,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                onTap: _confirm,
                borderRadius: BorderRadius.circular(999),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 15),
                  child: Center(child: _CpfContinueLabel()),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CpfContinueLabel extends StatelessWidget {
  const _CpfContinueLabel();
  @override
  Widget build(BuildContext context) =>
      Text('Continuar', style: AppText.body(size: 15, weight: FontWeight.w800, color: Colors.white));
}
