import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/data/public_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  String _mode = 'entrar'; // entrar | criar
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  /// Login real contra o backend (estabelecimento/admin). Não há conta de
  /// cliente — o cliente pede anônimo pelo QR.
  Future<void> _submit() async {
    if (_loading) return;
    final email = _email.text.trim().toLowerCase();
    final pass = _pass.text;

    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Informe e-mail e senha.');
      return;
    }
    if (_mode == 'criar') {
      setState(() => _error =
          'O cadastro ainda não está disponível pelo app. Contas de estabelecimento são criadas pela equipe Jurandir.');
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final r = await ref.read(publicApiProvider).login(email, pass);
      if (!mounted) return;
      final appRole = r.role == 'ADMIN' ? 'admin' : 'estab';
      ref.read(authProvider.notifier).login(
            role: appRole,
            name: r.name,
            email: r.email,
            establishmentId: r.establishmentId,
            token: r.token,
          );
      context.go(appRole == 'admin' ? '/admin/dashboard' : '/estab/pedidos');
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.response?.statusCode == 401
          ? 'E-mail ou senha inválidos.'
          : 'Não foi possível conectar ao servidor.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Não foi possível conectar ao servidor.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCriar = _mode == 'criar';
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => context.go('/perfil'),
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.duneA(0.12), shape: BoxShape.circle),
                    child: const Icon(Symbols.arrow_back, size: 20, color: AppColors.dune),
                  ),
                ),
                const SizedBox(height: 20),
                SvgPicture.asset('assets/images/jurandir-logo-horizontal.svg', width: 160),
                const SizedBox(height: 18),
                Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'Uma conta,\n'),
                    TextSpan(text: 'tudo dentro.', style: const TextStyle(color: AppColors.coralDeep)),
                  ]),
                  style: AppText.display(size: 27, letterSpacing: -0.5, height: 0.95, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text('Entre com a conta do seu estabelecimento ou da administração.',
                    style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.duneA(0.6))),
                const SizedBox(height: 20),
                _segmented(),
                const SizedBox(height: 18),
                if (isCriar) ...[
                  _field(label: 'Seu nome', controller: _nome, hint: 'Como podemos te chamar?'),
                  const SizedBox(height: 12),
                ],
                _field(label: 'E-mail', controller: _email, hint: 'voce@email.com', keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                _field(label: 'Senha', controller: _pass, hint: '••••••••', obscure: true),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.rose)),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: Material(
                    color: _loading ? AppColors.coral.withValues(alpha: 0.6) : AppColors.coral,
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      onTap: _loading ? null : _submit,
                      borderRadius: BorderRadius.circular(999),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        child: Center(
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                                )
                              : Text(isCriar ? 'Criar conta' : 'Entrar',
                                  style: AppText.body(size: 15, weight: FontWeight.w700, color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _segmented() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.duneA(0.1), borderRadius: BorderRadius.circular(999)),
      child: Row(
        children: [
          Expanded(child: _segBtn('Entrar', 'entrar')),
          Expanded(child: _segBtn('Criar conta', 'criar')),
        ],
      ),
    );
  }

  Widget _segBtn(String label, String mode) {
    final active = _mode == mode;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        _mode = mode;
        _error = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.dune : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            style: AppText.body(size: 13, weight: FontWeight.w800, color: active ? AppColors.ink : AppColors.duneA(0.6))),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? hint,
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: AppText.body(size: 11, weight: FontWeight.w800, letterSpacing: 0.5, color: AppColors.duneA(0.55))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: AppText.body(size: 14, color: Colors.white),
          cursorColor: AppColors.dune,
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: AppText.body(size: 14, color: AppColors.duneA(0.4)),
            filled: true,
            fillColor: AppColors.duneA(0.08),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(999),
              borderSide: BorderSide(color: AppColors.duneA(0.2), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(999),
              borderSide: const BorderSide(color: AppColors.dune, width: 2),
            ),
          ),
        ),
      ],
    );
  }

}
