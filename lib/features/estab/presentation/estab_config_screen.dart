import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/data/public_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../auth/auth_controller.dart';
import '../../../core/widgets/app_toggle.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../../core/widgets/labeled_input.dart';
import 'estab_sub_header.dart';
import '../../../l10n/i18n.dart';

const _gateways = [
  ('mp', 'Mercado Pago', 'estabCfg.gwMp'),
  ('pagarme', 'Pagar.me', 'estabCfg.gwPagarme'),
  ('asaas', 'Asaas', 'estabCfg.gwAsaas'),
  ('infinitepay', 'InfinitePay', 'estabCfg.gwInfinite'),
];

const _gwMethods = [
  ('pix', 'estabCfg.mPix', Symbols.qr_code_2),
  ('credito', 'estabCfg.mCredit', Symbols.credit_card),
  ('debito', 'estabCfg.mDebit', Symbols.account_balance_wallet),
];

/// Estab · Config: impressora + gateways por método + alterar senha.
class EstabConfigScreen extends ConsumerStatefulWidget {
  const EstabConfigScreen({super.key});

  @override
  ConsumerState<EstabConfigScreen> createState() => _EstabConfigScreenState();
}

class _EstabConfigScreenState extends ConsumerState<EstabConfigScreen> {
  bool _auto = true;
  bool _changingPw = false;
  final _ip = TextEditingController(text: '192.168.0.50');
  final _model = TextEditingController(text: 'Epson TM-T20');
  final _pwCur = TextEditingController();
  final _pwNova = TextEditingController();
  final Map<String, String> _gw = {'pix': 'mp', 'credito': 'mp', 'debito': 'mp'};

  @override
  void dispose() {
    for (final c in [_ip, _model, _pwCur, _pwNova]) {
      c.dispose();
    }
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        content: Text(msg, style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.dune)),
      ));
  }

  Future<void> _changePassword() async {
    if (_changingPw) return;
    final cur = _pwCur.text;
    final nova = _pwNova.text;
    if (cur.isEmpty || nova.length < 6) {
      _toast(tr('estabCfg.pwFill'));
      return;
    }
    final token = ref.read(authProvider).token;
    if (token == null) {
      _toast(tr('estabCfg.sessionExpired'));
      return;
    }
    setState(() => _changingPw = true);
    final r = await ref.read(publicApiProvider).changePassword(token, cur, nova);
    if (!mounted) return;
    setState(() => _changingPw = false);
    if (r.ok) {
      _pwCur.clear();
      _pwNova.clear();
      _toast(tr('estabCfg.pwChanged'));
    } else {
      _toast(r.error == 'currentWrong'
          ? tr('estabCfg.pwWrong')
          : r.error == 'invalid'
              ? tr('estabCfg.pwShort')
              : tr('estabCfg.pwError'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          EstabSubHeader(title: context.tr('estabCfg.settings')),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              children: [
                _printerCard(),
                const SizedBox(height: 14),
                _gatewaysCard(),
                const SizedBox(height: 14),
                _advancedPaymentsCard(),
                const SizedBox(height: 14),
                _passwordCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _h2(String text) => Text(text.toUpperCase(), style: AppText.display(size: 13));

  /// Abre o painel web (onde o dono cadastra recebedor Pagar.me e conecta o MP —
  /// setup único, mais confortável no navegador).
  Future<void> _openPanel() async {
    final ok = await launchUrl(Uri.parse('https://jurandir.app.br/pt/painel'),
        mode: LaunchMode.externalApplication);
    if (!ok && mounted) _toast(tr('estabCfg.panelOpenError'));
  }

  /// Config avançada de recebimentos (recebedor Pagar.me + conexão MP) fica no
  /// painel web — aqui só um atalho, pra não sumir e não confundir.
  Widget _advancedPaymentsCard() {
    return BrutalCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Symbols.account_balance, size: 18, color: AppColors.inkA(0.65)),
            const SizedBox(width: 8),
            _h2(context.tr('estabCfg.payouts')),
          ]),
          const SizedBox(height: 8),
          Text(
            context.tr('estabCfg.payoutsHint'),
            style: AppText.body(size: 12.5, weight: FontWeight.w600, color: AppColors.inkA(0.6)),
          ),
          const SizedBox(height: 12),
          AppButton.ghost(label: context.tr('estabCfg.openWebPanel'), onPressed: _openPanel),
        ],
      ),
    );
  }

  Widget _printerCard() {
    return BrutalCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _h2(context.tr('estabCfg.printer')),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('estabCfg.autoPrint'), style: AppText.body(size: 13, weight: FontWeight.w700)),
                    Text(context.tr('estabCfg.autoPrintHint'),
                        style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
                  ],
                ),
              ),
              AppToggle(value: _auto, onChanged: (v) => setState(() => _auto = v)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: LabeledInput(label: 'IP', controller: _ip)),
              const SizedBox(width: 10),
              Expanded(child: LabeledInput(label: context.tr('estabCfg.model'), controller: _model)),
            ],
          ),
          const SizedBox(height: 12),
          AppButton.ghost(label: context.tr('estabCfg.printTest'), onPressed: () => _toast(tr('estabCfg.testSent'))),
        ],
      ),
    );
  }

  Widget _gatewaysCard() {
    return BrutalCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _h2(context.tr('estabCfg.gateways')),
          const SizedBox(height: 6),
          Text(context.tr('estabCfg.gatewaysHint'),
              style: AppText.body(size: 11, weight: FontWeight.w600, height: 1.5, color: AppColors.inkA(0.5))),
          const SizedBox(height: 12),
          for (var i = 0; i < _gwMethods.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _methodBlock(_gwMethods[i]),
          ],
        ],
      ),
    );
  }

  Widget _methodBlock((String, String, IconData) m) {
    final (id, labelKey, icon) = m;
    final label = tr(labelKey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: AppColors.coralDeep),
            const SizedBox(width: 5),
            Text(label.toUpperCase(),
                style: AppText.body(size: 11, weight: FontWeight.w800, letterSpacing: 0.5, color: AppColors.inkA(0.6))),
          ],
        ),
        const SizedBox(height: 6),
        Row(children: [Expanded(child: _gwOpt(id, _gateways[0])), const SizedBox(width: 6), Expanded(child: _gwOpt(id, _gateways[1]))]),
        const SizedBox(height: 6),
        Row(children: [Expanded(child: _gwOpt(id, _gateways[2])), const SizedBox(width: 6), Expanded(child: _gwOpt(id, _gateways[3]))]),
      ],
    );
  }

  Widget _gwOpt(String method, (String, String, String) g) {
    final (gid, name, subKey) = g;
    final sub = tr(subKey);
    final sel = _gw[method] == gid;
    return GestureDetector(
      onTap: () => setState(() => _gw[method] = gid),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? AppColors.coral : AppColors.inkA(0.12), width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (sel) ...[
                  const Icon(Symbols.check_circle, size: 13, color: AppColors.coral),
                  const SizedBox(width: 3),
                ],
                Flexible(
                  child: Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(size: 12, weight: FontWeight.w800, color: sel ? AppColors.coral : AppColors.ink)),
                ),
              ],
            ),
            const SizedBox(height: 1),
            Text(sub, style: AppText.body(size: 10, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
          ],
        ),
      ),
    );
  }

  Widget _passwordCard() {
    return BrutalCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _h2(context.tr('estabCfg.changePw')),
          const SizedBox(height: 10),
          LabeledInput(hint: context.tr('estabCfg.currentPw'), controller: _pwCur, obscure: true),
          const SizedBox(height: 10),
          LabeledInput(hint: context.tr('estabCfg.newPw'), controller: _pwNova, obscure: true),
          const SizedBox(height: 10),
          AppButton.dark(
            label: _changingPw ? context.tr('estabCfg.changingPw') : context.tr('estabCfg.changePw'),
            onPressed: _changingPw ? null : _changePassword,
          ),
        ],
      ),
    );
  }
}
