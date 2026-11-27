import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/models.dart';
import '../../core/data/public_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../cart/cart_controller.dart';
import '../../l10n/i18n.dart';
import '../shell/client_mode.dart';

/// Linha do carrinho remontada a partir de um pedido.
typedef ResumeLine = ({MenuItem item, List<SelectedOption> options, int qty});

String _norm(String s) => s.trim().toLowerCase();

/// Remonta as linhas do carrinho de um pedido usando o cardápio ATUAL do bar:
/// casa cada item pelo nome e cada adicional pelo nome dentro dos grupos do
/// item. Se algum item/adicional não existir mais (cardápio mudou), devolve
/// null — aí não dá pra retomar com segurança (o preço/itens seriam outros).
List<ResumeLine>? rebuildCartLines(ClientOrder order, List<MenuItem> menu) {
  final lines = <ResumeLine>[];
  for (final it in order.items) {
    MenuItem? item;
    for (final m in menu) {
      if (_norm(m.name) == _norm(it.name)) {
        item = m;
        break;
      }
    }
    if (item == null) return null;
    final opts = <SelectedOption>[];
    for (final label in it.options) {
      SelectedOption? found;
      for (final g in item.groups) {
        for (final o in g.options) {
          if (_norm(o.name) == _norm(label)) {
            found = SelectedOption(
              groupId: g.id,
              groupName: g.name,
              optionId: o.id,
              name: o.name,
              priceDelta: o.priceDelta,
            );
            break;
          }
        }
        if (found != null) break;
      }
      if (found == null) return null;
      opts.add(found);
    }
    lines.add((item: item, options: opts, qty: it.qty));
  }
  return lines.isEmpty ? null : lines;
}

/// Pedido aguardando pagamento: dá pra retomar daqui? (Pix válido, divisão ou
/// remontar o carrinho pelo bar.)
bool canResumePayment(ClientOrder o) =>
    o.status == 'aguardando' && o.dbId != null && ((o.splits?.isNotEmpty ?? false) || _pixOpen(o) || o.estSlug != null);

bool _pixOpen(ClientOrder o) => o.payMethod == 'pix' && o.pixPayload != null && !o.expired;

/// Leva o cliente de volta ao pagamento de um pedido "Aguardando pagamento":
///  - conta dividida → tela da divisão;
///  - Pix ainda válido → mesmo QR;
///  - cartão/carteira (ou Pix vencido) → remonta o carrinho e abre a escolha de
///    pagamento; ao pagar, o pedido antigo é descartado e um novo criado no
///    lugar (mesmo fluxo do "editar pedido pendente").
Future<void> resumeOrderPayment(BuildContext context, WidgetRef ref, ClientOrder o) async {
  void toast(String msg) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      content: Text(msg, style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.dune)),
    ));
  // Modo visualização (estab vendo como o cliente): não retoma pagamento.
  if (ref.read(previewModeProvider)) {
    toast(previewPaymentBlockedMsg);
    return;
  }
  if (o.splits?.isNotEmpty ?? false) {
    context.push('/split', extra: o);
    return;
  }
  if (_pixOpen(o)) {
    context.push('/pix', extra: o);
    return;
  }
  final slug = o.estSlug;
  if (slug == null) {
    toast(tr('pedidos.resumeUnavailable'));
    return;
  }
  List<MenuItem> menu;
  try {
    menu = await ref.read(menuProvider(slug).future);
  } catch (_) {
    if (context.mounted) toast(tr('pedidos.resumeOffline'));
    return;
  }
  if (!context.mounted) return;
  final lines = rebuildCartLines(o, menu);
  if (lines == null) {
    toast(tr('pedidos.resumeMenuChanged'));
    return;
  }
  final cart = ref.read(cartProvider.notifier)..clear();
  ref.read(selectedSlugProvider.notifier).set(slug);
  ref.read(cartEstablishmentProvider.notifier).set(slug);
  for (final l in lines) {
    cart.addLine(l.item, l.options, qty: l.qty);
  }
  // O carrinho agora representa este pedido pendente: ao pagar, o checkout
  // descarta o antigo e cria o novo (nunca dois pedidos abertos).
  ref.read(pendingOrderProvider.notifier).set(o.dbId);
  context.go('/checkout');
}
