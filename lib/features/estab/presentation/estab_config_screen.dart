import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_toggle.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../../core/widgets/labeled_input.dart';
import 'estab_sub_header.dart';

const _gateways = [
  ('mp', 'Mercado Pago', 'Pix, crédito, débito'),
  ('pagarme', 'Pagar.me', 'Split + recebedores'),
  ('asaas', 'Asaas', 'Pix + split'),
  ('infinitepay', 'InfinitePay', 'Maquininha'),
];

const _gwMethods = [
  ('pix', 'Pix', Symbols.qr_code_2),
  ('credito', 'Crédito', Symbols.credit_card),
  ('debito', 'Débito', Symbols.account_balance_wallet),
];

/// Estab · Config: impressora + gateways por método + alterar senha.
class EstabConfigScreen extends StatefulWidget {
  const EstabConfigScreen({super.key});

  @override
  State<EstabConfigScreen> createState() => _EstabConfigScreenState();
}

class _EstabConfigScreenState extends State<EstabConfigScreen> {
  bool _auto = true;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          const EstabSubHeader(title: 'Configurações'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              children: [
                _printerCard(),
                const SizedBox(height: 14),
                _gatewaysCard(),
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

  Widget _printerCard() {
    return BrutalCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _h2('Impressora'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Impressão automática', style: AppText.body(size: 13, weight: FontWeight.w700)),
                    Text('Imprime ao confirmar o pagamento',
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
              Expanded(child: LabeledInput(label: 'Modelo', controller: _model)),
            ],
          ),
          const SizedBox(height: 12),
          AppButton.ghost(label: 'Imprimir teste', onPressed: () => _toast('Teste enviado à impressora')),
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
          _h2('Gateways de pagamento'),
          const SizedBox(height: 6),
          Text('Escolha por onde cada pagamento é processado. Cada método pode usar um gateway diferente.',
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
    final (id, label, icon) = m;
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
    final (gid, name, sub) = g;
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
          _h2('Alterar senha'),
          const SizedBox(height: 10),
          LabeledInput(hint: 'Senha atual', controller: _pwCur, obscure: true),
          const SizedBox(height: 10),
          LabeledInput(hint: 'Nova senha (mín. 6)', controller: _pwNova, obscure: true),
          const SizedBox(height: 10),
          AppButton.dark(label: 'Alterar senha', onPressed: () => _toast('Senha alterada')),
        ],
      ),
    );
  }
}
