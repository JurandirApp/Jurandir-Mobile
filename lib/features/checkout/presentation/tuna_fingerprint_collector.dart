import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../../core/payments/tuna_fingerprint.dart';

/// WebView invisível que roda o `tags.js` da CyberSource (device fingerprint do
/// antifraude da Tuna) enquanto o checkout está aberto. Não ocupa espaço, não
/// recebe toque e morre junto com a tela (o platform view é descartado quando o
/// widget sai da árvore).
///
/// Vai num `Stack` (é um `Positioned` 1×1 no canto). Fica PINTADO com opacidade
/// quase zero de propósito: com `Opacity(0)` o Flutter pula a pintura e alguns
/// platform views nem chegam a ser compostos/rodar.
///
/// Falhas são engolidas: sem fingerprint o pagamento segue normal.
/// Nunca logar a URL (contém o id da sessão do dispositivo).
class TunaFingerprintCollector extends StatefulWidget {
  const TunaFingerprintCollector({super.key, required this.tagUrl});

  /// URL do `tags.js` (ver [tunaFingerprintTagUrl]).
  final String tagUrl;

  @override
  State<TunaFingerprintCollector> createState() => _TunaFingerprintCollectorState();
}

class _TunaFingerprintCollectorState extends State<TunaFingerprintCollector> {
  final WebViewController _controller = WebViewController();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final c = _controller;
    try {
      await c.setJavaScriptMode(JavaScriptMode.unrestricted);
      await c.setBackgroundColor(Colors.transparent);
      final platform = c.platform;
      if (platform is AndroidWebViewController) {
        // O tags.js grava cookies em online-metrix.net (terceiro em relação à
        // base jurandir.app.br) — no Android vêm desligados.
        await AndroidWebViewCookieManager(const PlatformWebViewCookieManagerCreationParams())
            .setAcceptThirdPartyCookies(platform, true);
        // Engole o console da página (não vai pro logcat).
        await c.setOnConsoleMessage((_) {});
      }
      await c.loadHtmlString(
        tunaFingerprintHtml(widget.tagUrl),
        baseUrl: 'https://jurandir.app.br',
      );
    } catch (_) {
      // Best-effort: sem fingerprint a cobrança segue.
    }
  }

  @override
  Widget build(BuildContext context) => Positioned(
        left: 0,
        top: 0,
        width: 1,
        height: 1,
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: Opacity(
              opacity: 0.01,
              child: WebViewWidget(controller: _controller),
            ),
          ),
        ),
      );
}
