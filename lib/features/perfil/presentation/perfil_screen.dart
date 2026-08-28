import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_toggle.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../../core/widgets/dark_header.dart';
import '../../auth/auth_controller.dart';

const _payMethods = [
  ('Pix', 'Aprovação na hora', Symbols.qr_code_2, AppColors.pix, true),
  ('Visa •••• 4412', 'Crédito · até 6x sem juros', Symbols.credit_card, AppColors.credit, false),
];

class PerfilScreen extends ConsumerStatefulWidget {
  const PerfilScreen({super.key});

  @override
  ConsumerState<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends ConsumerState<PerfilScreen> {
  late final TextEditingController _name;
  bool _notif = true;
  bool _offers = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: ref.read(authProvider).name ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String _initials(String? name) {
    final n = (name ?? '').trim();
    if (n.isEmpty) return '?';
    return n.split(RegExp(r'\s+')).take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.email != prev?.email) _name.text = next.name ?? '';
    });
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          const DarkHeader(title: 'Perfil'),
          Expanded(child: auth.isAuthed ? _authed(context, auth) : _notAuthed(context)),
        ],
      ),
    );
  }

  // ---- não autenticado ----
  Widget _notAuthed(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 44, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
            child: const Icon(Symbols.person, size: 40, color: AppColors.amber),
          ),
          const SizedBox(height: 18),
          Text('Acesso ao painel'.toUpperCase(),
              textAlign: TextAlign.center, style: AppText.display(size: 24, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              'Dono de bar ou administração? Entre pra gerenciar pedidos, cardápio e taxas. Pra pedir, é só escanear o QR da mesa — sem precisar de conta.',
              textAlign: TextAlign.center,
              style: AppText.body(size: 13, weight: FontWeight.w600, height: 1.5, color: AppColors.inkA(0.55)),
            ),
          ),
          const SizedBox(height: 22),
          AppButton.primary(label: 'Entrar', onPressed: () => context.go('/login')),
        ],
      ),
    );
  }

  // ---- autenticado (cliente) ----
  Widget _authed(BuildContext context, AuthState auth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(_initials(auth.name), size: 60),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _name,
                      onChanged: (v) => ref.read(authProvider.notifier).setName(v),
                      style: AppText.display(size: 20, letterSpacing: 0),
                      decoration: const InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('Praia Brava, Itajaí/SC',
                        style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _h2('Formas de pagamento'),
          for (final p in _payMethods) ...[_payCard(p), const SizedBox(height: 8)],
          const SizedBox(height: 16),
          _h2('Preferências'),
          BrutalCard(
            radius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                _prefRow('Notificações de pedido', _notif, (v) => setState(() => _notif = v), border: true),
                _prefRow('Ofertas dos favoritos', _offers, (v) => setState(() => _offers = v), border: false),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _h2('Conta'),
          BrutalCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                  child: const Icon(Symbols.check, size: 19, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Conectado', style: AppText.body(size: 13, weight: FontWeight.w700)),
                      Text(auth.email ?? '',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => ref.read(authProvider.notifier).logout(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(color: AppColors.duneA(0.5), borderRadius: BorderRadius.circular(999)),
                    child: Text('Sair', style: AppText.body(size: 12, weight: FontWeight.w800, color: AppColors.inkA(0.7))),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _h2(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text.toUpperCase(), style: AppText.sectionTitle),
  );

  Widget _payCard((String, String, IconData, Color, bool) p) {
    final (label, sub, icon, color, fav) = p;
    return BrutalCard(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.body(size: 14, weight: FontWeight.w700)),
                Text(sub, style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
              ],
            ),
          ),
          if (fav)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(999)),
              child: Text('Favorito'.toUpperCase(),
                  style: AppText.body(size: 9, weight: FontWeight.w800, color: AppColors.dune)),
            ),
        ],
      ),
    );
  }

  Widget _prefRow(String label, bool value, ValueChanged<bool> onChanged, {required bool border}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: border ? Border(bottom: BorderSide(color: AppColors.inkA(0.08))) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppText.body(size: 14, weight: FontWeight.w600)),
          AppToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
