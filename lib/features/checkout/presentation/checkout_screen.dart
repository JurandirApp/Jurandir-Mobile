import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/data/models.dart';
import '../../../core/data/orders_controller.dart';
import '../../../core/data/public_api.dart';
import '../../../core/data/seed_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money.dart';
import '../../auth/auth_controller.dart';
import '../../cart/cart_controller.dart';
import '../../done/presentation/done_screen.dart';
import 'wallet_buttons.dart';

class _PayMethod {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  const _PayMethod(this.id, this.label, this.icon, this.color);
}

const _methods = [
  _PayMethod('pix', 'Pix', Symbols.qr_code_2, AppColors.pix),
  _PayMethod('credito', 'Crédito', Symbols.credit_card, AppColors.credit),
  _PayMethod('debito', 'Débito', Symbols.account_balance_wallet, AppColors.debit),
  _PayMethod('usdc', 'USDC', Symbols.toll, AppColors.usdc),
];

/// Checkout: resumo + observação + "Pagar tudo / Dividir conta" + métodos +
/// barra de pagar.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _payMode = 'full';
  int _people = 2;
  List<String?> _paid = [null, null];
  String? _selPay;
  bool _submitting = false;
  final _obsCtrl = TextEditingController();

  @override
  void dispose() {
    _obsCtrl.dispose();
    super.dispose();
  }

  void _setPeople(int n) {
    if (n < 2 || n > 8) return;
    setState(() {
      _people = n;
      _paid = List<String?>.filled(n, null);
    });
  }

  String _genCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random();
    return 'PED-${List.generate(8, (_) => chars[r.nextInt(chars.length)]).join()}';
  }

  void _pay(double grand) {
    final isSplit = _payMode == 'split';
    final nPaid = _paid.where((x) => x != null).length;
    final canPay = isSplit ? nPaid > 0 : _selPay != null;
    if (!canPay) return;
    final allPaid = !isSplit || nPaid == _people;
    _finish(incomplete: !allPaid);
  }

  /// Cria o pedido real (best-effort) e vai pra confirmação. Sem backend /
  /// estabelecimento real, mantém o comportamento de demonstração (stub).
  Future<void> _finish({required bool incomplete}) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final order = await _submitOrder();
    if (!mounted) return;
    ref.read(cartProvider.notifier).clear();
    context.go('/done', extra: DoneArgs(incomplete: incomplete, code: order?.code ?? _genCode()));
  }

  Future<ClientOrder?> _submitOrder() async {
    final ests = ref.read(establishmentsProvider).asData?.value ?? const <Establishment>[];
    Establishment? est;
    for (final e in ests) {
      if (e.slug != null) {
        // primeiro estabelecimento REAL (com slug vindo do Neon)
        est = e;
        break;
      }
    }
    if (est == null) return null;
    final lines = ref.read(cartProvider.notifier).lines;
    if (lines.isEmpty) return null;
    final name = ref.read(authProvider).name;
    final note = _obsCtrl.text.trim();
    final payload = <String, dynamic>{
      'establishmentId': est.id,
      'locationLabel': 'Pedido pelo app',
      if (name != null && name.isNotEmpty) 'customerName': name,
      if (note.isNotEmpty) 'note': note,
      'items': [
        for (final l in lines)
          <String, dynamic>{
            if (l.$1.dbId != null) 'menuItemId': l.$1.dbId,
            'name': l.$1.name,
            'qty': l.$2,
            'unitPrice': l.$1.price,
          },
      ],
      // Pagamento adiado: CREDIT não dispara cobrança dentro do createOrder,
      // então o pedido nasce "aguardando pagamento". Trocar pelo método real
      // quando o pagamento for ligado.
      'payment': {'kind': 'full', 'method': 'CREDIT', 'installments': 1},
    };
    try {
      final order = await ref.read(publicApiProvider).createOrder(payload);
      final id = order.dbId;
      if (id != null) await ref.read(myOrderIdsProvider.notifier).add(id);
      return order;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(cartProvider);
    final ctrl = ref.read(cartProvider.notifier);
    final ests = ref.watch(establishmentsProvider).asData?.value ?? const <Establishment>[];
    final est = ests.firstWhere(
      (e) => e.slug != null,
      orElse: () => kEstablishments.firstWhere((e) => e.id == 'live'),
    );
    final total = ctrl.total;
    final fee = total * 0.08;
    final estFee = total * 0.10;
    final grand = total + fee + estFee;
    final isSplit = _payMode == 'split';
    final share = _people == 0 ? 0.0 : grand / _people;
    final nPaid = _paid.where((x) => x != null).length;
    final canPay = isSplit ? nPaid > 0 : _selPay != null;
    final topSafe = MediaQuery.paddingOf(context).top;

    final String payLabel;
    final Color payBg;
    if (isSplit) {
      payLabel = nPaid == 0
          ? 'Escolha ao menos 1 pagamento'
          : nPaid == _people
          ? 'Finalizar — ${money(grand)}'
          : 'Enviar pedido · $nPaid/$_people pagos';
      payBg = !canPay
          ? AppColors.inkA(0.25)
          : (nPaid < _people ? AppColors.warning : AppColors.coral);
    } else {
      payLabel = 'Pagar ${money(grand)}';
      payBg = canPay ? AppColors.coral : AppColors.inkA(0.25);
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, topSafe + 20, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => context.go('/menu'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Symbols.arrow_back, size: 16, color: AppColors.inkA(0.55)),
                      const SizedBox(width: 6),
                      Text('Voltar ao cardápio',
                          style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.inkA(0.55))),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text('Confirmar pedido'.toUpperCase(), style: AppText.display(size: 22, letterSpacing: -0.5)),
                const SizedBox(height: 14),
                _summary(ctrl.lines, est, total, fee, estFee, grand),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text('Observação do pedido'.toUpperCase(),
                        style: AppText.display(size: 13, color: AppColors.inkA(0.6))),
                    const SizedBox(width: 6),
                    Text('(opcional)',
                        style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.inkA(0.35))),
                  ],
                ),
                const SizedBox(height: 10),
                _obsField(),
                const SizedBox(height: 18),
                _modeToggle(),
                const SizedBox(height: 12),
                if (!isSplit) ...[
                  _walletSection(grand),
                  _payGrid(),
                ] else
                  _splitCard(grand, share, nPaid),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _payBar(context, payLabel, payBg, canPay, grand),
          ),
        ],
      ),
    );
  }

  BoxDecoration get _brutal => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.ink, width: 2),
    boxShadow: const [BoxShadow(color: AppColors.ink, offset: Offset(4, 4))],
  );

  Widget _summary(List<(MenuItem, int)> cartLines, dynamic est, double total, double fee, double estFee, double grand) {
    final lines = cartLines
        .map((l) => (label: '${l.$2}× ${l.$1.name}', value: money(l.$1.price * l.$2)))
        .toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _brutal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Symbols.location_on, size: 13, color: AppColors.coral),
              const SizedBox(width: 4),
              Flexible(
                child: Text('${est.location} · ${est.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(size: 11, weight: FontWeight.w700, color: AppColors.inkA(0.5))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: Text(l.label, style: AppText.body(size: 13))),
                  Text(l.value, style: AppText.body(size: 13, weight: FontWeight.w600)),
                ],
              ),
            ),
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.inkA(0.08))),
            ),
            child: Column(
              children: [
                _sumRow('Subtotal', money(total)),
                const SizedBox(height: 5),
                _sumRow('Taxa Jurandir (8%)', money(fee)),
                const SizedBox(height: 5),
                _sumRow('Taxa de serviço (10%)', money(estFee)),
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  padding: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.inkA(0.08))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total', style: AppText.body(size: 15, weight: FontWeight.w800)),
                      Text(money(grand), style: AppText.body(size: 15, weight: FontWeight.w800, color: AppColors.coralDeep)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sumRow(String label, String value) {
    final s = AppText.body(size: 12, color: AppColors.inkA(0.6));
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: s), Text(value, style: s)],
    );
  }

  Widget _obsField() {
    return Container(
      decoration: _brutal,
      child: TextField(
        controller: _obsCtrl,
        maxLines: 2,
        maxLength: 140,
        style: AppText.body(size: 13, weight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'Ex: caipirinha sem açúcar, alergia a camarão…',
          hintStyle: AppText.body(size: 13, weight: FontWeight.w500, color: AppColors.inkA(0.4)),
          border: InputBorder.none,
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _modeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.inkA(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(child: _modeBtn('Pagar tudo', 'full', null)),
          Expanded(child: _modeBtn('Dividir conta', 'split', Symbols.group)),
        ],
      ),
    );
  }

  Widget _modeBtn(String label, String mode, IconData? icon) {
    final active = _payMode == mode;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _payMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: active ? AppColors.dune : AppColors.inkA(0.55)),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: AppText.body(
                    size: 13,
                    weight: FontWeight.w800,
                    color: active ? AppColors.dune : AppColors.inkA(0.55))),
          ],
        ),
      ),
    );
  }

  void _onWallet(Map<String, dynamic> _) {
    // TODO(#3b): enviar o token da wallet pro backend que cobra via Pagar.me.
    // Por ora cria o pedido real (aguardando pagamento) e vai pra confirmação.
    _finish(incomplete: false);
  }

  Widget _walletSection(double amount) {
    if (kIsWeb) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pagar rápido'.toUpperCase(), style: AppText.display(size: 13, color: AppColors.inkA(0.6))),
        const SizedBox(height: 10),
        WalletButtons(amount: amount, onToken: _onWallet),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: Divider(color: AppColors.inkA(0.12))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('ou pague com',
                  style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.4))),
            ),
            Expanded(child: Divider(color: AppColors.inkA(0.12))),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _payGrid() {
    return Column(
      children: [
        Row(children: [
          Expanded(child: _payOption(_methods[0])),
          const SizedBox(width: 8),
          Expanded(child: _payOption(_methods[1])),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _payOption(_methods[2])),
          const SizedBox(width: 8),
          Expanded(child: _payOption(_methods[3])),
        ]),
      ],
    );
  }

  Widget _payOption(_PayMethod pm) {
    final selected = _selPay == pm.id;
    return GestureDetector(
      onTap: () => setState(() => _selPay = pm.id),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.duneA(0.45) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.ink : AppColors.inkA(0.12), width: 2),
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: pm.color, shape: BoxShape.circle),
              child: Icon(pm.icon, size: 18, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(pm.label, textAlign: TextAlign.center, style: AppText.body(size: 13, weight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _splitCard(double grand, double share, int nPaid) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _brutal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Quantos amigos?', style: AppText.body(size: 13, weight: FontWeight.w700)),
              Row(
                children: [
                  _stepBtn(Symbols.remove, AppColors.inkA(0.08), AppColors.ink, () => _setPeople(_people - 1)),
                  SizedBox(
                    width: 24,
                    child: Text('$_people', textAlign: TextAlign.center, style: AppText.body(size: 15, weight: FontWeight.w800)),
                  ),
                  _stepBtn(Symbols.add, AppColors.coral, Colors.white, () => _setPeople(_people + 1)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.inkA(0.5)),
              children: [
                const TextSpan(text: 'Dividido igualmente · '),
                TextSpan(text: money(share), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.coralDeep)),
                const TextSpan(text: ' por pessoa (com taxas)'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _people; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _friendRow(i, share),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$nPaid de $_people pagaram',
                  style: AppText.body(size: 11, weight: FontWeight.w700, color: AppColors.inkA(0.5))),
              Text('${money(nPaid * share)} de ${money(grand)}',
                  style: AppText.body(size: 11, weight: FontWeight.w700, color: AppColors.inkA(0.5))),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _people == 0 ? 0 : nPaid / _people,
              minHeight: 8,
              backgroundColor: AppColors.inkA(0.08),
              valueColor: const AlwaysStoppedAnimation(AppColors.success),
            ),
          ),
          if (nPaid > 0 && nPaid < _people) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Text.rich(
                TextSpan(
                  style: AppText.body(size: 11, weight: FontWeight.w600, height: 1.45, color: const Color(0xFF92400E)),
                  children: const [
                    TextSpan(text: 'O pedido só vai para a cozinha quando estiver '),
                    TextSpan(text: '100% pago', style: TextStyle(fontWeight: FontWeight.w800)),
                    TextSpan(text: ' — quem faltar pode pagar depois em Pedidos.'),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _friendRow(int idx, double share) {
    final method = _paid[idx];
    final paid = method != null;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inkA(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.inkA(0.08), shape: BoxShape.circle),
                    child: Text('${idx + 1}', style: AppText.body(size: 11, weight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 8),
                  Text('Amigo ${idx + 1}', style: AppText.body(size: 13, weight: FontWeight.w700)),
                ],
              ),
              if (paid)
                Row(
                  children: [
                    const Icon(Symbols.check, size: 13, color: AppColors.successText),
                    const SizedBox(width: 4),
                    Text('Pago · ${_labelOf(method)}',
                        style: AppText.body(size: 11, weight: FontWeight.w800, color: AppColors.successText)),
                  ],
                )
              else
                Text(money(share), style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.inkA(0.45))),
            ],
          ),
          if (!paid) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                for (var m = 0; m < _methods.length; m++) ...[
                  if (m > 0) const SizedBox(width: 6),
                  Expanded(child: _friendPayBtn(idx, _methods[m])),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _friendPayBtn(int idx, _PayMethod pm) {
    return GestureDetector(
      onTap: () => setState(() => _paid[idx] = pm.id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.duneA(0.35),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.inkA(0.1)),
        ),
        child: Column(
          children: [
            Icon(pm.icon, size: 15, color: AppColors.inkA(0.7)),
            const SizedBox(height: 2),
            Text(pm.label, style: AppText.body(size: 9, weight: FontWeight.w700, color: AppColors.inkA(0.6))),
          ],
        ),
      ),
    );
  }

  String _labelOf(String id) => _methods.firstWhere((m) => m.id == id).label;

  Widget _stepBtn(IconData icon, Color bg, Color fg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, size: 15, color: fg),
      ),
    );
  }

  Widget _payBar(BuildContext context, String label, Color bg, bool canPay, double grand) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 24, 16, 20 + bottomSafe),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [AppColors.canvas, AppColors.canvas, AppColors.canvas.withValues(alpha: 0)],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: canPay ? () => _pay(grand) : null,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Center(
              child: Text(label, style: AppText.body(size: 15, weight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }
}
