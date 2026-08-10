import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/data/models.dart';
import '../../../core/data/seed_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/brutal_card.dart';
import 'admin_sub_header.dart';

/// Admin · Cadastros: estabelecimentos da plataforma.
class AdminCadastrosScreen extends StatelessWidget {
  const AdminCadastrosScreen({super.key});

  void _toast(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        content: Text('Cadastro de estabelecimento — em breve nesta prévia',
            style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.dune)),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          AdminSubHeader(
            title: 'Cadastros',
            trailing: GestureDetector(
              onTap: () => _toast(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(color: AppColors.coral, borderRadius: BorderRadius.circular(999)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Symbols.add, size: 15, color: Colors.white),
                    const SizedBox(width: 4),
                    Text('Cadastrar', style: AppText.body(size: 12, weight: FontWeight.w800, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              children: [
                Text('${kEstablishments.length} estabelecimentos cadastrados',
                    style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
                const SizedBox(height: 12),
                for (final e in kEstablishments) ...[_card(e), const SizedBox(height: 10)],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(Establishment e) {
    final slug = e.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    final plano = e.orders > 300 ? 'Pro' : 'Básico';
    final tipo = kEstabType[e.id] ?? 'Bar';
    final rev = e.orders * 85.0;
    final feeMes = rev * estabFee(e.id) / 100;

    return BrutalCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(e.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.display(size: 14, weight: FontWeight.w700, letterSpacing: 0)),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.oceanDark.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
                          child: Text(tipo.toUpperCase(),
                              style: AppText.body(size: 9, weight: FontWeight.w800, color: AppColors.oceanDark)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('${e.location} · Plano $plano',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ativoBadge(),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Symbols.person, size: 12, color: AppColors.inkA(0.4)),
              const SizedBox(width: 4),
              Expanded(
                child: Text('$slug · @$slug',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: AppText.body(size: 10, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                const Icon(Symbols.check_circle, size: 12, color: AppColors.successText),
                const SizedBox(width: 4),
                Text('Pagamentos ativos · Mercado Pago',
                    style: AppText.body(size: 10, weight: FontWeight.w700, color: AppColors.successText)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _cell('Faturamento', money(rev))),
              const SizedBox(width: 6),
              Expanded(child: _cell('Pedidos', groupThousands(e.orders))),
              const SizedBox(width: 6),
              Expanded(child: _cell('Fee (mês)', money(feeMes), color: AppColors.successText)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ativoBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(999)),
    child: Text('Ativo', style: AppText.body(size: 10, weight: FontWeight.w700, color: AppColors.successText)),
  );

  Widget _cell(String label, String value, {Color? color}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
    decoration: BoxDecoration(color: AppColors.duneA(0.4), borderRadius: BorderRadius.circular(9)),
    child: Column(
      children: [
        Text(label.toUpperCase(),
            textAlign: TextAlign.center, style: AppText.body(size: 9, weight: FontWeight.w700, color: AppColors.inkA(0.5))),
        const SizedBox(height: 1),
        Text(value, style: AppText.display(size: 12, letterSpacing: 0, color: color ?? AppColors.ink)),
      ],
    ),
  );
}
