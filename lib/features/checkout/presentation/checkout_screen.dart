import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/data/models.dart';
import '../../../core/data/orders_controller.dart';
import '../../../core/data/public_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money.dart';
import '../../auth/auth_controller.dart';
import '../../cart/cart_controller.dart';
import '../../done/presentation/done_screen.dart';
import 'card_wait_screen.dart';
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

  void _pay(double grand) {
    if (_payMode == 'split') {
      _paySplit();
      return;
    }
    if (_selPay == null) return;
    // Pix (pagar tudo) → cobrança real: gera o QR e vai pra tela do Pix.
    if (_selPay == 'pix') {
      _payPix();
      return;
    }
    // Crédito/Débito (pagar tudo) → checkout hospedado da Pagar.me.
    if (_selPay == 'credito' || _selPay == 'debito') {
      _payCard();
      return;
    }
    _finish(incomplete: false);
  }

  /// Cria o pedido Pix (cobrança real na Pagar.me) e abre a tela do QR.
  Future<void> _payPix() async {
    if (_submitting) return;
    final payload = _orderPayload(method: 'PIX');
    if (payload == null) {
      // Sem estabelecimento real (demo) → mantém o fluxo antigo.
      _finish(incomplete: false);
      return;
    }
    setState(() => _submitting = true);
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
    ref.read(cartProvider.notifier).clear();
    // Sem cobrança Pix (gateway não-Pagar.me ou sem recebedor) → confirma como
    // pedido normal em vez de travar o cliente numa tela vazia.
    if (order.pixPayload == null && order.pixQrImage == null) {
      context.go('/done', extra: DoneArgs(incomplete: false, code: order.code));
      return;
    }
    context.go('/pix', extra: order);
  }

  /// Crédito/Débito → cria o pedido e abre o checkout hospedado da Pagar.me
  /// (cartão + 3DS acontecem na página segura). A confirmação vem pelo polling.
  Future<void> _payCard() async {
    if (_submitting) return;
    final payload = _orderPayload(method: _enumMethod(_selPay));
    if (payload == null) {
      // Sem estabelecimento real (demo) → mantém o fluxo antigo.
      _finish(incomplete: false);
      return;
    }
    setState(() => _submitting = true);
    ({bool ok, String? checkoutUrl, ClientOrder? order})? res;
    try {
      res = await ref.read(publicApiProvider).createCardCheckout(payload);
    } catch (_) {
      res = null;
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    final url = res?.checkoutUrl;
    final order = res?.order;
    if (res == null || res.ok != true || url == null || url.isEmpty || order == null) {
      _toast('Não foi possível abrir o pagamento no cartão. Tente novamente.');
      return;
    }
    final id = order.dbId;
    if (id != null) await ref.read(myOrderIdsProvider.notifier).add(id);
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    ref.read(cartProvider.notifier).clear();
    context.go('/pagamento', extra: CardWaitArgs(order: order, checkoutUrl: url));
  }

  /// Cria o pedido real (best-effort) e vai pra confirmação. Sem backend /
  /// estabelecimento real, mantém o comportamento de demonstração (stub).
  Future<void> _finish({required bool incomplete}) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final order = await _submitOrder();
    if (!mounted) return;
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
    final name = ref.read(authProvider).name;
    final note = _obsCtrl.text.trim();
    return <String, dynamic>{
      'establishmentId': est.id,
      'locationLabel': 'Pedido pelo app',
      if (name != null && name.isNotEmpty) 'customerName': name,
      if (note.isNotEmpty) 'note': note,
      'items': [
        for (final l in lines)
          <String, dynamic>{
            if (l.$1.dbId != null) 'menuItemId': l.$1.dbId,
            'name': l.$1.name,
            'qty': l.$2,
            'unitPrice': l.$1.price,
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
                  _walletSection(grand),
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

  Widget _summary(List<(MenuItem, int)> cartLines, dynamic est, double total, double fee, double estFee, double grand) {
    final lines = cartLines
        .map((l) => (label: '${l.$2}× ${l.$1.name}', value: money(l.$1.price * l.$2)))
        .toList();

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
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: Text(l.label, style: AppText.body(size: 13))),
                  Text(l.value, style: AppText.body(size: 13, weight: FontWeight.w600)),
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
    try {
      final r = await ref
          .read(publicApiProvider)
          .createWalletOrder(payload, walletType, token);
      if (!mounted) return;
      if (r.ok && r.status == 'paid') {
        final id = r.order?.dbId;
        if (id != null) await ref.read(myOrderIdsProvider.notifier).add(id);
        if (!mounted) return;
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
        color: bg,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: canPay ? () => _pay(grand) : null,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Center(
              child: Text(label, style: AppText.body(size: 15, weight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }
}
