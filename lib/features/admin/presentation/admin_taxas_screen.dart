import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/data/models.dart';
import '../../../core/data/public_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../auth/auth_controller.dart';
import 'admin_sub_header.dart';

/// Admin · Taxas: fee (%) editável por estabelecimento (salva no backend).
class AdminTaxasScreen extends ConsumerWidget {
  const AdminTaxasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminOverviewProvider);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          const AdminSubHeader(title: 'Taxas'),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.coral, strokeWidth: 3)),
              error: (_, _) => Center(
                child: GestureDetector(
                  onTap: () => ref.invalidate(adminOverviewProvider),
                  child: Text('Erro ao carregar. Toque para tentar de novo.',
                      style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.inkA(0.5))),
                ),
              ),
              data: (ov) {
                final ests = ov?.establishments ?? const <AdminEstablishment>[];
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  children: [
                    Text('Fee do Jurandir sobre cada venda, por estabelecimento. Edite e salve.',
                        style: AppText.body(size: 12, weight: FontWeight.w600, height: 1.4, color: AppColors.inkA(0.5))),
                    const SizedBox(height: 12),
                    for (final e in ests) ...[_FeeRow(est: e), const SizedBox(height: 10)],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FeeRow extends ConsumerStatefulWidget {
  final AdminEstablishment est;
  const _FeeRow({required this.est});

  @override
  ConsumerState<_FeeRow> createState() => _FeeRowState();
}

class _FeeRowState extends ConsumerState<_FeeRow> {
  late final TextEditingController _c;
  late int _current;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _current = widget.est.feePct;
    _c = TextEditingController(text: _current.toString());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  int get _typed => int.tryParse(_c.text.trim()) ?? _current;
  bool get _changed => _typed != _current && _c.text.trim().isNotEmpty;

  Future<void> _save() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    final pct = _typed.clamp(0, 100);
    setState(() => _saving = true);
    try {
      await ref.read(publicApiProvider).saveFee(token, widget.est.id, pct);
      if (!mounted) return;
      setState(() => _current = pct);
      ref.invalidate(adminOverviewProvider);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.ink,
          content: Text('Fee de ${widget.est.name} salvo: $pct%',
              style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.dune)),
        ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.ink,
            content: Text('Não foi possível salvar',
                style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.dune)),
          ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.est;
    return BrutalCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: AppText.display(size: 14, weight: FontWeight.w700, letterSpacing: 0)),
                const SizedBox(height: 1),
                Text.rich(TextSpan(children: [
                  const TextSpan(text: 'Fees acumulados: '),
                  TextSpan(text: money(e.fees), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.successText)),
                ]), style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 48,
            child: TextField(
              controller: _c,
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              style: AppText.body(size: 13, weight: FontWeight.w700),
              onChanged: (_) => setState(() {}),
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
          const SizedBox(width: 3),
          Text('%', style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.inkA(0.5))),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: (_changed && !_saving) ? _save : null,
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: (_changed && !_saving) ? AppColors.coral : AppColors.inkA(0.12),
                shape: BoxShape.circle,
              ),
              child: _saving
                  ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(Symbols.check, size: 17, color: (_changed) ? Colors.white : AppColors.inkA(0.4)),
            ),
          ),
        ],
      ),
    );
  }
}
