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
class EstabPerfilScreen extends ConsumerStatefulWidget {
  const EstabPerfilScreen({super.key});

  @override
  ConsumerState<EstabPerfilScreen> createState() => _EstabPerfilScreenState();
}

class _EstabPerfilScreenState extends ConsumerState<EstabPerfilScreen> {
  final _nome = TextEditingController();
  final _frase = TextEditingController();
  final _endereco = TextEditingController();
  final _horario = TextEditingController();
  final _whatsapp = TextEditingController();
  final _instagram = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_nome, _frase, _endereco, _horario, _whatsapp, _instagram]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(Map<String, String> m) {
    _nome.text = m['name'] ?? '';
    _frase.text = m['tagline'] ?? '';
    _endereco.text = m['address'] ?? '';
    _horario.text = m['hours'] ?? '';
    _whatsapp.text = m['whatsapp'] ?? '';
    _instagram.text = m['instagram'] ?? '';
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
        'hours': _horario.text.trim(),
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
                const SizedBox(height: 12),
                LabeledInput(label: 'Horário de funcionamento', controller: _horario),
                const SizedBox(height: 12),
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
}
