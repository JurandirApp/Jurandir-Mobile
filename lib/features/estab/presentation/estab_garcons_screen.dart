import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/data/public_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/auth_controller.dart';
import '../../../core/widgets/brutal_card.dart';
import 'estab_sub_header.dart';

/// Estab · Garções: cadastra/edita/remove garçons e mostra, por garçom, quantas
/// entregas e quantos produtos ele já entregou (do OrderEvent DELIVERED).
class EstabGarconsScreen extends ConsumerWidget {
  const EstabGarconsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(estabWaitersProvider);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          const EstabSubHeader(title: 'Garções'),
          Expanded(
            child: async.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.coral, strokeWidth: 3)),
              error: (_, _) => _error(ref),
              data: (waiters) => ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: Material(
                      color: AppColors.coral,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _openForm(context, null),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Symbols.person_add, size: 18, color: Colors.white),
                              const SizedBox(width: 8),
                              Text('Novo garçom',
                                  style: AppText.body(
                                      size: 15, weight: FontWeight.w800, color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (waiters.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Column(
                        children: [
                          Icon(Symbols.badge, size: 40, color: AppColors.inkA(0.3)),
                          const SizedBox(height: 10),
                          Text('Nenhum garçom cadastrado ainda.',
                              style: AppText.body(
                                  size: 13, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
                        ],
                      ),
                    )
                  else
                    for (final w in waiters) ...[
                      _card(context, ref, w),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _error(WidgetRef ref) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Symbols.cloud_off, size: 40, color: AppColors.inkA(0.4)),
              const SizedBox(height: 12),
              Text('Não foi possível carregar os garçons.',
                  style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => ref.invalidate(estabWaitersProvider),
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

  Widget _card(BuildContext context, WidgetRef ref, PanelWaiter w) {
    return BrutalCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.duneA(0.6), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Symbols.badge, size: 22, color: AppColors.ink),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(w.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.display(size: 15, weight: FontWeight.w700, letterSpacing: 0)),
                    const SizedBox(height: 1),
                    Text(w.user,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
                  ],
                ),
              ),
              _iconBtn(Symbols.edit, AppColors.ink, () => _openForm(context, w)),
              const SizedBox(width: 6),
              _iconBtn(Symbols.delete, AppColors.danger, () => _confirmDelete(context, ref, w)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _stat('Entregas', '${w.deliveries}')),
              const SizedBox(width: 8),
              Expanded(child: _stat('Produtos entregues', '${w.products}')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: AppColors.duneA(0.4), borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: AppText.body(size: 9, weight: FontWeight.w700, color: AppColors.inkA(0.5))),
            const SizedBox(height: 2),
            Text(value, style: AppText.display(size: 18, letterSpacing: 0)),
          ],
        ),
      );

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 16, color: color),
        ),
      );

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, PanelWaiter w) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Excluir garçom?', style: AppText.display(size: 17, letterSpacing: -0.2)),
        content: Text('${w.name} perderá o acesso ao app do garçom. Esta ação não pode ser desfeita.',
            style: AppText.body(size: 13, weight: FontWeight.w500, color: AppColors.inkA(0.6))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Excluir', style: AppText.body(size: 14, weight: FontWeight.w800, color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final token = ref.read(authProvider).token;
    if (token == null) return;
    try {
      await ref.read(publicApiProvider).panelDeleteWaiter(token, w.id);
      ref.invalidate(estabWaitersProvider);
      messenger
        ..clearSnackBars()
        ..showSnackBar(garconsSnack('Garçom removido'));
    } catch (_) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(garconsSnack('Não foi possível remover'));
    }
  }

  void _openForm(BuildContext context, PanelWaiter? edit) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _WaiterFormSheet(edit: edit),
    );
  }
}

SnackBar garconsSnack(String msg) => SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      content: Text(msg, style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.dune)),
    );

/// Form (bottom sheet) de criar/editar garçom. É um StatefulWidget PRÓPRIO pra os
/// TextEditingController serem descartados em `dispose()` — que só roda quando o
/// sheet é desmontado (depois da animação de saída). Descartá-los antes (como num
/// `_openForm` async) faz o TextField rebuildar sobre um controller disposto na
/// animação de fechamento → crash "ChangeNotifier used after dispose".
class _WaiterFormSheet extends ConsumerStatefulWidget {
  final PanelWaiter? edit;
  const _WaiterFormSheet({this.edit});

  @override
  ConsumerState<_WaiterFormSheet> createState() => _WaiterFormSheetState();
}

class _WaiterFormSheetState extends ConsumerState<_WaiterFormSheet> {
  late final _name = TextEditingController(text: widget.edit?.name ?? '');
  late final _login = TextEditingController(text: widget.edit?.user ?? '');
  final _pass = TextEditingController();
  String? _err;
  bool _saving = false;

  bool get _isEdit => widget.edit != null;

  @override
  void dispose() {
    _name.dispose();
    _login.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nm = _name.text.trim();
    final lg = _login.text.trim();
    if (nm.isEmpty || lg.isEmpty) {
      setState(() => _err = 'Preencha nome e login.');
      return;
    }
    if (!_isEdit && _pass.text.trim().length < 6) {
      setState(() => _err = 'Senha: mínimo 6 caracteres.');
      return;
    }
    final token = ref.read(authProvider).token;
    if (token == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() {
      _err = null;
      _saving = true;
    });
    try {
      await ref.read(publicApiProvider).panelUpsertWaiter(token, {
        if (_isEdit) 'id': widget.edit!.id,
        'name': nm,
        'user': lg,
        if (_pass.text.trim().isNotEmpty) 'password': _pass.text.trim(),
      });
      ref.invalidate(estabWaitersProvider);
      if (mounted) nav.pop();
      messenger
        ..clearSnackBars()
        ..showSnackBar(garconsSnack(_isEdit ? 'Garçom atualizado' : 'Garçom criado'));
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _err = 'Não foi possível salvar (login pode já estar em uso).';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.inkA(0.2), borderRadius: BorderRadius.circular(999)),
              ),
            ),
            const SizedBox(height: 16),
            Text(_isEdit ? 'Editar garçom' : 'Novo garçom',
                style: AppText.display(size: 20, letterSpacing: -0.3)),
            const SizedBox(height: 16),
            _field(_name, 'Nome'),
            const SizedBox(height: 10),
            _field(_login, 'Login (usuário ou e-mail)', keyboard: TextInputType.emailAddress),
            const SizedBox(height: 10),
            _field(_pass, _isEdit ? 'Nova senha (em branco = manter)' : 'Senha de acesso', obscure: true),
            if (_err != null) ...[
              const SizedBox(height: 10),
              Text(_err!, style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.danger)),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: Material(
                color: _saving ? AppColors.coral.withValues(alpha: 0.6) : AppColors.coral,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  onTap: _saving ? null : _save,
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: Center(
                      child: _saving
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                          : Text(_isEdit ? 'Salvar' : 'Criar garçom',
                              style: AppText.body(size: 15, weight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, {bool obscure = false, TextInputType? keyboard}) {
    return TextField(
      controller: c,
      obscureText: obscure,
      keyboardType: keyboard,
      style: AppText.body(size: 14, weight: FontWeight.w600),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: AppText.body(size: 13.5, weight: FontWeight.w500, color: AppColors.inkA(0.4)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.inkA(0.15), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.ink, width: 2),
        ),
      ),
    );
  }
}
