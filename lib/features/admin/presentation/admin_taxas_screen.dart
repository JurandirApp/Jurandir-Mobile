import 'package:flutter/material.dart';

import '../../../core/data/seed_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/brutal_card.dart';
import 'admin_sub_header.dart';

/// Admin · Taxas: fee (%) editável por estabelecimento.
class AdminTaxasScreen extends StatefulWidget {
  const AdminTaxasScreen({super.key});

  @override
  State<AdminTaxasScreen> createState() => _AdminTaxasScreenState();
}

class _AdminTaxasScreenState extends State<AdminTaxasScreen> {
  final Map<String, double> _fees = {};
  final Map<String, TextEditingController> _ctrls = {};

  @override
  void initState() {
    super.initState();
    for (final e in kEstablishments) {
      final f = estabFee(e.id);
      _fees[e.id] = f;
      _ctrls[e.id] = TextEditingController(text: f.toStringAsFixed(0));
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          const AdminSubHeader(title: 'Taxas'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              children: [
                Text('Fee do Jurandir sobre cada venda, por estabelecimento. Aparece para o cliente no checkout.',
                    style: AppText.body(size: 12, weight: FontWeight.w600, height: 1.4, color: AppColors.inkA(0.5))),
                const SizedBox(height: 12),
                for (final e in kEstablishments) ...[_row(e.id, e.name, e.orders), const SizedBox(height: 10)],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String id, String name, int orders) {
    final fee = _fees[id] ?? 8;
    final feeMes = orders * 85 * fee / 100;
    return BrutalCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: AppText.display(size: 14, weight: FontWeight.w700, letterSpacing: 0)),
                const SizedBox(height: 1),
                Text.rich(TextSpan(children: [
                  const TextSpan(text: 'Fee estimado (mês): '),
                  TextSpan(text: money(feeMes), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.successText)),
                ]), style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 52,
            child: TextField(
              controller: _ctrls[id],
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: AppText.body(size: 13, weight: FontWeight.w700),
              onChanged: (v) {
                final parsed = double.tryParse(v.replaceAll(',', '.'));
                setState(() => _fees[id] = parsed ?? 0);
              },
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.inkA(0.15), width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.ink, width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text('%', style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.inkA(0.5))),
        ],
      ),
    );
  }
}
