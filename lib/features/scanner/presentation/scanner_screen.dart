import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/data/public_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Scanner de QR REAL (câmera via mobile_scanner). Lê o QR da mesa/guarda-sol
/// (`https://jurandir.app.br/?est=<slug>&local=<label>`), extrai o slug do
/// estabelecimento e abre o cardápio dele.
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  late final AnimationController _c;
  static const _box = 230.0;
  bool _handled = false;
  bool _torch = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Extrai o slug do estabelecimento do conteúdo do QR. Aceita a URL do painel
  /// (`...?est=<slug>`), uma URL `.../<slug>` ou o slug puro. `null` = QR alheio.
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
    if (RegExp(r'^[a-z0-9-]{3,}$').hasMatch(v)) return v; // slug puro
    return null;
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw == null) continue;
      final slug = _slugFromCode(raw);
      if (slug == null) continue; // ignora QR que não é do Jurandir
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

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error, child) => _cameraError(error),
            ),
            // Escurece topo/base pra legibilidade dos textos/botões.
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
            SafeArea(
              child: Column(
                children: [
                  Padding(
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
                        _circleBtn(_torch ? Symbols.flash_on : Symbols.flash_off, _toggleTorch),
                      ],
                    ),
                  ),
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
                                AnimatedBuilder(
                                  animation: _c,
                                  builder: (context, _) => Positioned(
                                    left: 10,
                                    right: 10,
                                    top: _box * (0.08 + 0.8 * _c.value) - 1,
                                    child: Container(
                                      height: 2,
                                      decoration: BoxDecoration(
                                        color: AppColors.coral,
                                        boxShadow: [
                                          BoxShadow(color: AppColors.coral.withValues(alpha: 0.8), blurRadius: 16),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
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
              ),
            ),
          ],
        ),
      ),
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

  Widget _cameraError(MobileScannerException error) {
    return Container(
      color: AppColors.ink,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Symbols.no_photography, size: 48, color: AppColors.dune),
          const SizedBox(height: 14),
          Text(
            'Precisamos da câmera pra ler o QR da sua mesa. '
            'Libere o acesso à câmera nas configurações e tente de novo.',
            textAlign: TextAlign.center,
            style: AppText.body(size: 14, color: AppColors.duneA(0.8)),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => context.go('/home'),
            child: Text('Voltar', style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.coral)),
          ),
        ],
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
