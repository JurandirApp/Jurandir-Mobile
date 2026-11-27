import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/data/public_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../auth/auth_controller.dart';

// "Modo cliente" do estabelecimento: o dono navega pela experiência do cliente
// SEM deslogar. Não há estado novo — a sessão do estab continua no
// `authProvider` (role 'estab'); enquanto ela existir, as telas do cliente
// mostram o atalho "Voltar ao painel do estabelecimento".

/// Sessão de estabelecimento ativa (o dono está vendo como cliente).
bool isEstabSession(AuthState auth) => auth.isAuthed && auth.role == 'estab';

/// Atalho de volta ao "painel" da sessão logada enquanto ela navega nas telas
/// do cliente: estab → pedidos; garçom → fila. Null = cliente comum (sem atalho).
({String route, String label})? panelReturnFor(AuthState auth) {
  if (!auth.isAuthed) return null;
  return switch (auth.role) {
    'estab' => (route: '/estab/pedidos', label: 'Modo cliente · Voltar ao painel do estabelecimento'),
    'waiter' => (route: '/waiter', label: 'Voltar à fila do garçom'),
    _ => null,
  };
}

/// Slug do próprio bar: vem do GET /establishment/qr; sem ele, procura o id do
/// login na lista pública. Null se não achar.
Future<String?> resolveOwnSlug(WidgetRef ref) async {
  try {
    final qr = await ref.read(establishmentQrProvider.future);
    if (qr.slug.isNotEmpty) return qr.slug;
  } catch (_) {/* cai na lista pública */}
  final id = ref.read(authProvider).establishmentId;
  if (id == null) return null;
  try {
    final ests = await ref.read(establishmentsProvider.future);
    for (final e in ests) {
      if (e.id == id && e.slug != null) return e.slug;
    }
  } catch (_) {}
  return null;
}

/// Entra no modo cliente com o bar já selecionado (abre o cardápio dele).
void enterClientMode(WidgetRef ref, BuildContext context, String slug) {
  ref.read(selectedSlugProvider.notifier).set(slug);
  context.go('/menu');
}

/// Faixa "Modo cliente · Voltar ao painel" (só aparece com sessão de estab ou
/// de garçom navegando nas telas do cliente).
class BackToPanelBar extends ConsumerWidget {
  const BackToPanelBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ret = panelReturnFor(ref.watch(authProvider));
    if (ret == null) return const SizedBox.shrink();
    return Material(
      color: AppColors.amber,
      child: InkWell(
        onTap: () => context.go(ret.route),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            children: [
              const Icon(Symbols.storefront, size: 17, color: AppColors.ink),
              const SizedBox(width: 8),
              Expanded(
                child: Text(ret.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(size: 12, weight: FontWeight.w800, color: AppColors.ink)),
              ),
              const Icon(Symbols.arrow_forward, size: 16, color: AppColors.ink),
            ],
          ),
        ),
      ),
    );
  }
}
