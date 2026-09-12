import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/public_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../../core/widgets/labeled_input.dart';
import '../../auth/auth_controller.dart';
import 'estab_sub_header.dart';

/// Estab · Perfil: dados que o cliente vê no cardápio (carrega e salva real).
/// O horário usa o editor ESTRUTURADO por dia (`weeklyHours`) — mesma fonte da
/// verdade do painel web (decide aberto/fechado e o ranking). O backend deriva
/// o texto de exibição a partir dele.
class EstabPerfilScreen extends ConsumerStatefulWidget {
  const EstabPerfilScreen({super.key});

  @override
  ConsumerState<EstabPerfilScreen> createState() => _EstabPerfilScreenState();
}

class _EstabPerfilScreenState extends ConsumerState<EstabPerfilScreen> {
  final _nome = TextEditingController();
  final _frase = TextEditingController();
  final _endereco = TextEditingController();
  final _whatsapp = TextEditingController();
  final _instagram = TextEditingController();
  // 7 dias (índice 0 = domingo, igual ao backend); cada dia com 0..2 janelas {o,c}.
  List<List<Map<String, String>>> _weekly = List.generate(7, (_) => []);
  bool _loaded = false;
  bool _saving = false;

  // Ordem de exibição começando na segunda; rótulos indexados por dia (0 = Dom).
  static const _order = [1, 2, 3, 4, 5, 6, 0];
  static const _labels = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];

  @override
  void dispose() {
    for (final c in [_nome, _frase, _endereco, _whatsapp, _instagram]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(Map<String, dynamic> m) {
    _nome.text = (m['name'] as String?) ?? '';
    _frase.text = (m['tagline'] as String?) ?? '';
    _endereco.text = (m['address'] as String?) ?? '';
    _whatsapp.text = (m['whatsapp'] as String?) ?? '';
    _instagram.text = (m['instagram'] as String?) ?? '';
    _weekly = _parseWeekly(m['weeklyHours']);
  }

  List<List<Map<String, String>>> _parseWeekly(dynamic raw) {
    final week = List.generate(7, (_) => <Map<String, String>>[]);
    if (raw is List) {
      for (var i = 0; i < 7 && i < raw.length; i++) {
        final day = raw[i];
        if (day is List) {
          for (final w in day) {
            if (week[i].length >= 2) break;
            if (w is Map && w['o'] is String && w['c'] is String) {
              week[i].add({'o': w['o'] as String, 'c': w['c'] as String});
            }
          }
        }
      }
    }
    return week;
  }

  String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  TimeOfDay _parse(String hhmm) {
    final p = hhmm.split(':');
    return TimeOfDay(hour: int.tryParse(p.first) ?? 0, minute: int.tryParse(p.length > 1 ? p[1] : '0') ?? 0);
  }

  Future<void> _pickTime(int day, int win, String key) async {
    final current = _parse(_weekly[day][win][key] ?? '00:00');
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _weekly[day][win][key] = _fmt(picked));
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

  Future<void> _save() async {
    if (_saving) return;
    final token = ref.read(authProvider).token;
    if (token == null) return;
    if (_nome.text.trim().isEmpty) {
      _toast('Informe o nome do estabelecimento.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(publicApiProvider).saveEstablishmentProfile(token, {
        'name': _nome.text.trim(),
        'tagline': _frase.text.trim(),
        'address': _endereco.text.trim(),
        'weekly': _weekly, // fonte única do horário (backend deriva o texto)
        'whatsapp': _whatsapp.text.trim(),
        'instagram': _instagram.text.trim(),
      });
      if (!mounted) return;
      ref.invalidate(establishmentProfileProvider);
      ref.invalidate(establishmentsProvider); // o cliente vê o nome/dados atualizados
      _toast('Perfil salvo!');
    } catch (_) {
      if (mounted) _toast('Não foi possível salvar');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(establishmentProfileProvider);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          const EstabSubHeader(title: 'Perfil'),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.coral, strokeWidth: 3)),
              error: (_, _) => Center(
                child: GestureDetector(
                  onTap: () => ref.invalidate(establishmentProfileProvider),
                  child: Text('Erro ao carregar. Toque para tentar de novo.',
                      style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.inkA(0.5))),
                ),
              ),
              data: (m) {
                if (!_loaded) {
                  _loaded = true;
                  _fill(m);
                }
                return _form();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _form() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('O que o cliente vê ao abrir seu cardápio.',
              style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
          const SizedBox(height: 14),
          BrutalCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LabeledInput(label: 'Nome do estabelecimento', controller: _nome),
                const SizedBox(height: 12),
                LabeledInput(label: 'Frase de destaque', controller: _frase),
                const SizedBox(height: 12),
                LabeledInput(label: 'Endereço', controller: _endereco),
                const SizedBox(height: 16),
                _weeklyHours(),
                const SizedBox(height: 16),
                LabeledInput(label: 'WhatsApp', controller: _whatsapp, keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                LabeledInput(label: 'Instagram', controller: _instagram),
                const SizedBox(height: 14),
                AppButton.primary(label: _saving ? 'Salvando…' : 'Salvar perfil', onPressed: _save),
                const SizedBox(height: 8),
                Center(
                  child: Text('As mudanças aparecem na hora no cardápio do cliente.',
                      textAlign: TextAlign.center,
                      style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.4))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _weeklyHours() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('HORÁRIO DE FUNCIONAMENTO',
            style: AppText.body(size: 11, weight: FontWeight.w800, color: AppColors.inkA(0.55), letterSpacing: 0.4)),
        const SizedBox(height: 4),
        Text('Define quando o bar aparece como "Aberto" pro cliente.',
            style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.4))),
        const SizedBox(height: 8),
        for (final d in _order) _dayRow(d),
      ],
    );
  }

  Widget _dayRow(int day) {
    final windows = _weekly[day];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_labels[day], style: AppText.body(size: 14, weight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: windows.isEmpty
                ? Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('Fechado',
                            style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.inkA(0.4))),
                      ),
                      const Spacer(),
                      _smallBtn('Abrir', () => setState(() => windows.add({'o': '18:00', 'c': '23:00'}))),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var w = 0; w < windows.length; w++) _windowRow(day, w),
                      if (windows.length < 2)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: _smallBtn('+ 2º turno', () => setState(() => windows.add({'o': '18:00', 'c': '23:00'}))),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _windowRow(int day, int win) {
    final w = _weekly[day][win];
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          _timeChip(w['o'] ?? '00:00', () => _pickTime(day, win, 'o')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('–', style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.inkA(0.5))),
          ),
          _timeChip(w['c'] ?? '00:00', () => _pickTime(day, win, 'c')),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _weekly[day].removeAt(win)),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.close, size: 18, color: AppColors.inkA(0.45)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.ink, width: 1.5),
        ),
        child: Text(label, style: AppText.body(size: 15, weight: FontWeight.w800)),
      ),
    );
  }

  Widget _smallBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: AppColors.duneA(0.6), borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: AppText.body(size: 12, weight: FontWeight.w800, color: AppColors.ink)),
      ),
    );
  }
}
