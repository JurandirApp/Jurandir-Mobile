import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';

/// Argumentos passados pelo Checkout via `go('/done', extra: ...)`.
class DoneArgs {
  final bool incomplete;
  final String code;
  const DoneArgs({required this.incomplete, required this.code});
}

/// Pedido confirmado: status (pago / falta gente pagar), código e ações.
class DoneScreen extends StatelessWidget {
  const DoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = GoRouterState.of(context).extra as DoneArgs?;
    final incomplete = args?.incomplete ?? false;
    final code = args?.code ?? '—';

    final bg = incomplete ? AppColors.warning : AppColors.success;
    final icon = incomplete ? Symbols.schedule : Symbols.check;
    final title = incomplete ? 'Falta gente pagar' : 'Pedido confirmado!';
    final sub = incomplete
        ? 'Seu pedido vai à cozinha quando todos pagarem. Complete em Pedidos.'
        : 'Pagamento confirmado! O estabelecimento já está preparando. Acompanhe em Pedidos.';

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, size: 44, color: Colors.white),
              ),
              const SizedBox(height: 18),
              Text(title.toUpperCase(), textAlign: TextAlign.center, style: AppText.display(size: 26, letterSpacing: -0.5)),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Text(sub, textAlign: TextAlign.center, style: AppText.body(size: 14, color: AppColors.inkA(0.6))),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.ink, width: 2),
                  boxShadow: const [BoxShadow(color: AppColors.ink, offset: Offset(4, 4))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Código', style: AppText.body(size: 11, weight: FontWeight.w700, color: AppColors.inkA(0.5))),
                    const SizedBox(width: 10),
                    Text(
                      code,
                      style: AppText.body(size: 14, weight: FontWeight.w800, letterSpacing: 0.7)
                          .copyWith(fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              AppButton.primary(label: 'Acompanhar pedido', onPressed: () => context.go('/pedidos')),
              const SizedBox(height: 10),
              AppButton.dark(label: 'Voltar ao início', onPressed: () => context.go('/home')),
            ],
          ),
        ),
      ),
    );
  }
}
