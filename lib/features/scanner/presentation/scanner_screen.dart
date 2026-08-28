import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/data/public_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';

/// Scanner de QR REAL (câmera via mobile_scanner). Lê o QR da mesa/guarda-sol
/// (`https://jurandir.app.br/?est=<slug>&local=<label>`), extrai o slug do
/// estabelecimento e abre o cardápio dele. Sem permissão de câmera → tela de
/// erro limpa com atalho pras configurações.
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  static const _box = 230.0;
  bool _handled = false;
  bool _torch = false;
  MobileScannerException? _error;
  // Muda a cada "Tentar de novo" — vira a Key do MobileScanner pra forçar um
  // initState novo (e um controller.start() novo). Sem isso, a câmera não
  // reinicia depois que a permissão é liberada.
  int _attempt = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Extrai o slug do estabelecimento do conteúdo do QR.
  String? _slugFromCode(String raw) {
    final v = raw.trim();
    final uri = Uri.tryParse(v);
    if (uri != null) {
      final est = uri.queryParameters['est'];
      if (est != null && est.isNotEmpty) return est;
      if (uri.host.contains('jurandir') && uri.pathSegments.isNotEmpty) {
        final last = uri.pathSegments.last;
        if (last.isNotEmpty) return last;
      }
    }
    if (RegExp(r'^[a-z0-9-]{3,}$').hasMatch(v)) return v;
    return null;
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw == null) continue;
      final slug = _slugFromCode(raw);
      if (slug == null) continue;
      _handled = true;
      _controller.stop();
      ref.read(selectedSlugProvider.notifier).set(slug);
      context.go('/menu');
      return;
    }
  }

  void _toggleTorch() {
    _controller.toggleTorch();
    setState(() => _torch = !_torch);
  }

  /// Registra o erro da câmera pra tela reagir. Só trava na tela de erro quando
  /// é permissão negada ou câmera sem suporte — erros transitórios de startup
  /// (controller ainda inicializando) não devem prender o usuário aqui.
  void _recordError(MobileScannerException error) {
    if (error.errorCode != MobileScannerErrorCode.permissionDenied &&
        error.errorCode != MobileScannerErrorCode.unsupported) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _error == null) setState(() => _error = error);
    });
  }

  Future<void> _openSettings() => openAppSettings();

  /// Pede a permissão da câmera NÓS MESMOS (o pedido interno do mobile_scanner
  /// não reaparece após a 1ª negativa) e, se liberada, recria o controller +
  /// força um MobileScanner novo (via `_attempt`/Key) pra reiniciar a câmera.
  /// Se estiver negada permanentemente, manda pras configurações do app.
  Future<void> _retry() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (!status.isGranted) {
      // 2ª negativa (permanente) → o único caminho é liberar nas configs.
      if (status.isPermanentlyDenied) await openAppSettings();
      return;
    }
    await _controller.dispose();
    if (!mounted) return;
    setState(() {
      _error = null;
      _handled = false;
      _torch = false;
      _attempt++;
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasError = _error != null;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              key: ValueKey(_attempt),
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error, child) {
                _recordError(error);
                return const ColoredBox(color: AppColors.ink);
              },
            ),
            if (!hasError)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xCC141821), Color(0x33141821), Color(0xCC141821)],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
                child: SizedBox.expand(),
              ),
            SafeArea(child: hasError ? _errorView() : _scanningView()),
          ],
        ),
      ),
    );
  }

  Widget _header({required bool showTorch}) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _circleBtn(Symbols.arrow_back, () => context.go('/home')),
          Expanded(
            child: Center(
              child: Text('Escanear QR'.toUpperCase(),
                  style: AppText.display(size: 16, letterSpacing: 0, color: Colors.white)),
            ),
          ),
          showTorch
              ? _circleBtn(_torch ? Symbols.flash_on : Symbols.flash_off, _toggleTorch)
              : const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _scanningView() {
    return Column(
      children: [
        _header(showTorch: true),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: _box,
                  height: _box,
                  child: Stack(
                    children: [
                      _corner(top: 0, left: 0),
                      _corner(top: 0, right: 0),
                      _corner(bottom: 0, left: 0),
                      _corner(bottom: 0, right: 0),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Aponte para o QR na sua mesa ou guarda-sol.',
                    textAlign: TextAlign.center,
                    style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.duneA(0.75)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorView() {
    return Column(
      children: [
        _header(showTorch: false),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              Container(
                width: 76,
                height: 76,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.duneA(0.12), shape: BoxShape.circle),
                child: const Icon(Symbols.no_photography, size: 38, color: AppColors.dune),
              ),
              const SizedBox(height: 18),
              Text(
                'Precisamos da câmera pra ler o QR da sua mesa',
                textAlign: TextAlign.center,
                style: AppText.display(size: 20, letterSpacing: -0.3, color: Colors.white),
              ),
              const SizedBox(height: 10),
              Text(
                'Libere o acesso à câmera nas configurações do app e toque em "Tentar de novo".',
                textAlign: TextAlign.center,
                style: AppText.body(size: 14, height: 1.45, color: AppColors.duneA(0.7)),
              ),
              const SizedBox(height: 26),
              AppButton.primary(
                label: 'Abrir configurações',
                icon: Symbols.settings,
                onPressed: _openSettings,
              ),
              const SizedBox(height: 10),
              AppButton.dark(
                label: 'Tentar de novo',
                icon: Symbols.refresh,
                onPressed: _retry,
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => context.go('/home'),
                child: Text('Voltar',
                    style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.dune)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.duneA(0.14), shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: AppColors.dune),
      ),
    );
  }

  Widget _corner({double? top, double? bottom, double? left, double? right}) {
    const side = BorderSide(color: AppColors.amber, width: 3);
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          border: Border(
            top: top != null ? side : BorderSide.none,
            bottom: bottom != null ? side : BorderSide.none,
            left: left != null ? side : BorderSide.none,
            right: right != null ? side : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
