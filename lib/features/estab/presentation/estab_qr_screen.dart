import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/data/seed_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/dark_header.dart';

/// Estab · QR Codes: gera/gerencia os QRs das mesas/guarda-sóis.
class EstabQrScreen extends StatefulWidget {
  const EstabQrScreen({super.key});

  @override
  State<EstabQrScreen> createState() => _EstabQrScreenState();
}

class _EstabQrScreenState extends State<EstabQrScreen> {
  final List<String> _spots = [...kQrSpots];
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _add() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _spots.add(t);
      _ctrl.clear();
    });
  }

  String _qrUrl(String label) {
    final data = Uri.encodeComponent('https://jurandir.app/?est=quiosque-do-mar&local=$label');
    return 'https://api.qrserver.com/v1/create-qr-code/?size=200x200&margin=10&data=$data';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          const DarkHeader(eyebrow: 'Quiosque do Mar', title: 'QR Codes'),
          Expanded(
            child: ListView(
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
                        child: Row(
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
                for (var i = 0; i < _spots.length; i += 2)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _qrCard(_spots[i])),
                        const SizedBox(width: 12),
                        if (i + 1 < _spots.length)
                          Expanded(child: _qrCard(_spots[i + 1]))
                        else
                          const Expanded(child: SizedBox()),
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

  Widget _qrCard(String label) {
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
                image: DecorationImage(image: NetworkImage(_qrUrl(label)), fit: BoxFit.cover),
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
                child: Text(label,
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
                  onTap: () {},
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
                onTap: () => setState(() => _spots.remove(label)),
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
