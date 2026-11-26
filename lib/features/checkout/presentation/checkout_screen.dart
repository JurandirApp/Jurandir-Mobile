import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:pay/pay.dart';
import 'package:url_launcher/url_launcher.dart';

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
import '../../../core/payments/threeds.dart';
import '../../../core/payments/tuna_fingerprint.dart';
import '../../../core/payments/tuna_threeds.dart';
import '../../../core/payments/wallet_config.dart';
import 'card_sheet.dart';
import 'three_ds_screen.dart';
import 'tuna_fingerprint_collector.dart';
import 'tuna_threeds_screen.dart';

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
  bool _calling = false; // cooldown do "chamar garçom"
  // Carteira (Google/Apple Pay) no débito? Só oferecido quando a carteira do
  // bar está na Tuna (os outros gateways cobram carteira só no crédito).
  bool _walletDebit = false;
  // Device fingerprint da Tuna (antifraude): começa ao abrir o checkout (precisa
  // de 5–10 s antes de cobrar). Id novo por abertura; nunca logar.
  bool _fpStarted = false;
  String? _deviceSessionId;
  String? _fpTagUrl;

  @override
  void dispose() {
    _obsCtrl.dispose();
    super.dispose();
  }

  /// Métodos de pagamento, na ordem iFood. A carteira nativa aparece conforme a
  /// plataforma (Apple Pay no iOS, Google Pay no Android); no web não há carteira.
  /// Todas as opções ficam SEMPRE visíveis — exceto Apple Pay quando a carteira
  /// do bar está na Tuna (Apple Pay via Tuna ainda não existe; o token não seria
  /// cobrável).
  List<_PayMethod> get _payMethods {
    final iOS = defaultTargetPlatform == TargetPlatform.iOS;
    return [
      const _PayMethod('pix', 'Pix', Symbols.qr_code_2, AppColors.pix),
      if (!kIsWeb)
        if (!iOS)
          const _PayMethod('google_pay', 'Google Pay', Symbols.contactless, AppColors.ink)
        else if (!_applePayBlocked)
          const _PayMethod('apple_pay', 'Apple Pay', Symbols.contactless, AppColors.ink),
      const _PayMethod('credito', 'Crédito', Symbols.credit_card, AppColors.credit),
      const _PayMethod('debito', 'Débito', Symbols.account_balance, AppColors.debit),
    ];
  }

  /// Apple Pay indisponível pro bar: a carteira dele está na Tuna (fora de escopo).
  /// A carteira ([walletId] = 'google_pay' | 'apple_pay') aceita débito? Só na Tuna.
  bool _walletAllowsDebit(String walletId) =>
      _cartEst()?.gatewayFor(walletId == 'apple_pay' ? 'applePay' : 'googlePay') == 'TUNA';

  /// Débito efetivo da carteira desta plataforma (escolha + gateway que aceita).
  bool get _walletDebitActive {
    final id = defaultTargetPlatform == TargetPlatform.iOS ? 'apple_pay' : 'google_pay';
    return _walletDebit && _walletAllowsDebit(id);
  }

  /// (Tuna só com o Merchant ID próprio dela no build — APPLE_MERCHANT_ID_TUNA.)
  bool get _applePayBlocked => !WalletConfig.applePayAvailableFor(_cartEst()?.gatewayFor('applePay') ?? 'PAGARME');

  /// Inicia o fingerprint da Tuna uma vez por abertura do checkout, assim que
  /// o bar do carrinho é conhecido e roteia crédito, débito ou Google Pay pra
  /// Tuna. Config desligada/erro → pula em silêncio (o pagamento nunca depende).
  Future<void> _maybeStartFingerprint() async {
    if (_fpStarted) return;
    final est = _cartEst();
    if (est == null) return; // bares ainda carregando — tenta no próximo build
    _fpStarted = true;
    final usesTuna = ['credit', 'debit', 'googlePay'].any((m) => est.gatewayFor(m) == 'TUNA');
    if (!usesTuna || kIsWeb) return;
    final cfg = await ref.read(publicApiProvider).tunaFingerprint();
    if (!mounted || !cfg.usable) return;
    final id = generateDeviceSessionId();
    setState(() {
      _deviceSessionId = id;
      _fpTagUrl = tunaFingerprintTagUrl(orgId: cfg.orgId!, merchantId: cfg.merchantId!, deviceSessionId: id);
    });
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
    if (iOS && _applePayBlocked) {
      // Defensivo (a opção nem aparece): nunca abre Apple Pay de bar na Tuna.
      _toast('Apple Pay indisponível neste local. Use outro método.');
      return;
    }
    final provider = iOS ? PayProvider.apple_pay : PayProvider.google_pay;
    final gpGateway = _cartEst()?.gatewayFor('googlePay') ?? 'PAGARME';
    // Google Pay na Tuna: o gatewayMerchantId vem do servidor (troca sem versão
    // nova). Sem ele, não abre (um id errado só daria recusa na Tuna).
    String? tunaMid;
    if (!iOS && gpGateway == 'TUNA') {
      tunaMid = await ref.read(publicApiProvider).tunaGooglePayGatewayMerchantId();
      if (!mounted) return;
      if (tunaMid == null) {
        _toast('Google Pay indisponível agora. Tente de novo ou use outro método.');
        return;
      }
    }
    final config = iOS
        ? WalletConfig.applePayFor(_cartEst()?.gatewayFor('applePay') ?? 'PAGARME', debit: _walletDebitActive)
        : WalletConfig.googlePayFor(gpGateway, tunaGatewayMerchantId: tunaMid, debit: _walletDebitActive);
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
      debugPrint('WALLET_ERR >>> $e');
      if (!mounted) return;
      // Cancelamento pelo usuário (fechou a folha): sem aviso.
      if (e.toString().toLowerCase().contains('cancel')) return;
      _toast(iOS
          ? 'Apple Pay indisponível agora. Adicione um cartão no Wallet ou use outro método.'
          : 'Google Pay indisponível agora. Use outro método.');
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
      return await completer.future.timeout(const Duration(seconds: 120));
    } finally {
      await sub.cancel();
    }
  }

  /// Cartão manual: abre a tela de cartão (tokeniza direto no gateway do método —
  /// Pagar.me ou PagBank), e com o token cria o pedido + cobra via `/orders/card`.
  /// Débito PagBank: entre criar o pedido e cobrar, o banco confirma a compra
  /// (3DS) numa tela dentro do app; sem confirmação, não cobra.
  /// Tuna: a folha só coleta o cartão; a sessão de tokenização é presa ao pedido,
  /// então tokeniza DEPOIS de criar o pedido. Débito Tuna: 3DS (código no
  /// Generate/Bind → DDC → cobrança com `threeDs` → desafio do banco se pedir).
  /// Crédito Tuna segue sem 3DS.
  Future<void> _payCard(double grand, {required bool debit}) async {
    // InfinitePay: o crédito é pago na página hospedada (sem tokenização no app).
    if (!debit && _cartEst()?.gatewayFor('credit') == 'INFINITEPAY') return _payHosted('CREDIT');
    if (!await _ensureCpf() || !mounted) return;
    final tuna = _cartEst()?.gatewayFor(debit ? 'debit' : 'credit') == 'TUNA';
    final threeDs = debit && _cartEst()?.gatewayFor('debit') == 'PAGBANK';
    // O 3DS do PagBank pede o celular do pagador (com DDD).
    if (threeDs && (!await _ensurePhone() || !mounted)) return;
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
    // Tuna: a folha abre a sessão do APARELHO pra mostrar os cartões salvos.
    final api = ref.read(publicApiProvider);
    final cardKey = ref.read(clientProfileProvider).cardKey;
    final card = await showCardSheet(context,
        amount: grand,
        debit: debit,
        pagbankKey: pagbankKey,
        wantRaw: threeDs,
        tuna: tuna,
        tunaCardsSession: tuna ? () => api.tunaCardsSession(cardKey) : null);
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

    // 1b) Débito PagBank: o banco confirma (3DS) ANTES de cobrar. Sem a
    //     confirmação não cobra — o pedido fica pendente (a próxima tentativa
    //     descarta pelo `_replacePending`).
    String? authenticationId;
    var chargeToken = card.token;
    if (threeDs) {
      authenticationId = await _confirmWithBank(id, card);
      if (authenticationId == null) return; // já avisou e liberou o botão
      // O blob do PagBank tem timestamp e o 3DS pode ter levado minutos:
      // recriptografa agora (só em memória; nunca logar).
      chargeToken = card.freshToken?.call() ?? card.token;
    }

    // 1c) Tuna: abre a sessão do pedido e manda o cartão direto pra Tuna. Falhou
    //     → nada cobrado; o pedido fica pendente (a próxima tentativa descarta
    //     pelo `_replacePending`).
    //     Débito: na produção da Tuna TODO débito passa por 3DS — o código curto
    //     vai no Generate/Bind (a Tuna devolve os dados do Cardinal), roda o
    //     DDC (best-effort) e a cobrança leva `threeDs` + `browser`. Cartão
    //     salvo sem `authenticationInformation` no Bind vai sem 3DS (a Tuna
    //     provavelmente recusa).
    Map<String, dynamic>? tunaInfo;
    if (tuna) {
      final authCode = debit ? newTunaThreeDsCode() : null;
      final t = await _tokenizeTuna(id, card, authCode: authCode);
      if (t == null || !mounted) return; // já avisou e liberou o botão
      chargeToken = t.token;
      Map<String, dynamic>? threeDsInfo;
      final auth = t.auth;
      if (authCode != null && auth != null) {
        await runTunaDdc(context, auth);
        if (!mounted) return;
        threeDsInfo = tunaThreeDsBlock(authCode, auth);
      }
      tunaInfo = {
        'sessionId': t.sessionId,
        'brand': ?t.brand,
        'deviceSessionId': ?_deviceSessionId,
        'deviceKey': ?t.deviceKey, // só cartão salvo / cartão novo salvo agora
        'threeDs': ?threeDsInfo,
        if (threeDsInfo != null) 'browser': _tunaBrowser(),
      };
    }

    // 2) Cobra o pedido. Em QUALQUER lentidão/timeout vai pra tela de
    //    processamento (que confirma sozinha pelo polling) — nunca trava com o
    //    dinheiro já cobrado.
    final doc = ref.read(clientProfileProvider).documentDigits;
    try {
      final r = await ref.read(publicApiProvider).createCardOrder(
            id,
            chargeToken,
            method: debit ? 'debit' : 'credit',
            billing: tuna ? null : card.billing, // a Tuna não usa o billing
            customerDocument: doc,
            authenticationId: authenticationId,
            tuna: tunaInfo,
          );
      if (!mounted) return;
      final challenge = r.challenge;
      if (tuna && r.ok && challenge != null) {
        // Débito Tuna: o banco pediu confirmação (desafio 3DS).
        await _tunaChallenge(order, challenge);
      } else if (r.ok && r.status == 'paid') {
        _markPending(null);
        ref.read(cartProvider.notifier).clear();
        context.go('/done', extra: DoneArgs(incomplete: false, code: order.code));
      } else if (r.ok && r.status == 'pending') {
        // Em análise (antifraude assíncrono) — tela de processamento confirma sozinha.
        context.go('/pagamento', extra: CardWaitArgs(order: r.order ?? order));
      } else {
        // Recusa de fato (dados/antifraude) — deixa retentar com outro cartão.
        setState(() => _submitting = false);
        _declineToast('Pagamento não aprovado. Confira os dados ou tente outro cartão.');
      }
    } catch (_) {
      // Timeout/rede: a cobrança PODE ter ido. NÃO trava — vai pra tela de
      // processamento, que confirma sozinha (o pedido já está em "Pedidos").
      if (mounted) context.go('/pagamento', extra: CardWaitArgs(order: order));
    }
  }

  /// Tuna: abre a sessão de tokenização do pedido (`/tuna/session`) e gera o
  /// token de uso único direto na Tuna. Devolve token + bandeira + sessão, ou
  /// null — nesse caso já avisou o cliente, liberou o botão e NADA foi cobrado.
  /// Nunca logar o cartão, o token nem a sessão.
  /// Cartão salvo / cartão novo a salvar: usa uma sessão NOVA do aparelho
  /// (`/tuna/cards/session`) — Bind do CVV ou Generate persistente — e devolve
  /// `deviceKey` pra cobrança ir no customer do aparelho. Sem essa sessão, o
  /// cartão salvo não paga (avisa); o cartão novo cai no fluxo de sempre, sem
  /// salvar.
  /// `authCode` (débito, 3DS) vai no Generate/Bind; `auth` volta com os dados
  /// do Cardinal quando a Tuna devolve `authenticationInformation`.
  Future<({String token, String? brand, String sessionId, String? deviceKey, TunaAuthInfo? auth})?> _tokenizeTuna(
      String orderId, CardSheetResult card,
      {String? authCode}) async {
    final tokenize = card.tunaTokenize;
    if (tokenize != null && (card.tunaSavedCard || card.tunaSaveNew)) {
      final key = ref.read(clientProfileProvider).cardKey;
      final ds = await ref.read(publicApiProvider).tunaCardsSession(key);
      if (!mounted) return null;
      if (ds != null) {
        final t = await tokenize(ds.tokenUrl, ds.sessionId, true, authCode);
        if (!mounted) return null;
        if (t == null) {
          setState(() => _submitting = false);
          _toast(card.tunaSavedCard
              ? 'Não foi possível validar o cartão salvo. Confira o CVV ou use outro cartão.'
              : 'Não foi possível validar o cartão. Confira os dados ou tente outro cartão.');
          return null;
        }
        return (token: t.token, brand: t.brand, sessionId: ds.sessionId, deviceKey: key, auth: t.auth);
      }
      if (card.tunaSavedCard) {
        setState(() => _submitting = false);
        _toast('Pagamento com cartão indisponível agora. Tente outro método.');
        return null;
      }
    }
    final s = await ref.read(publicApiProvider).tunaSession(orderId);
    if (!mounted) return null;
    final session = s.session;
    if (session == null || tokenize == null) {
      // 404/409/403/502: tanto faz o motivo pro cliente — usa outro método.
      setState(() => _submitting = false);
      _toast('Pagamento com cartão indisponível agora. Tente outro método.');
      return null;
    }
    final t = await tokenize(session.tokenUrl, session.sessionId, false, authCode);
    if (!mounted) return null;
    if (t == null) {
      setState(() => _submitting = false);
      _toast('Não foi possível validar o cartão. Confira os dados ou tente outro cartão.');
      return null;
    }
    return (token: t.token, brand: t.brand, sessionId: session.sessionId, deviceKey: null, auth: t.auth);
  }

  /// Bloco `tuna.browser` (3DS): tela em px lógicos, idioma e fuso do aparelho.
  Map<String, dynamic> _tunaBrowser() {
    final size = MediaQuery.sizeOf(context);
    return tunaBrowserBlock(
      screenWidth: size.width,
      screenHeight: size.height,
      timeZoneOffset: DateTime.now().timeZoneOffset,
      languageTag: WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag(),
    );
  }

  /// Débito Tuna: o banco pediu confirmação. Abre a tela do desafio, que
  /// acompanha o pedido sozinha (o resultado vai do banco direto pra Tuna).
  /// Pago → /done; recusado/fechado → avisa e libera o botão (o pedido fica
  /// pendente; a próxima tentativa descarta pelo `_replacePending`); sem
  /// resposta em 5 min → tela de processamento (ainda pode confirmar).
  Future<void> _tunaChallenge(ClientOrder order, TunaChallenge challenge) async {
    final id = order.dbId;
    final api = ref.read(publicApiProvider);
    final outcome = await runTunaChallenge(
      context,
      challenge: challenge,
      fetchOrder: () async {
        if (id == null) return null;
        final list = await api.myOrders([id]);
        return list.isEmpty ? null : list.first;
      },
      // Recusa do banco aparece na hora (o pedido continua "aguardando").
      fetchChargeStatus: () async => id == null ? null : api.tunaCardStatus(id),
    );
    if (!mounted) return;
    switch (outcome) {
      case TunaChallengePaid(order: final paid):
        _markPending(null);
        ref.read(cartProvider.notifier).clear();
        context.go('/done', extra: DoneArgs(incomplete: false, code: paid.code.isNotEmpty ? paid.code : order.code));
      case TunaChallengeTimeout():
        context.go('/pagamento', extra: CardWaitArgs(order: order));
      case TunaChallengeDeclined():
        setState(() => _submitting = false);
        _declineToast('Pagamento não aprovado pelo banco. Tente de novo ou use outro cartão.');
      case TunaChallengeCancelled():
        setState(() => _submitting = false);
        _declineToast('Pagamento não confirmado com o banco. Tente de novo ou use outro método.');
    }
  }

  /// Débito PagBank: abre a sessão 3DS do pedido e a tela "Confirmação do banco".
  /// Devolve o id da autenticação (`3DS_…`) ou null — nesse caso já avisou o
  /// cliente, liberou o botão e NADA foi cobrado.
  Future<String?> _confirmWithBank(String orderId, CardSheetResult card) async {
    final api = ref.read(publicApiProvider);
    final raw = card.raw;
    final parts = card.billingParts;
    final s = await api.pagbankThreeDsSession(orderId);
    if (!mounted) return null;
    final session = s.session;
    if (session == null || raw == null || parts == null) {
      setState(() => _submitting = false);
      _toast(s.error == 'debitDisabled'
          ? 'Débito indisponível no momento. Use crédito, Pix ou carteira.'
          : 'Não foi possível iniciar o pagamento. Tente de novo.');
      return null;
    }
    final outcome = await runThreeDs(
      context,
      pageUrl: api.pagbankThreeDsPageUrl(),
      session: session,
      data: buildThreeDsData(session: session, card: raw, billing: parts),
    );
    if (!mounted) return null;
    if (outcome is ThreeDsAuthenticated) return outcome.id;
    if (kDebugMode && outcome is ThreeDsFailed) debugPrint('3DS_FAIL >>> ${outcome.code}'); // só o código
    setState(() => _submitting = false);
    _toast(switch (outcome) {
      ThreeDsNotSupported() || ThreeDsDenied() =>
        'Esse cartão de débito não pode ser usado aqui. Pague com crédito, Pix ou carteira.',
      _ => 'Não foi possível confirmar com o seu banco. Tente de novo.',
    });
    return null;
  }

  /// Checkout HOSPEDADO (InfinitePay): o cliente paga Pix ou crédito na página do
  /// gateway. Cria o pedido + o link (`/orders/checkout`), abre a página e vai pra
  /// tela de espera, que confirma sozinha pelo polling. O pedido já fica em
  /// "Pedidos" — se o cliente fechar a página, dá pra reabrir de lá.
  Future<void> _payHosted(String method) async {
    if (_submitting) return;
    final payload = _orderPayload(method: method);
    if (payload == null) {
      _finish(incomplete: false); // demo (sem estabelecimento real)
      return;
    }
    setState(() => _submitting = true);
    await _replacePending();
    ({bool ok, String? checkoutUrl, ClientOrder? order}) r;
    try {
      r = await ref.read(publicApiProvider).createCardCheckout(payload);
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        _toast('Não foi possível iniciar o pagamento. Tente de novo.');
      }
      return;
    }
    final order = r.order;
    final id = order?.dbId;
    if (id != null) {
      await ref.read(myOrderIdsProvider.notifier).add(id);
      _markPending(id); // se o link falhar, a próxima tentativa descarta este pedido
    }
    if (!mounted) return;
    final url = r.checkoutUrl ?? '';
    if (!r.ok || order == null || url.isEmpty) {
      setState(() => _submitting = false);
      _toast('Não foi possível abrir o pagamento agora. Tente de novo ou use outro método.');
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    context.go('/pagamento', extra: CardWaitArgs(order: order, checkoutUrl: url));
  }

  /// Pergunta a mesa quando o cliente entrou sem QR. Mostra as mesas CADASTRADAS
  /// do bar pra ESCOLHER (evita duplicar "Mesa 02"/"Mesa 2") + opção de digitar.
  /// Retorna o label escolhido/digitado, ou null se cancelar.
  Future<String?> _askTable() async {
    final slug = _cartEst()?.slug;
    List<String> spots = const [];
    if (slug != null) {
      spots = await ref.read(publicApiProvider).barSpots(slug); // best-effort (nunca lança)
    }
    if (!mounted) return null;
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _TableSheet(spots: spots),
    );
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

  /// Garante um celular com DDD pro pagador (o 3DS do PagBank exige o telefone).
  /// Usa o do perfil; se tiver menos de 10 dígitos, pede uma vez num sheet,
  /// valida e guarda no perfil (vai no pedido como `customerPhone`).
  /// Retorna false se o usuário cancelar.
  Future<bool> _ensurePhone() async {
    final profile = ref.read(clientProfileProvider);
    final current = (profile.phone ?? '').replaceAll(RegExp(r'\D'), '');
    if (_isValidPhone(current)) return true;
    // Pré-preenche o que der (sem o DDI 55); o resto o cliente completa.
    final initial = current.length > 11 && current.startsWith('55') ? current.substring(2) : current;
    final phone = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _PhoneSheet(initial: initial.length > 11 ? '' : initial),
    );
    if (phone == null || !mounted) return false;
    final p = ref.read(clientProfileProvider);
    await ref.read(clientProfileProvider.notifier).save(p.name ?? '', phone);
    return true;
  }

  /// Cria o pedido Pix (cobrança real na Pagar.me) e abre a tela do QR.
  Future<void> _payPix() async {
    if (_submitting) return;
    // InfinitePay: não há QR Pix por API — o Pix é pago na página hospedada.
    if (_cartEst()?.gatewayFor('pix') == 'INFINITEPAY') return _payHosted('PIX');
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

  /// Chama o garçom até a mesa. Cooldown de 60s (o backend também deduplica).
  Future<void> _callWaiter() async {
    if (_calling) return;
    final estId = _cartEst()?.id;
    if (estId == null) {
      _toast('Abra o cardápio de um bar pra chamar o garçom.');
      return;
    }
    var mesa = ref.read(selectedLocalProvider) ?? '';
    if (mesa.trim().isEmpty) {
      final table = await _askTable();
      if (table == null || !mounted) return; // cancelou
      ref.read(selectedLocalProvider.notifier).set(table);
      mesa = table;
    }
    setState(() => _calling = true);
    try {
      final ok = await ref.read(publicApiProvider).callWaiter(
            establishmentId: estId,
            locationLabel: mesa,
            clientId: ref.read(clientProfileProvider).clientId,
          );
      if (!mounted) return;
      if (ok) {
        _toast('Avisamos o garçom, ele já vem até a sua mesa 👍');
        // Sucesso: mantém desabilitado por 60s.
        Future.delayed(const Duration(seconds: 60), () {
          if (mounted) setState(() => _calling = false);
        });
      } else {
        _toast('Não foi possível chamar agora. Tente de novo.');
        setState(() => _calling = false);
      }
    } catch (_) {
      if (!mounted) return;
      _toast('Não foi possível chamar agora. Tente de novo.');
      setState(() => _calling = false);
    }
  }

  /// Botão compacto "Chamar garçom" no canto superior direito do checkout.
  Widget _callWaiterButton() => Material(
        color: _calling ? AppColors.inkA(0.06) : AppColors.ink,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: _calling ? null : _callWaiter,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Symbols.room_service, size: 16, color: _calling ? AppColors.inkA(0.4) : AppColors.dune),
                const SizedBox(width: 6),
                Text(
                  _calling ? 'Garçom avisado ✓' : 'Chamar garçom',
                  style: AppText.body(
                      size: 12, weight: FontWeight.w700, color: _calling ? AppColors.inkA(0.45) : AppColors.dune),
                ),
              ],
            ),
          ),
        ),
      );

  /// Toast de recusa de pagamento com ação "Chamar garçom".
  /// Aviso de pagamento recusado: cartão compacto (ícone + título + dica), com
  /// "Chamar garçom" em pílula e X pra fechar. Some sozinho em 5 s.
  void _declineToast(String msg) {
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: EdgeInsets.zero,
      elevation: 0,
      backgroundColor: Colors.transparent,
      content: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 6))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: AppColors.coral.withValues(alpha: 0.18), shape: BoxShape.circle),
              child: const Icon(Symbols.credit_card_off, size: 18, color: AppColors.coral),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Pagamento não aprovado',
                      style: AppText.body(size: 14, weight: FontWeight.w800, color: AppColors.dune)),
                  const SizedBox(height: 2),
                  Text(_declineHint(msg),
                      style: AppText.body(size: 12.5, weight: FontWeight.w500, color: AppColors.duneA(0.75))),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {
                      messenger.hideCurrentSnackBar();
                      _callWaiter();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(color: AppColors.coral, borderRadius: BorderRadius.circular(999)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Symbols.room_service, size: 15, color: Colors.white),
                          const SizedBox(width: 6),
                          Text('Chamar garçom',
                              style: AppText.body(size: 12, weight: FontWeight.w800, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: messenger.hideCurrentSnackBar,
              icon: Icon(Symbols.close, size: 18, color: AppColors.duneA(0.7)),
              visualDensity: VisualDensity.compact,
              tooltip: 'Fechar',
            ),
          ],
        ),
      ),
    ));
  }

  /// Tira o "Pagamento não aprovado." do começo (já é o título) e deixa a dica.
  String _declineHint(String msg) {
    final hint = msg.replaceFirst(RegExp(r'^Pagamento não aprovado\.?\s*'), '').trim();
    return hint.isEmpty ? 'Tente de novo ou escolha outro método.' : hint;
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
    unawaited(_maybeStartFingerprint()); // idempotente (só roda uma vez)

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
          // Fingerprint da Tuna: WebView 1×1 invisível, sem toque nem layout.
          if (_fpTagUrl != null) TunaFingerprintCollector(tagUrl: _fpTagUrl!),
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, topSafe + 20, 20, 170),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                    const Spacer(),
                    _callWaiterButton(),
                  ],
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
    // Débito na carteira (Tuna) → pedido DEBIT; o servidor cobra a carteira como débito.
    final payload = _orderPayload(method: _walletDebitActive ? 'DEBIT' : 'CREDIT');
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
      // Fingerprint só vai quando o Google Pay do bar é cobrado pela Tuna.
      final tunaWallet =
          walletType == 'google_pay' && _cartEst()?.gatewayFor('googlePay') == 'TUNA';
      final r = await ref.read(publicApiProvider).createWalletOrder(id, walletType, token,
          deviceSessionId: tunaWallet ? _deviceSessionId : null);
      if (!mounted) return;
      if (r.ok && r.status == 'paid') {
        _markPending(null);
        ref.read(cartProvider.notifier).clear();
        context.go('/done', extra: DoneArgs(incomplete: false, code: order.code));
      } else if (r.ok && r.status == 'pending') {
        context.go('/pagamento', extra: CardWaitArgs(order: r.order ?? order));
      } else {
        setState(() => _submitting = false);
        _declineToast('Pagamento não aprovado. Tente outro método.');
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
            // Carteiras: na Tuna o cliente escolhe crédito ou débito; nos outros
            // gateways a carteira é cobrada só como crédito.
            if (pm.id == 'apple_pay' || pm.id == 'google_pay') ...[
              if (_walletAllowsDebit(pm.id))
                _fundingToggle(onPick: () => setState(() => _selPay = pm.id))
              else
                Text(
                  'Somente crédito',
                  style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.55)),
                ),
              const SizedBox(width: 10),
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

  /// Seletor compacto "Crédito | Débito" da carteira. Tocar também seleciona a
  /// carteira ([onPick]), pra não precisar de dois toques.
  Widget _fundingToggle({required VoidCallback onPick}) {
    Widget seg(String label, bool debit) {
      final on = _walletDebit == debit;
      return GestureDetector(
        onTap: () {
          setState(() => _walletDebit = debit);
          onPick();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: on ? AppColors.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: AppText.body(size: 11, weight: FontWeight.w700, color: on ? AppColors.dune : AppColors.inkA(0.6)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.inkA(0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [seg('Crédito', false), seg('Débito', true)]),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: _submitting ? AppColors.coral.withValues(alpha: 0.6) : bg,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: enabled ? () => _pay(grand) : null,
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                width: double.infinity,
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
          ),
        ],
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

/// Celular com DDD, só dígitos: DDD (2 dígitos, sem 0 na frente) + número de
/// 8 ou 9 dígitos. Mesma regra pro perfil salvo e pro sheet.
bool _isValidPhone(String digits) =>
    digits.length >= 10 && digits.length <= 11 && !digits.startsWith('0');

/// Sheet pra coletar o celular com DDD (débito PagBank: o banco pede no 3DS).
/// Mesmo padrão do [_CpfSheet]. Devolve só dígitos no pop, ou null se cancelar.
class _PhoneSheet extends StatefulWidget {
  const _PhoneSheet({required this.initial});
  final String initial;

  @override
  State<_PhoneSheet> createState() => _PhoneSheetState();
}

class _PhoneSheetState extends State<_PhoneSheet> {
  late final _ctrl = TextEditingController(text: widget.initial);
  String? _err;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final d = _ctrl.text.replaceAll(RegExp(r'\D'), '');
    if (!_isValidPhone(d)) {
      setState(() => _err = 'Celular inválido — informe o DDD e o número.');
      return;
    }
    Navigator.pop(context, d);
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
          Text('Celular com DDD', style: AppText.display(size: 20, letterSpacing: -0.3)),
          const SizedBox(height: 6),
          Text('O seu banco pede o celular pra confirmar o débito. Pedimos só uma vez — depois fica salvo.',
              style: AppText.body(size: 13, weight: FontWeight.w500, color: AppColors.inkA(0.55))),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: TextInputType.phone,
            maxLength: 11,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofillHints: const [AutofillHints.telephoneNumberNational],
            style: AppText.body(size: 18, weight: FontWeight.w700, letterSpacing: 1),
            onChanged: (_) {
              if (_err != null) setState(() => _err = null);
            },
            decoration: InputDecoration(
              counterText: '',
              hintText: 'DDD + número, só números',
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

/// Sheet pra escolher a mesa quando o cliente entrou sem QR: campo pra buscar/
/// digitar + a LISTA das mesas cadastradas do bar (toque = escolhe). O campo
/// filtra a lista ao digitar e também cria uma mesa nova ("Usar …"). Escolher da
/// lista evita a mesma mesa virar duas ("Mesa 02" vs "Mesa 2").
class _TableSheet extends StatefulWidget {
  final List<String> spots;
  const _TableSheet({required this.spots});

  @override
  State<_TableSheet> createState() => _TableSheetState();
}

class _TableSheetState extends State<_TableSheet> {
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() {})); // filtra a lista ao digitar
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _confirmTyped() {
    final v = _ctrl.text.trim();
    if (v.isNotEmpty) Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final hasSpots = widget.spots.isNotEmpty;
    final typed = _ctrl.text.trim();
    final q = typed.toLowerCase();
    final filtered = q.isEmpty ? widget.spots : widget.spots.where((s) => s.toLowerCase().contains(q)).toList();
    final isExisting = widget.spots.any((s) => s.toLowerCase() == q);
    final canConfirm = typed.isNotEmpty;

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
          Text(
            hasSpots
                ? 'Escolha a sua mesa na lista — ou digite a sua.'
                : 'Diga onde você está pra o pedido chegar no lugar certo.',
            style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.inkA(0.55)),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _confirmTyped(),
            style: AppText.body(size: 15, weight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hasSpots ? 'Buscar ou digitar a mesa' : 'Ex: Mesa 5, Guarda-sol 12',
              hintStyle: AppText.body(size: 15, weight: FontWeight.w500, color: AppColors.inkA(0.4)),
              prefixIcon: Icon(hasSpots ? Symbols.search : Symbols.edit_location_alt, size: 20, color: AppColors.inkA(0.4)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.inkA(0.15), width: 1.5)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.ink, width: 2)),
            ),
          ),
          if (hasSpots) ...[
            const SizedBox(height: 12),
            Text('MESAS DO BAR', style: AppText.body(size: 10, weight: FontWeight.w800, letterSpacing: 0.4, color: AppColors.inkA(0.4))),
            const SizedBox(height: 7),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.3),
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text('Nenhuma mesa com esse nome — toque em "Usar" pra criar.',
                          style: AppText.body(size: 12.5, weight: FontWeight.w600, color: AppColors.inkA(0.45))),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (_, i) => _spotRow(filtered[i]),
                    ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: Material(
              color: canConfirm ? AppColors.coral : AppColors.inkA(0.12),
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                onTap: canConfirm ? _confirmTyped : null,
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: Center(
                    child: Text(
                      canConfirm && hasSpots && !isExisting ? 'Usar "$typed"' : 'Confirmar',
                      style: AppText.body(size: 15, weight: FontWeight.w800, color: canConfirm ? Colors.white : AppColors.inkA(0.4)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _spotRow(String s) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(context, s),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.inkA(0.12), width: 1.5),
          ),
          child: Row(
            children: [
              Icon(Symbols.table_restaurant, size: 18, color: AppColors.inkA(0.6)),
              const SizedBox(width: 10),
              Expanded(child: Text(s, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 14.5, weight: FontWeight.w700))),
              Icon(Symbols.chevron_right, size: 18, color: AppColors.inkA(0.3)),
            ],
          ),
        ),
      );
}
