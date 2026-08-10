import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';

/// Scanner QR: viewfinder com cantos + linha de scan animada.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  static const _box = 230.0;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.go('/home'),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: AppColors.duneA(0.12), shape: BoxShape.circle),
                        child: const Icon(Symbols.arrow_back, size: 20, color: AppColors.dune),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text('Escanear QR'.toUpperCase(),
                            style: AppText.display(size: 16, letterSpacing: 0, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 40),
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
                          style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.duneA(0.6)),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: AppButton.primary(
                          label: 'Simular leitura — Guarda-sol nº 14',
                          onPressed: () => context.go('/menu'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
