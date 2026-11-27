import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/data/onboarding_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../l10n/i18n.dart';

class _Slide {
  final IconData icon;
  final String title; // chave de tradução
  final String desc; // chave de tradução
  const _Slide(this.icon, this.title, this.desc);
}

const _slides = <_Slide>[
  _Slide(
    Symbols.qr_code_scanner,
    'onboarding.slide1Title',
    'onboarding.slide1Desc',
  ),
  _Slide(
    Symbols.restaurant,
    'onboarding.slide2Title',
    'onboarding.slide2Desc',
  ),
  _Slide(
    Symbols.group,
    'onboarding.slide3Title',
    'onboarding.slide3Desc',
  ),
];

/// Onboarding: 3 slides (ícone + título + descrição), dots e CTA.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _i = 0;

  /// Marca a apresentação como vista (persistente) e vai pra Home.
  /// A partir daqui o onboarding não reaparece — nem ao reabrir o app,
  /// nem ao logar/deslogar.
  void _finish() {
    ref.read(onboardingProvider).markSeen();
    context.go('/home');
  }

  void _next() {
    if (_i < _slides.length - 1) {
      setState(() => _i++);
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_i];
    final isLast = _i == _slides.length - 1;
    final pad = MediaQuery.paddingOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(24, pad.top + 20, 24, 0),
              child: Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _finish,
                  child: Text(
                    context.tr('onboarding.skip'),
                    style: AppText.body(
                      size: 13,
                      weight: FontWeight.w700,
                      color: AppColors.duneA(0.6),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        key: ValueKey(_i),
                        width: 96,
                        height: 96,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.coral,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Icon(slide.icon, size: 48, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      context.tr(slide.title).toUpperCase(),
                      textAlign: TextAlign.center,
                      style: AppText.onboardTitle.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: Text(
                        context.tr(slide.desc),
                        textAlign: TextAlign.center,
                        style: AppText.body(
                          size: 15,
                          height: 1.6,
                          color: AppColors.duneA(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, pad.bottom + 40),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var d = 0; d < _slides.length; d++) ...[
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: d == _i ? 22 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: d == _i ? AppColors.coral : AppColors.duneA(0.25),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        if (d < _slides.length - 1) const SizedBox(width: 6),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  AppButton.primary(
                    label: isLast ? context.tr('onboarding.start') : context.tr('onboarding.next'),
                    onPressed: _next,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
