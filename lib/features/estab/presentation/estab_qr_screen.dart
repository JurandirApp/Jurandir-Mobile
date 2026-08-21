import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/data/models.dart';
import '../../../core/data/public_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/dark_header.dart';
import '../../auth/auth_controller.dart';

/// Estab · QR Codes reais: cada ponto (mesa/guarda-sol) abre o cardápio já
/// identificado. Criar/excluir persistem no backend.
class EstabQrScreen extends ConsumerStatefulWidget {
  const EstabQrScreen({super.key});

  @override
  ConsumerState<EstabQrScreen> createState() => _EstabQrScreenState();
}

class _EstabQrScreenState extends ConsumerState<EstabQrScreen> {
  final _ctrl = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _ctrl.dispose();
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

  String _qrUrl(String slug, String label) {
    final data = Uri.encodeComponent('https://jurandir.app.br/?est=$slug&local=$label');
    return 'https://api.qrserver.com/v1/create-qr-code/?size=200x200&margin=10&data=$data';
  }

  Future<void> _add() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty || _adding) return;
    final token = ref.read(authProvider).token;
    if (token == null) return;
    setState(() => _adding = true);
    try {
      await ref.read(publicApiProvider).addQrSpot(token, t);
      _ctrl.clear();
      ref.invalidate(establishmentQrProvider);
    } catch (_) {
      _toast('Não foi possível criar');
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _delete(String id) async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    try {
      await ref.read(publicApiProvider).deleteQrSpot(token, id);
      ref.invalidate(establishmentQrProvider);
    } catch (_) {
      _toast('Não foi possível excluir');
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(establishmentQrProvider);
    final estName = ref.watch(authProvider).name ?? 'Estabelecimento';

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          DarkHeader(eyebrow: estName, title: 'QR Codes'),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.coral, strokeWidth: 3)),
              error: (_, _) => _errorState(),
              data: (data) => _body(data.slug, data.spots),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Symbols.cloud_off, size: 40, color: AppColors.inkA(0.4)),
              const SizedBox(height: 12),
              Text('Não foi possível carregar os QRs.',
                  style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => ref.invalidate(establishmentQrProvider),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(999)),
                  child: Text('Tentar de novo',
                      style: AppText.body(size: 13, weight: FontWeight.w800, color: AppColors.dune)),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _body(String slug, List<QrSpot> spots) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      children: [
        Text('Cada QR abre o cardápio já identificando o guarda-sol ou mesa.',
            style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                style: AppText.body(size: 13, weight: FontWeight.w600),
                onSubmitted: (_) => _add(),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Ex: Guarda-sol nº 30',
                  hintStyle: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.inkA(0.4)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: const BorderSide(color: AppColors.ink, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: const BorderSide(color: AppColors.ink, width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _add,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(color: AppColors.coral, borderRadius: BorderRadius.circular(999)),
                child: _adding
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Symbols.add, size: 16, color: Colors.white),
                          const SizedBox(width: 5),
                          Text('Gerar', style: AppText.body(size: 13, weight: FontWeight.w800, color: Colors.white)),
                        ],
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (spots.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text('Nenhum QR ainda. Gere o primeiro acima.',
                  style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.inkA(0.45))),
            ),
          )
        else
          for (var i = 0; i < spots.length; i += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _qrCard(slug, spots[i])),
                  const SizedBox(width: 12),
                  if (i + 1 < spots.length)
                    Expanded(child: _qrCard(slug, spots[i + 1]))
                  else
                    const Expanded(child: SizedBox()),
                ],
              ),
            ),
      ],
    );
  }

  Widget _qrCard(String slug, QrSpot spot) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.ink, width: 2),
        boxShadow: const [BoxShadow(color: AppColors.ink, offset: Offset(4, 4))],
      ),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.inkA(0.1)),
                image: DecorationImage(image: NetworkImage(_qrUrl(slug, spot.label)), fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Symbols.location_on, size: 13, color: AppColors.coral),
              const SizedBox(width: 4),
              Flexible(
                child: Text(spot.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(size: 12, weight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _toast('Impressão do QR — em breve'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.duneA(0.5), borderRadius: BorderRadius.circular(999)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Symbols.print, size: 13, color: AppColors.inkA(0.7)),
                        const SizedBox(width: 4),
                        Text('Imprimir', style: AppText.body(size: 11, weight: FontWeight.w800, color: AppColors.inkA(0.7))),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _delete(spot.id),
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(999)),
                  child: const Icon(Symbols.delete, size: 14, color: Color(0xFFEF4444)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
