import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../../core/data/models.dart';
import '../../../core/payments/tuna_threeds.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/i18n.dart';

// 3DS da Tuna (débito) — parte com WebView. A lógica pura (HTML, parsing) fica
// em core/payments/tuna_threeds.dart. Nunca logar JWT/token/URLs com dados.

/// Base das páginas montadas com `loadHtmlString` (mesma do fingerprint).
const String _kBaseUrl = 'https://jurandir.app.br';

/// Controller com as permissões que páginas de banco/Cardinal precisam: JS,
/// cookies de terceiros (Android) e mídia inline sem toque (iOS).
Future<WebViewController> _newController({Color background = Colors.transparent}) async {
  PlatformWebViewControllerCreationParams params = const PlatformWebViewControllerCreationParams();
  if (WebViewPlatform.instance is WebKitWebViewPlatform) {
    params = WebKitWebViewControllerCreationParams(
      allowsInlineMediaPlayback: true,
      mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
    );
  } else if (WebViewPlatform.instance is AndroidWebViewPlatform) {
    params = AndroidWebViewControllerCreationParams.fromPlatformWebViewControllerCreationParams(params);
  }
  final c = WebViewController.fromPlatformCreationParams(params);
  await c.setJavaScriptMode(JavaScriptMode.unrestricted);
  await c.setBackgroundColor(background);
  final platform = c.platform;
  if (platform is AndroidWebViewController) {
    // Cardinal/banco rodam em domínios de terceiros que dependem de cookies.
    await AndroidWebViewCookieManager(const PlatformWebViewCookieManagerCreationParams())
        .setAcceptThirdPartyCookies(platform, true);
    await platform.setMediaPlaybackRequiresUserGesture(false);
    // Engole o console das páginas de terceiros (não vai pro logcat).
    await c.setOnConsoleMessage((_) {});
  }
  return c;
}

// ---- DDC (Device Data Collection) -------------------------------------------

/// Roda a coleta de dados do aparelho do Cardinal numa WebView invisível (1×1,
/// num OverlayEntry por cima de tudo) e espera o "profile.completed" — no
/// máximo [timeout]. Best-effort: devolve true se completou, false se não deu
/// (sem overlay, sem dados, erro, timeout); a cobrança segue nos dois casos.
Future<bool> runTunaDdc(
  BuildContext context,
  TunaAuthInfo auth, {
  Duration timeout = const Duration(seconds: 12),
}) async {
  if (!auth.canCollect) return false;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return false;
  final done = Completer<bool>();
  void complete(bool ok) {
    if (!done.isCompleted) done.complete(ok);
  }

  final entry = OverlayEntry(
    builder: (_) => _TunaDdcCollector(
      html: tunaDdcHtml(url: auth.deviceDataCollectionUrl!, jwt: auth.accessToken!),
      onDone: complete,
    ),
  );
  overlay.insert(entry);
  final timer = Timer(timeout, () => complete(false));
  try {
    return await done.future;
  } finally {
    timer.cancel();
    entry.remove();
  }
}

class _TunaDdcCollector extends StatefulWidget {
  const _TunaDdcCollector({required this.html, required this.onDone});
  final String html;
  final void Function(bool ok) onDone;

  @override
  State<_TunaDdcCollector> createState() => _TunaDdcCollectorState();
}

class _TunaDdcCollectorState extends State<_TunaDdcCollector> {
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final c = await _newController();
      // O canal precisa existir ANTES de carregar a página.
      await c.addJavaScriptChannel(tunaDdcChannel, onMessageReceived: (m) {
        widget.onDone(m.message == 'completed');
      });
      if (!mounted) return;
      setState(() => _controller = c);
      await c.loadHtmlString(widget.html, baseUrl: _kBaseUrl);
    } catch (_) {
      widget.onDone(false); // best-effort: segue sem DDC
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    // Fica PINTADA com opacidade quase zero (com 0 o platform view pode nem rodar).
    return Positioned(
      left: 0,
      top: 0,
      width: 1,
      height: 1,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: Opacity(
            opacity: 0.01,
            child: c == null ? const SizedBox.shrink() : WebViewWidget(controller: c),
          ),
        ),
      ),
    );
  }
}

// ---- Desafio (step-up) -------------------------------------------------------

/// Resultado do desafio 3DS da Tuna.
sealed class TunaChallengeOutcome {
  const TunaChallengeOutcome();
}

/// O pedido foi pago (o banco autorizou e a Tuna aprovou).
class TunaChallengePaid extends TunaChallengeOutcome {
  const TunaChallengePaid(this.order);
  final ClientOrder order;
}

/// O banco devolveu o resultado e o pedido não foi pago (negado/cancelado no banco).
class TunaChallengeDeclined extends TunaChallengeOutcome {
  const TunaChallengeDeclined();
}

/// O cliente fechou a tela antes de o pedido ser pago.
class TunaChallengeCancelled extends TunaChallengeOutcome {
  const TunaChallengeCancelled();
}

/// Passou do tempo máximo sem resposta (o pagamento ainda pode confirmar).
class TunaChallengeTimeout extends TunaChallengeOutcome {
  const TunaChallengeTimeout();
}

/// Abre a tela "Confirmação do banco" com o desafio da Tuna. O resultado vai do
/// banco direto pra Tuna; o app só acompanha o pedido ([fetchOrder], a cada
/// [pollEvery]) e fecha quando ele fica pago. Quando a página sai do Cardinal
/// pra URL de retorno da Tuna (o banco terminou), espera mais
/// [graceAfterReturn]: se não pagou, é recusa. Sem nada em [maxWait] → timeout.
Future<TunaChallengeOutcome> runTunaChallenge(
  BuildContext context, {
  required TunaChallenge challenge,
  required Future<ClientOrder?> Function() fetchOrder,
  Future<String?> Function()? fetchChargeStatus,
  Duration pollEvery = const Duration(seconds: 3),
  Duration maxWait = const Duration(minutes: 5),
  Duration graceAfterReturn = const Duration(seconds: 30),
}) async {
  final outcome = await Navigator.of(context, rootNavigator: true).push<TunaChallengeOutcome>(
    MaterialPageRoute<TunaChallengeOutcome>(
      fullscreenDialog: true,
      builder: (_) => _TunaChallengeScreen(
        challenge: challenge,
        fetchOrder: fetchOrder,
        fetchChargeStatus: fetchChargeStatus,
        pollEvery: pollEvery,
        maxWait: maxWait,
        graceAfterReturn: graceAfterReturn,
      ),
    ),
  );
  return outcome ?? const TunaChallengeCancelled();
}

/// Pedido pago = em produção ou entregue (mesma regra da tela de espera).
bool _isPaid(ClientOrder? o) => o != null && (o.status == 'producao' || o.status == 'entregue');

bool _hostIs(String host, List<String> domains) {
  final h = host.toLowerCase();
  return domains.any((d) => h == d || h.endsWith('.$d'));
}

/// Host do Cardinal (step-up).
bool _isCardinalHost(String host) => _hostIs(host, const ['cardinaltrusted.com', 'cardinalcommerce.com']);

/// Host da Tuna (URL de retorno do step-up). Só com o retorno CONFIRMADO num
/// host da Tuna a tela conclui "o banco terminou" — uma página de banco no
/// frame principal não pode virar recusa enquanto o cliente ainda autoriza.
bool _isTunaHost(String host) => _hostIs(host, const ['tunagateway.com', 'tuna.uy', 'tuna-demo.uy']);

class _TunaChallengeScreen extends StatefulWidget {
  const _TunaChallengeScreen({
    required this.challenge,
    required this.fetchOrder,
    this.fetchChargeStatus,
    required this.pollEvery,
    required this.maxWait,
    required this.graceAfterReturn,
  });
  final TunaChallenge challenge;
  final Future<ClientOrder?> Function() fetchOrder;
  /// Situação da cobrança na Tuna (paid | failed | pending), via
  /// GET /tuna/card-status — detecta a RECUSA na hora (o pedido continua
  /// "aguardando" quando o banco recusa, então só o pedido não basta).
  final Future<String?> Function()? fetchChargeStatus;
  final Duration pollEvery;
  final Duration maxWait;
  final Duration graceAfterReturn;

  @override
  State<_TunaChallengeScreen> createState() => _TunaChallengeScreenState();
}

class _TunaChallengeScreenState extends State<_TunaChallengeScreen> {
  WebViewController? _controller;
  Timer? _poll;
  Timer? _timeout;
  Timer? _grace;
  bool _done = false;
  bool _loading = true;
  bool _checking = false;
  bool _sawCardinal = false; // o step-up do Cardinal chegou a abrir
  bool _returned = false; // a página saiu do Cardinal (resultado foi pra Tuna)

  @override
  void initState() {
    super.initState();
    _timeout = Timer(widget.maxWait, () => _finish(const TunaChallengeTimeout()));
    _poll = Timer.periodic(widget.pollEvery, (_) => unawaited(_check()));
    unawaited(_load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _timeout?.cancel();
    _grace?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final c = await _newController(background: Colors.white);
      await c.setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: _onNavigationRequest,
        onPageStarted: _onUrl,
        onUrlChange: (change) => _onUrl(change.url ?? ''),
        onPageFinished: (_) {
          if (mounted && _loading) setState(() => _loading = false);
        },
      ));
      if (!mounted) return;
      setState(() => _controller = c);
      await c.loadHtmlString(tunaChallengeHtml(widget.challenge), baseUrl: _kBaseUrl);
    } catch (_) {
      // Sem a página do banco não há como autorizar — segue acompanhando o
      // pedido (pode já ter sido resolvido) até o cliente fechar.
      if (mounted) setState(() => _loading = false);
    }
  }

  /// https/about/data/blob navegam na WebView. Outros esquemas (ex.: link pro
  /// app do banco) abrem fora; nunca navegam aqui dentro.
  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;
    const allowed = {'https', 'about', 'data', 'blob'};
    if (allowed.contains(uri.scheme.toLowerCase())) return NavigationDecision.navigate;
    if (request.isMainFrame || uri.scheme != 'http') {
      unawaited(launchUrl(uri, mode: LaunchMode.externalApplication).catchError((Object _) => false));
    }
    return NavigationDecision.prevent;
  }

  /// Acompanha o frame principal: saiu do Cardinal pra URL de retorno da Tuna
  /// → o banco terminou; dá um tempo pro pedido virar pago.
  void _onUrl(String url) {
    if (_done) return;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return;
    if (_isCardinalHost(uri.host)) {
      _sawCardinal = true;
      return;
    }
    if (!_sawCardinal || _returned || !_isTunaHost(uri.host)) return;
    _returned = true;
    unawaited(_check());
    _grace = Timer(widget.graceAfterReturn, () async {
      await _check();
      if (!_done) _finish(const TunaChallengeDeclined());
    });
  }

  Future<void> _check() async {
    if (_done || _checking) return;
    _checking = true;
    try {
      final o = await widget.fetchOrder();
      if (_isPaid(o)) return _finish(TunaChallengePaid(o!));
      final st = await widget.fetchChargeStatus?.call();
      if (st == 'failed') _finish(const TunaChallengeDeclined());
    } catch (_) {
      // rede: tenta de novo no próximo ciclo
    } finally {
      _checking = false;
    }
  }

  /// Fechar: confere uma última vez (o banco pode ter acabado de aprovar).
  Future<void> _close() async {
    if (_done) return;
    try {
      final o = await widget.fetchOrder().timeout(const Duration(seconds: 6));
      if (_isPaid(o)) return _finish(TunaChallengePaid(o!));
    } catch (_) {}
    _finish(_returned ? const TunaChallengeDeclined() : const TunaChallengeCancelled());
  }

  void _finish(TunaChallengeOutcome outcome) {
    if (_done) return;
    _done = true;
    _poll?.cancel();
    _timeout?.cancel();
    _grace?.cancel();
    if (!mounted) return;
    // Descarta a página (JWT do desafio fica só na memória dela).
    try {
      unawaited(_controller?.loadRequest(Uri.parse('about:blank')).catchError((Object _) {}));
    } catch (_) {}
    Navigator.of(context).pop(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final size = tunaChallengeWindowSize(widget.challenge.paRequest);
    return PopScope(
      canPop: false, // voltar do Android = fechar (confere o pedido antes)
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close());
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: AppColors.canvas,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: IconButton(
            tooltip: context.tr('checkout.close'),
            icon: const Icon(Symbols.close, color: AppColors.ink),
            onPressed: () => unawaited(_close()),
          ),
          title: Text(context.tr('checkout.bankConfirmation'), style: AppText.display(size: 18)),
          centerTitle: false,
          bottom: _loading || _returned
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(2),
                  child: LinearProgressIndicator(minHeight: 2, color: AppColors.coral, backgroundColor: Colors.transparent),
                )
              : null,
        ),
        body: SafeArea(
          top: false,
          child: c == null
              ? const SizedBox.expand()
              : LayoutBuilder(builder: (context, box) {
                  final web = WebViewWidget(controller: c);
                  // Janela pedida pelo banco (challengeWindowSize): usa se couber;
                  // senão (ou 05/sem info) ocupa a tela toda.
                  if (size == null || size.width > box.maxWidth || size.height > box.maxHeight) return web;
                  return Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(width: size.width, height: size.height, child: web),
                  );
                }),
        ),
      ),
    );
  }
}
