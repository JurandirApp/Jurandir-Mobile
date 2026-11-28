import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/data/public_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../auth/auth_controller.dart';
import '../../l10n/i18n.dart';

// "Modo visualização" do estabelecimento: o dono navega pela experiência do
// cliente SEM deslogar (a sessão do estab continua no `authProvider`) e vê o
// cardápio e as mesas exatamente como o cliente — mas NÃO consegue pagar nem
// criar pedido. O estado é o [previewModeProvider]: ligado pelo botão "Ver como
// o cliente vê" e desligado ao voltar ao painel (ou ao deslogar).

/// Sessão de estabelecimento ativa (o dono está vendo como cliente).
bool isEstabSession(AuthState auth) => auth.isAuthed && auth.role == 'estab';

/// Atalho de volta ao "painel" da sessão logada enquanto ela navega nas telas
/// do cliente: estab → pedidos; garçom → fila. Null = cliente comum (sem atalho).
({String route, String label})? panelReturnFor(AuthState auth) {
  if (!auth.isAuthed) return null;
  return switch (auth.role) {
    'estab' => (route: '/estab/pedidos', label: tr('shell.backToEstabPanel')),
    'waiter' => (route: '/waiter', label: tr('shell.backToWaiterQueue')),
    _ => null,
  };
}

/// Flag crua do modo visualização (ligada/desligada pelos atalhos abaixo).
class PreviewModeFlag extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool on) => state = on;
}

final previewModeFlagProvider = NotifierProvider<PreviewModeFlag, bool>(PreviewModeFlag.new);

/// Regra pura do modo visualização: só vale com a flag ligada E uma sessão de
/// equipe (estab/garçom) ativa — se a sessão cair, o preview some sozinho.
bool isPreviewActive({required bool flag, required AuthState auth}) =>
    flag && auth.isAuthed && (auth.role == 'estab' || auth.role == 'waiter');

/// Modo visualização efetivo: a equipe está vendo as telas do cliente pelo
/// "Ver como o cliente vê". Enquanto true: nada de pagamento nem pedido, e o
/// perfil local do cliente (nome/telefone) não é exigido.
final previewModeProvider = Provider<bool>((ref) =>
    isPreviewActive(flag: ref.watch(previewModeFlagProvider), auth: ref.watch(authProvider)));

/// Texto padrão dos bloqueios de pagamento no modo visualização.
String get previewPaymentBlockedMsg => tr('shell.previewPayBlocked');

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

/// Entra no modo visualização com o bar já selecionado (abre o cardápio dele).
void enterClientMode(WidgetRef ref, BuildContext context, String slug) {
  ref.read(previewModeFlagProvider.notifier).set(true);
  ref.read(selectedSlugProvider.notifier).set(slug);
  context.go('/menu');
}

/// Sai do modo visualização e volta ao painel da sessão logada.
void exitPreviewToPanel(WidgetRef ref, BuildContext context, String route) {
  ref.read(previewModeFlagProvider.notifier).set(false);
  context.go(route);
}

/// Faixa de volta ao painel (só aparece com sessão de estab ou de garçom
/// navegando nas telas do cliente). No modo visualização, explica que é a
/// visão do cliente e que os pagamentos estão desativados.
class BackToPanelBar extends ConsumerWidget {
  const BackToPanelBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ret = panelReturnFor(ref.watch(authProvider));
    if (ret == null) return const SizedBox.shrink();
    if (!ref.watch(previewModeProvider)) {
      return Material(
        color: AppColors.amber,
        child: InkWell(
          onTap: () => exitPreviewToPanel(ref, context, ret.route),
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
    return Material(
      color: AppColors.amber,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 9, 10, 9),
        child: Row(
          children: [
            const Icon(Symbols.visibility, size: 18, color: AppColors.ink),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.tr('shell.previewBanner'),
                style: AppText.body(size: 11.5, weight: FontWeight.w700, height: 1.3, color: AppColors.ink),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => exitPreviewToPanel(ref, context, ret.route),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Text(context.tr('shell.backToPanel'),
                      style: AppText.body(size: 11.5, weight: FontWeight.w800, color: AppColors.dune)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
