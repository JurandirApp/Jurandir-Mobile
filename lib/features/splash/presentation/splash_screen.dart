import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/onboarding_controller.dart';
import '../../auth/auth_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Splash: logo animado + tagline + barra de progresso; auto-avança em 2s.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    _timer = Timer(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      // Sessão persistida: estab/admin voltam direto pro painel.
      final auth = ref.read(authProvider);
      if (auth.isAuthed && auth.role == 'estab') {
        context.go('/estab/pedidos');
        return;
      }
      if (auth.isAuthed && auth.role == 'admin') {
        context.go('/admin/dashboard');
        return;
      }
      // Onboarding só aparece uma vez (flag persistente em shared_preferences).
      final seen = ref.read(onboardingProvider).seen;
      context.go(seen ? '/home' : '/onboarding');
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logo = CurvedAnimation(
      parent: _c,
      curve: const Interval(0, 0.7, curve: Curves.easeOutBack),
    );
    final tag = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.3, 0.85, curve: Curves.easeOut),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _c,
                builder: (context, child) {
                  final t = logo.value.clamp(0.0, 1.0);
                  return Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, (1 - t) * 16),
                      child: Transform.scale(
                        scale: 0.94 + 0.06 * t,
                        child: child,
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SvgPicture.asset(
                    'assets/images/jurandir-logo-horizontal.svg',
                    width: 260,
                  ),
                ),
              ),
              const SizedBox(height: 26),
              FadeTransition(
                opacity: tag,
                child: Text('SEU GARÇOM DIGITAL', style: AppText.splashTag),
              ),
              const SizedBox(height: 40),
              AnimatedBuilder(
                animation: _c,
                builder: (context, _) => Container(
                  width: 180,
                  height: 4,
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: AppColors.duneA(0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: FractionallySizedBox(
                    widthFactor: _c.value,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.coral,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
