import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../../core/payments/threeds.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Tempo máximo da confirmação com o banco. Passou disso → falha (não cobra).
const Duration _kThreeDsTimeout = Duration(minutes: 5);

/// Abre a tela "Confirmação do banco" (3DS do PagBank) em tela cheia e devolve
/// o resultado. A página hospedada (`pageUrl`) roda o SDK do PagBank; o app só
/// injeta `{session, env, data}` quando ela avisa que está pronta e escuta o
/// resultado pelo canal JS `ThreeDS`. Fechar/voltar → [ThreeDsCancelled].
///
/// `data` tem o número do cartão: fica só em memória — nunca logar.
Future<ThreeDsOutcome> runThreeDs(
  BuildContext context, {
  required String pageUrl,
  required ThreeDsSession session,
  required Map<String, dynamic> data,
}) async {
  final outcome = await Navigator.of(context, rootNavigator: true).push<ThreeDsOutcome>(
    MaterialPageRoute<ThreeDsOutcome>(
      fullscreenDialog: true,
      builder: (_) => _ThreeDsScreen(pageUrl: pageUrl, session: session, data: data),
    ),
  );
  return outcome ?? const ThreeDsCancelled();
}

class _ThreeDsScreen extends StatefulWidget {
  const _ThreeDsScreen({required this.pageUrl, required this.session, required this.data});
  final String pageUrl;
  final ThreeDsSession session;
  final Map<String, dynamic> data;

  @override
  State<_ThreeDsScreen> createState() => _ThreeDsScreenState();
}

class _ThreeDsScreenState extends State<_ThreeDsScreen> {
  late final WebViewController _controller;
  Timer? _timeout;
  bool _ready = false; // a página avisou "ready" (SDK carregado)
  bool _started = false; // já chamamos window.jurandir3ds.start (uma vez só)
  bool _done = false; // já devolvemos um resultado
  bool _loading = true; // barra fina no topo até a página carregar

  @override
  void initState() {
    super.initState();
    _timeout = Timer(_kThreeDsTimeout, () => _finish(const ThreeDsFailed('TIMEOUT')));
    _controller = _buildController();
    unawaited(_configureAndLoad());
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  /// Controller novo a cada execução. iOS: mídia inline e sem exigir toque
  /// (algumas páginas de banco usam vídeo/áudio no desafio).
  WebViewController _buildController() {
    PlatformWebViewControllerCreationParams params = const PlatformWebViewControllerCreationParams();
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else if (WebViewPlatform.instance is AndroidWebViewPlatform) {
      params = AndroidWebViewControllerCreationParams.fromPlatformWebViewControllerCreationParams(params);
    }
    return WebViewController.fromPlatformCreationParams(params);
  }

  Future<void> _configureAndLoad() async {
    final c = _controller;
    try {
      await c.setJavaScriptMode(JavaScriptMode.unrestricted);
      await c.setBackgroundColor(AppColors.dune); // mesma cor da página (sem flash branco)
      // O canal precisa existir ANTES de carregar a página.
      await c.addJavaScriptChannel('ThreeDS', onMessageReceived: _onMessage);
      await c.setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: _onNavigationRequest,
        onPageFinished: (_) {
          if (mounted && _loading) setState(() => _loading = false);
        },
        onWebResourceError: _onWebResourceError,
        onHttpError: _onHttpError,
      ));
      // `window.confirm` = o "desafio" do SANDBOX. Sem handler, o Android
      // responde "não" e o 3DS falha calado — usamos um diálogo nosso.
      await c.setOnJavaScriptConfirmDialog(_onConfirm);
      await c.setOnJavaScriptAlertDialog(_onAlert);

      final platform = c.platform;
      if (platform is AndroidWebViewController) {
        // O desafio do banco roda em iframes de terceiros (Cardinal/banco) que
        // dependem de cookies de terceiros — no Android vêm desligados.
        // (DOM storage o plugin já liga sozinho.)
        await AndroidWebViewCookieManager(const PlatformWebViewCookieManagerCreationParams())
            .setAcceptThirdPartyCookies(platform, true);
        await platform.setMediaPlaybackRequiresUserGesture(false);
        // Engole o console da página/iframes de terceiros (não vai pro logcat).
        await c.setOnConsoleMessage((_) {});
      }

      await c.loadRequest(Uri.parse(widget.pageUrl));
    } catch (_) {
      _finish(const ThreeDsFailed('PAGE_LOAD'));
    }
  }

  /// Deixa navegar em https (e esquemas internos do navegador) e na própria
  /// página (http só em ambiente local). Subframes (iframes do Cardinal/banco)
  /// nem passam por aqui no plugin — nunca são bloqueados.
  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;
    if (!request.isMainFrame || _samePage(uri)) return NavigationDecision.navigate;
    const allowed = {'https', 'about', 'data', 'blob'};
    return allowed.contains(uri.scheme.toLowerCase()) ? NavigationDecision.navigate : NavigationDecision.prevent;
  }

  /// Erro de carga da PÁGINA PRINCIPAL → falha. Erros de subrecursos/iframes
  /// e navegações canceladas (-999 no iOS) não contam.
  void _onWebResourceError(WebResourceError error) {
    if (error.isForMainFrame != true) return;
    if (error.errorCode == -999) return; // NSURLErrorCancelled (navegação substituída)
    if (error is WebKitWebResourceError && error.domain == 'WebKitErrorDomain' && error.errorCode == 102) {
      return; // "Frame load interrupted" (navegação cancelada pela política)
    }
    _finish(const ThreeDsFailed('PAGE_LOAD'));
  }

  /// HTTP 4xx/5xx da nossa página (ex.: backend fora do ar) antes de ela ficar
  /// pronta → falha na hora em vez de esperar o timeout. Depois do "ready" só
  /// sobram recursos/iframes do banco, que não são da nossa conta.
  void _onHttpError(HttpResponseError error) {
    if (_ready || _done) return;
    final status = error.response?.statusCode ?? 0;
    if (status < 400) return;
    final uri = error.request?.uri;
    // Android manda a URL do recurso (pode ser o SDK) → só conta a página.
    // iOS só informa navegações e sem a URL → só conta enquanto a página
    // principal ainda está carregando (antes disso não há iframe nenhum).
    if (uri != null ? !_samePage(uri) : !_loading) return;
    _finish(const ThreeDsFailed('PAGE_LOAD'));
  }

  bool _samePage(Uri uri) {
    final page = Uri.parse(widget.pageUrl);
    String trim(String p) => p.replaceAll(RegExp(r'/+$'), '');
    return uri.scheme == page.scheme && uri.host == page.host && uri.port == page.port && trim(uri.path) == trim(page.path);
  }

  void _onMessage(JavaScriptMessage message) {
    if (_done) return;
    final raw = message.message; // pode ter mensagem de erro — não logar
    final outcome = parseThreeDsMessage(raw);
    if (outcome != null) {
      _finish(outcome);
      return;
    }
    switch (_messageType(raw)) {
      case 'ready':
        unawaited(_start());
      case 'result':
        // Resultado com status desconhecido/nulo: o SDK já terminou e nada mais
        // vai chegar — falha agora em vez de esperar o timeout.
        _finish(const ThreeDsFailed('UNKNOWN_STATUS'));
      default:
        break; // 'challenge' e afins: só seguir mostrando a página
    }
  }

  String? _messageType(String raw) {
    try {
      final d = jsonDecode(raw);
      if (d is Map && d['type'] is String) return d['type'] as String;
    } catch (_) {}
    return null;
  }

  /// Injeta os dados na página (uma vez só). Nunca logar o script (tem o cartão).
  ///
  /// O canal `ThreeDS` fica visível pra qualquer frame/origem (iframes do
  /// banco, ou o frame principal se navegar pra outro https). Por isso só
  /// injeta se o frame principal AINDA estiver na nossa página — checado aqui
  /// (sem consumir o start se falhar: um "ready" legítimo depois ainda vale) e
  /// de novo dentro do script, atomicamente, antes de chamar o `start`.
  Future<void> _start() async {
    if (_started || _done) return;
    final String expected;
    final Uri? current;
    try {
      final page = Uri.parse(widget.pageUrl);
      expected = '${page.origin}${page.path}'.replaceAll(RegExp(r'/+$'), '');
      current = Uri.tryParse(await _controller.currentUrl() ?? '');
    } catch (_) {
      return; // não deu pra conferir → não injeta
    }
    if (_started || _done || current == null || !_samePage(current)) return;
    _started = true;
    _ready = true;
    final params = jsonEncode({
      'session': widget.session.session,
      'env': widget.session.env,
      'data': widget.data,
    });
    final script = '(function(){'
        "var here=(window.location.origin+window.location.pathname).replace(/\\/+\$/,'');"
        'if(here===${jsonEncode(expected)}&&window.jurandir3ds){window.jurandir3ds.start($params);}'
        '})()';
    try {
      await _controller.runJavaScript(script);
    } catch (_) {
      _finish(const ThreeDsFailed('JS_START'));
    }
  }

  Future<bool> _onConfirm(JavaScriptConfirmDialogRequest request) async {
    if (!mounted || _done) return false;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.canvas,
        title: Text('Confirmar pagamento?', style: AppText.display(size: 18)),
        content: request.message.trim().isEmpty
            ? null
            : Text(request.message, style: AppText.body(size: 14, color: AppColors.inkA(0.75))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar', style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.inkA(0.6))),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Confirmar', style: AppText.body(size: 14, weight: FontWeight.w800, color: AppColors.coralDeep)),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _onAlert(JavaScriptAlertDialogRequest request) async {
    if (!mounted || _done || request.message.trim().isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.canvas,
        content: Text(request.message, style: AppText.body(size: 14, color: AppColors.inkA(0.75))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('OK', style: AppText.body(size: 14, weight: FontWeight.w800, color: AppColors.coralDeep)),
          ),
        ],
      ),
    );
  }

  /// Devolve o resultado uma vez só. Se houver um diálogo nosso aberto em cima
  /// (ex.: timeout com o "Confirmar pagamento?" na tela), fecha ele antes.
  void _finish(ThreeDsOutcome outcome) {
    if (_done) return;
    _done = true;
    _timeout?.cancel();
    if (!mounted) return;
    // Descarta a página (e a memória JS dela, que tinha o cartão).
    try {
      unawaited(_controller.loadRequest(Uri.parse('about:blank')).catchError((Object _) {}));
    } catch (_) {}
    final nav = Navigator.of(context);
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) nav.popUntil((r) => r == route);
    nav.pop(outcome);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // voltar do Android = cancelar (devolve o resultado)
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish(const ThreeDsCancelled());
      },
      child: Scaffold(
        backgroundColor: AppColors.dune,
        appBar: AppBar(
          backgroundColor: AppColors.canvas,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: IconButton(
            tooltip: 'Fechar',
            icon: const Icon(Symbols.close, color: AppColors.ink),
            onPressed: () => _finish(const ThreeDsCancelled()),
          ),
          title: Text('Confirmação do banco', style: AppText.display(size: 18)),
          centerTitle: false,
          bottom: _loading
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(2),
                  child: LinearProgressIndicator(minHeight: 2, color: AppColors.coral, backgroundColor: Colors.transparent),
                )
              : null,
        ),
        // A própria página tem o spinner e abre o desafio do banco — nada por
        // cima dela.
        body: SafeArea(top: false, child: WebViewWidget(controller: _controller)),
      ),
    );
  }
}
