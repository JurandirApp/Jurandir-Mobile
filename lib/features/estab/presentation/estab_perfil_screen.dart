import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../../core/widgets/labeled_input.dart';
import 'estab_sub_header.dart';

/// Estab · Perfil: dados que o cliente vê no cardápio.
class EstabPerfilScreen extends StatefulWidget {
  const EstabPerfilScreen({super.key});

  @override
  State<EstabPerfilScreen> createState() => _EstabPerfilScreenState();
}

class _EstabPerfilScreenState extends State<EstabPerfilScreen> {
  final _nome = TextEditingController(text: 'Quiosque do Mar');
  final _frase = TextEditingController(text: 'Drinks autorais, frutos do mar e pé na areia');
  final _endereco = TextEditingController(text: 'Av. Beira-Mar, 1200 — Praia Brava, Itajaí/SC');
  final _horario = TextEditingController(text: 'Todos os dias · 09h às 20h');
  final _whatsapp = TextEditingController(text: '5547999990000');
  final _instagram = TextEditingController(text: '@quiosquedomar');

  @override
  void dispose() {
    for (final c in [_nome, _frase, _endereco, _horario, _whatsapp, _instagram]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        content: Text('Perfil salvo!', style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.dune)),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          const EstabSubHeader(title: 'Perfil'),
          Expanded(
            child: SingleChildScrollView(
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
                        AppButton.primary(label: 'Salvar perfil', onPressed: _save),
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
            ),
          ),
        ],
      ),
    );
  }
}
