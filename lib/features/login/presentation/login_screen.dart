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

/// Login: entra com a conta de estabelecimento ou admin (verificação real no
/// backend). Layout centralizado e clean.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    final email = _email.text.trim().toLowerCase();
    final pass = _pass.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Informe e-mail e senha.');
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: SafeArea(
          child: Stack(
            children: [
              // Conteúdo centralizado vertical e horizontalmente.
              LayoutBuilder(
                builder: (context, c) => SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: c.maxHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SvgPicture.asset('assets/images/jurandir-logo-horizontal.svg', width: 150),
                        const SizedBox(height: 28),
                        Text.rich(
                          const TextSpan(children: [
                            TextSpan(text: 'Uma conta,\n'),
                            TextSpan(text: 'tudo dentro.', style: TextStyle(color: AppColors.coralDeep)),
                          ]),
                          textAlign: TextAlign.center,
                          style: AppText.display(size: 28, letterSpacing: -0.5, height: 1.03, color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 300),
                          child: Text(
                            'Entre com a conta do seu estabelecimento ou da administração.',
                            textAlign: TextAlign.center,
                            style: AppText.body(size: 13.5, weight: FontWeight.w600, height: 1.5, color: AppColors.duneA(0.6)),
                          ),
                        ),
                        const SizedBox(height: 30),
                        _field(controller: _email, hint: 'E-mail', icon: Symbols.mail, keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 12),
                        _field(controller: _pass, hint: 'Senha', icon: Symbols.lock, obscure: true),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: AppText.body(size: 12.5, weight: FontWeight.w700, color: AppColors.rose),
                          ),
                        ],
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          child: Material(
                            color: _loading ? AppColors.coral.withValues(alpha: 0.6) : AppColors.coral,
                            borderRadius: BorderRadius.circular(999),
                            child: InkWell(
                              onTap: _loading ? null : _submit,
                              borderRadius: BorderRadius.circular(999),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: _loading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                                        )
                                      : Text('Entrar', style: AppText.body(size: 15, weight: FontWeight.w800, color: Colors.white)),
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
              // Voltar — canto superior esquerdo, sobre o conteúdo.
              Positioned(
                top: 4,
                left: 20,
                child: GestureDetector(
                  onTap: () => context.go('/perfil'),
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.duneA(0.12), shape: BoxShape.circle),
                    child: const Icon(Symbols.arrow_back, size: 20, color: AppColors.dune),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: AppText.body(size: 14.5, weight: FontWeight.w600, color: Colors.white),
      cursorColor: AppColors.dune,
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: Icon(icon, size: 19, color: AppColors.duneA(0.5)),
        hintText: hint,
        hintStyle: AppText.body(size: 14.5, weight: FontWeight.w500, color: AppColors.duneA(0.4)),
        filled: true,
        fillColor: AppColors.duneA(0.08),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: AppColors.duneA(0.18), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: AppColors.dune, width: 2),
        ),
      ),
    );
  }
}
