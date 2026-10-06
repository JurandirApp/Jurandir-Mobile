import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:pay/pay.dart';

import '../../../core/data/client_profile.dart';
import '../../../core/data/models.dart';
import '../../../core/data/orders_controller.dart';
import '../../../core/data/public_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money.dart';
import '../../auth/auth_controller.dart';
import '../../cart/cart_controller.dart';
import '../../done/presentation/done_screen.dart';
import '../../menu/presentation/item_sheet.dart';
import 'card_wait_screen.dart';
import '../../../core/payments/wallet_config.dart';
import 'card_sheet.dart';

class _PayMethod {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  const _PayMethod(this.id, this.label, this.icon, this.color);
}

/// EventChannel por onde o `pay_android` (3.2.0) devolve o resultado do Google
/// Pay. Precisa estar ESCUTANDO antes de `showPaymentSelector`, senão o plugin
/// lança `illegalEventChannelState` e a folha nem abre. É o mesmo canal que o
/// widget `GooglePayButton` assina internamente.
const EventChannel _gpayResultChannel =
    EventChannel('plugins.flutter.io/pay/payment_result');

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

  /// Métodos de pagamento, na ordem iFood. A carteira nativa aparece conforme a
  /// plataforma (Apple Pay no iOS, Google Pay no Android); no web não há carteira.
  /// Todas as opções ficam SEMPRE visíveis — nenhuma é ocultada.
  List<_PayMethod> get _payMethods {
    final iOS = defaultTargetPlatform == TargetPlatform.iOS;
    return [
      const _PayMethod('pix', 'Pix', Symbols.qr_code_2, AppColors.pix),
      if (!kIsWeb)
        iOS
            ? const _PayMethod('apple_pay', 'Apple Pay', Symbols.contactless, AppColors.ink)
            : const _PayMethod('google_pay', 'Google Pay', Symbols.contactless, AppColors.ink),
      const _PayMethod('credito', 'Crédito', Symbols.credit_card, AppColors.credit),
      const _PayMethod('debito', 'Débito', Symbols.account_balance, AppColors.debit),
    ];
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
    // Roteia por método. Cada um trata o próprio fluxo de cobrança.
    switch (_selPay) {
      case 'pix':
        _payPix();
        break;
      case 'apple_pay':
      case 'google_pay':
        await _startWallet(grand);
        break;
      case 'credito':
        await _payCard(grand, debit: false);
        break;
      case 'debito':
        await _payCard(grand, debit: true);
        break;
      default:
        _finish(incomplete: false);
    }
  }

  /// Dispara a folha nativa (Apple Pay / Google Pay) programaticamente e, com o
  /// token, cai no `_onWallet` (cria o pedido + cobra). Se a carteira não estiver
  /// disponível (sem cartão no Wallet), avisa e o cliente usa outro método.
  Future<void> _startWallet(double grand) async {
    final iOS = defaultTargetPlatform == TargetPlatform.iOS;
    final provider = iOS ? PayProvider.apple_pay : PayProvider.google_pay;
    final config = iOS
        ? WalletConfig.applePay
        : WalletConfig.googlePayFor(_cartEst()?.gatewayFor('googlePay') ?? 'PAGARME');
    final client = Pay({provider: PaymentConfiguration.fromJsonString(config)});
    final items = [
      PaymentItem(
        label: 'Total',
        amount: grand.toStringAsFixed(2),
        status: PaymentItemStatus.final_price,
      ),
    ];
    try {
      // Android (Google Pay): o resultado volta pelo EventChannel, não pelo
      // retorno do método (que devolve "{}"). iOS (Apple Pay) volta direto.
      final result = iOS
          ? await client.showPaymentSelector(provider, items)
          : await _googlePaySelect(client, provider, items);
      if (!mounted) return;
      await _onWallet(result);
    } catch (e) {
      // DIAGNOSTICO TEMPORARIO: dialogo persistente e copiavel com o erro real do
      // Google/Apple Pay (o toast sumia rapido demais). Reverter depois da causa.
      debugPrint('GPAY_ERR >>> $e');
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(iOS ? 'Apple Pay — erro' : 'Google Pay — erro'),
            content: SingleChildScrollView(
              child: SelectableText('$e', style: const TextStyle(fontSize: 13)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Fechar'),
              ),
            ],
          ),
        );
      }
    }
  }

  /// Google Pay (pay_android 3.2.0): assina o EventChannel do resultado ANTES de
  /// abrir a folha (o `onListen` é o que ativa o canal no nativo) e aguarda o
  /// primeiro resultado/erro por ele. `showPaymentSelector` retorna "{}" — o
  /// pagamento de verdade chega pelo stream. Sem isso: `illegalEventChannelState`.
  Future<Map<String, dynamic>> _googlePaySelect(
      Pay client, PayProvider provider, List<PaymentItem> items) async {
    final completer = Completer<Map<String, dynamic>>();
    final sub = _gpayResultChannel.receiveBroadcastStream().listen(
      (event) {
        if (completer.isCompleted) return;
        try {
          completer.complete(jsonDecode(event as String) as Map<String, dynamic>);
        } catch (e) {
          completer.completeError(e);
        }
      },
      onError: (Object e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
    );
    try {
      // Dispara a folha (retorno "{}" descartado; o resultado vem pelo stream).
      await client.showPaymentSelector(provider, items);
      return await completer.future;
    } finally {
      await sub.cancel();
    }
  }

  /// Cartão manual: abre a tela de cartão (tokeniza direto no gateway do método —
  /// Pagar.me ou PagBank), e com o token cria o pedido + cobra via `/orders/card`.
  Future<void> _payCard(double grand, {required bool debit}) async {
    if (!await _ensureCpf() || !mounted) return;
    // PagBank: o cartão é criptografado com a chave pública da conta (vem do backend).
    String? pagbankKey;
    if (_cartEst()?.gatewayFor(debit ? 'debit' : 'credit') == 'PAGBANK') {
      pagbankKey = await ref.read(publicApiProvider).pagbankPublicKey();
      if (!mounted) return;
      if (pagbankKey == null) {
        _toast('Pagamento com cartão indisponível agora. Tente outro método.');
        return;
      }
    }
    final card = await showCardSheet(context, amount: grand, debit: debit, pagbankKey: pagbankKey);
    if (card == null || !mounted) return; // cancelou ou falhou a tokenização
    final payload = _orderPayload(method: debit ? 'DEBIT' : 'CREDIT');
    if (payload == null) {
      _finish(incomplete: false); // demo (sem estabelecimento real)
      return;
    }
    setState(() => _submitting = true);
    await _replacePending();
    // 1) Cria o pedido ANTES de cobrar — o app SEMPRE fica com o id (aparece em
    //    "Pedidos") e NUNCA trava, mesmo se a cobrança demorar/der timeout.
    final ClientOrder order;
    try {
      order = await ref.read(publicApiProvider).createOrder(payload);
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        _toast('Não foi possível iniciar o pedido. Tente de novo.');
      }
      return;
    }
    final id = order.dbId;
    if (id == null) {
      if (mounted) {
        setState(() => _submitting = false);
        _toast('Não foi possível iniciar o pedido. Tente de novo.');
      }
      return;
    }
    await ref.read(myOrderIdsProvider.notifier).add(id);
    _markPending(id);

    // 2) Cobra o pedido. Em QUALQUER lentidão/timeout vai pra tela de
    //    processamento (que confirma sozinha pelo polling) — nunca trava com o
    //    dinheiro já cobrado.
    final doc = ref.read(clientProfileProvider).documentDigits;
    try {
      final r = await ref.read(publicApiProvider).createCardOrder(
            id,
            card.token,
            method: debit ? 'debit' : 'credit',
            billing: card.billing,
            customerDocument: doc,
          );
      if (!mounted) return;
      if (r.ok && r.status == 'paid') {
        _markPending(null);
        ref.read(cartProvider.notifier).clear();
        context.go('/done', extra: DoneArgs(incomplete: false, code: order.code));
      } else if (r.ok && r.status == 'pending') {
        // Em análise (antifraude assíncrono) — tela de processamento confirma sozinha.
        context.go('/pagamento', extra: CardWaitArgs(order: r.order ?? order));
      } else {
        // Recusa de fato (dados/antifraude) — deixa retentar com outro cartão.
        setState(() => _submitting = false);
        _toast('Pagamento não aprovado. Confira os dados ou tente outro cartão.');
      }
    } catch (_) {
      // Timeout/rede: a cobrança PODE ter ido. NÃO trava — vai pra tela de
      // processamento, que confirma sozinha (o pedido já está em "Pedidos").
      if (mounted) context.go('/pagamento', extra: CardWaitArgs(order: order));
    }
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

  /// Estabelecimento do CARRINHO — garante que a cobrança vai pro recebedor
  /// certo mesmo que o cliente tenha navegado pra outro bar sem adicionar.
  /// 1) o estabelecimento que o cliente abriu (slug); 2) senão, o primeiro real.
  Establishment? _cartEst() {
    final ests = ref.read(establishmentsProvider).asData?.value ?? const <Establishment>[];
    final slug = ref.read(cartEstablishmentProvider) ?? ref.read(selectedSlugProvider);
    for (final e in ests) {
      if (slug != null && e.slug == slug) return e;
    }
    for (final e in ests) {
      if (e.slug != null) return e;
    }
    return null;
  }

  /// Monta o payload do pedido (estabelecimento escolhido + carrinho). Null se
  /// não houver estabelecimento real ou o carrinho estiver vazio.
  Map<String, dynamic>? _orderPayload({required String method}) {
    final est = _cartEst();
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
    // Estabelecimento do CARRINHO (autoritativo — um pedido é de um bar só).
    // Fallback pro slug aberto, só quando o carrinho ainda está vazio.
    final selSlug = ref.watch(cartEstablishmentProvider) ?? ref.watch(selectedSlugProvider);
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
                if (!isSplit)
                  _payGrid()
                else
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
    // 1) Cria o pedido ANTES de cobrar — o app fica com o id (aparece em
    //    "Pedidos") e NUNCA trava, mesmo se a cobrança demorar/der timeout.
    final ClientOrder order;
    try {
      order = await ref.read(publicApiProvider).createOrder(payload);
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        _toast('Não foi possível iniciar o pedido. Tente de novo.');
      }
      return;
    }
    final id = order.dbId;
    if (id == null) {
      if (mounted) {
        setState(() => _submitting = false);
        _toast('Não foi possível iniciar o pedido. Tente de novo.');
      }
      return;
    }
    await ref.read(myOrderIdsProvider.notifier).add(id);
    _markPending(id);

    // 2) Cobra o pedido. Lentidão/timeout → tela de processamento (nunca trava
    //    com o dinheiro já cobrado).
    try {
      final r = await ref.read(publicApiProvider).createWalletOrder(id, walletType, token);
      if (!mounted) return;
      if (r.ok && r.status == 'paid') {
        _markPending(null);
        ref.read(cartProvider.notifier).clear();
        context.go('/done', extra: DoneArgs(incomplete: false, code: order.code));
      } else if (r.ok && r.status == 'pending') {
        context.go('/pagamento', extra: CardWaitArgs(order: r.order ?? order));
      } else {
        setState(() => _submitting = false);
        _toast('Pagamento não aprovado. Tente outro método.');
      }
    } catch (_) {
      // Timeout/rede: a cobrança PODE ter ido. NÃO trava — tela de processamento
      // confirma sozinha (o pedido já está em "Pedidos").
      if (mounted) context.go('/pagamento', extra: CardWaitArgs(order: order));
    }
  }

  Widget _payGrid() {
    // Lista vertical estilo iFood: todos os métodos SEMPRE visíveis (Pix,
    // carteira nativa, crédito e débito), com subtítulo e seleção por toque.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Como você quer pagar?'.toUpperCase(),
            style: AppText.display(size: 13, color: AppColors.inkA(0.6))),
        const SizedBox(height: 10),
        for (final pm in _payMethods) ...[
          _payOption(pm),
          const SizedBox(height: 8),
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
        child: Row(
          children: [
            // Google Pay: marca OFICIAL (acceptance mark) no lugar de icone+texto
            // custom — exigencia de marca do Google pra aprovar o Google Pay.
            if (pm.id == 'google_pay')
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Image.asset('assets/images/google-pay-mark.png', height: 34),
                ),
              )
            else ...[
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: pm.color, shape: BoxShape.circle),
                child: Icon(pm.icon, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(pm.label, style: AppText.body(size: 14.5, weight: FontWeight.w800)),
              ),
            ],
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? AppColors.ink : AppColors.inkA(0.3), width: 2),
                color: selected ? AppColors.ink : Colors.transparent,
              ),
              child: selected ? const Icon(Symbols.check, size: 14, color: Colors.white) : null,
            ),
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
