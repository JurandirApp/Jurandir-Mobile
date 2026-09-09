import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/data/client_profile.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../../core/widgets/labeled_input.dart';

/// Onboarding do perfil local do cliente (nome + telefone).
///
/// Aparece uma única vez, antes do cliente acessar o app (ver gate em
/// `app_router.dart`). Não é login — não cria conta no servidor, só grava
/// nome/telefone em shared_preferences (via [clientProfileProvider]) pra
/// identificar o pedido e o clientId anônimo já gerado.
class ProfileOnboardingScreen extends ConsumerStatefulWidget {
  const ProfileOnboardingScreen({super.key});

  @override
  ConsumerState<ProfileOnboardingScreen> createState() => _ProfileOnboardingScreenState();
}

class _ProfileOnboardingScreenState extends ConsumerState<ProfileOnboardingScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Se já havia algo salvo (perfil incompleto, ex: só o nome), pré-preenche.
    final profile = ref.read(clientProfileProvider);
    _name.text = profile.name ?? '';
    _phone.text = profile.phone ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final digits = phone.replaceAll(RegExp(r'\D'), '');

    if (name.isEmpty) {
      setState(() => _error = 'Informe seu nome.');
      return;
    }
    if (digits.length < 8) {
      setState(() => _error = 'Informe um telefone válido (mín. 8 dígitos).');
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });
    await ref.read(clientProfileProvider.notifier).save(name, phone);
    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, pad.top + 40, 24, pad.bottom + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.coral, borderRadius: BorderRadius.circular(22)),
              child: const Icon(Symbols.waving_hand, size: 34, color: Colors.white),
            ),
            const SizedBox(height: 22),
            Text('Como podemos te chamar?'.toUpperCase(),
                textAlign: TextAlign.center, style: AppText.display(size: 24, letterSpacing: -0.5)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                'Nome e telefone só pra identificar seu pedido no balcão. Sem conta, sem senha.',
                textAlign: TextAlign.center,
                style: AppText.body(size: 13, weight: FontWeight.w600, height: 1.5, color: AppColors.inkA(0.55)),
              ),
            ),
            const SizedBox(height: 26),
            BrutalCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LabeledInput(label: 'Nome', hint: 'Seu nome', controller: _name),
                  const SizedBox(height: 12),
                  LabeledInput(
                    label: 'Telefone',
                    hint: '(00) 00000-0000',
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.danger)),
                  ],
                  const SizedBox(height: 16),
                  AppButton.primary(label: _saving ? 'Salvando…' : 'Continuar', onPressed: _submit),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
