import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/data/public_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../../core/widgets/dark_header.dart';
import '../../auth/auth_controller.dart';

/// Tela do garçom: confirmação de entrega por código.
///
/// Chegada via `context.push('/waiter/deliver', extra: {...})` a partir da
/// tela de "prontos" (`waiter_ready_screen.dart`), logo após pegar o pedido.
/// `extra` é um `Map<String, dynamic>` com `orderItemId`, `name`, `mesa`,
/// `cliente`, `qty`.
///
/// Pensada pra uso com uma mão só: campo de código grande, botão de
/// confirmação de largura cheia (alvo ≥ 56px), sem navegação extra — só
/// confirma ou volta pra lista.
class WaiterDeliverScreen extends ConsumerStatefulWidget {
  const WaiterDeliverScreen({super.key});

  @override
  ConsumerState<WaiterDeliverScreen> createState() => _WaiterDeliverScreenState();
}

class _WaiterDeliverScreenState extends ConsumerState<WaiterDeliverScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _codeError;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _toast(String msg, {Color bg = AppColors.ink, Color fg = AppColors.dune}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: bg,
        content: Text(msg, style: AppText.body(size: 13, weight: FontWeight.w600, color: fg)),
      ));
  }

  /// Confirma a entrega de `qty` unidades de `orderItemId` com o código
  /// digitado. Mantém `_busy` até resolver (sucesso navega embora; erro
  /// libera o botão de novo) — evita double-submit.
  Future<void> _confirm(String orderItemId, int qty) async {
    final code = _code.text.trim();
    if (code.length != 4) {
      setState(() => _codeError = 'Digite os 4 dígitos do código');
      return;
    }
    final token = ref.read(authProvider).token;
    if (_busy || token == null) return;
    setState(() {
      _busy = true;
      _codeError = null;
    });

    ({bool ok, String? error, bool orderDone})? result;
    try {
      result = await ref.read(publicApiProvider).waiterDeliver(token, orderItemId, qty, code);
    } catch (_) {
      result = null;
    }
    if (!mounted) return;

    if (result == null) {
      setState(() => _busy = false);
      _toast('Não foi possível confirmar. Tente de novo.', bg: AppColors.danger, fg: Colors.white);
      return;
    }

    if (result.ok) {
      _toast(
        result.orderDone ? '✅ ENTREGUE — pedido totalmente entregue' : '✅ ENTREGUE',
        bg: AppColors.success,
        fg: Colors.white,
      );
      // Pequeno respiro pro garçom ver a confirmação antes de voltar.
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      context.go('/waiter');
      return;
    }

    setState(() => _busy = false);
    if (result.error == 'code') {
      setState(() => _codeError = 'Código inválido, confira com o cliente');
    } else {
      _toast('Não foi possível confirmar. Tente de novo.', bg: AppColors.danger, fg: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    final mesa = extra?['mesa'] as String? ?? '';
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          DarkHeader(eyebrow: 'Garçom', title: extra == null ? 'Confirmar entrega' : 'Entrega — $mesa'),
          Expanded(child: extra == null ? _missingState() : _body(extra)),
        ],
      ),
    );
  }

  Widget _missingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: AppColors.inkA(0.4)),
            const SizedBox(height: 12),
            Text('Pedido não encontrado.',
                textAlign: TextAlign.center,
                style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
            const SizedBox(height: 14),
            SizedBox(
              height: 56,
              child: AppButton.dark(label: 'VOLTAR PARA A LISTA', onPressed: () => context.go('/waiter')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(Map<String, dynamic> extra) {
    final orderItemId = extra['orderItemId'] as String? ?? '';
    final name = extra['name'] as String? ?? '';
    final cliente = extra['cliente'] as String? ?? '';
    final qty = (extra['qty'] as num?)?.toInt() ?? 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BrutalCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(Symbols.person, 'Cliente: $cliente'),
                const SizedBox(height: 8),
                _infoRow(Symbols.restaurant, 'Pedido: $qty× $name'),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text('CÓDIGO DO CLIENTE', style: AppText.sectionTitle),
          const SizedBox(height: 10),
          TextField(
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: AppText.display(size: 40, letterSpacing: 14),
            onChanged: (_) {
              if (_codeError != null) setState(() => _codeError = null);
            },
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              hintText: '••••',
              hintStyle: AppText.display(size: 40, letterSpacing: 14, color: AppColors.inkA(0.2)),
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: _codeError != null ? AppColors.danger : AppColors.inkA(0.15),
                  width: 2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: _codeError != null ? AppColors.danger : AppColors.ink, width: 2),
              ),
            ),
          ),
          if (_codeError != null) ...[
            const SizedBox(height: 8),
            Text(_codeError!, style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.danger)),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: Material(
              color: _busy ? AppColors.coral.withValues(alpha: 0.6) : AppColors.coral,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _busy ? null : () => _confirm(orderItemId, qty),
                child: Center(
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Symbols.check_circle, size: 20, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              'CONFIRMAR ENTREGA',
                              style: AppText.body(
                                  size: 16, weight: FontWeight.w800, color: Colors.white, letterSpacing: 0.3),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.inkA(0.5)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: AppText.body(size: 16, weight: FontWeight.w700)),
        ),
      ],
    );
  }
}
