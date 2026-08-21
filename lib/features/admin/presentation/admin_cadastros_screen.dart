import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/data/models.dart';
import '../../../core/data/public_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../auth/auth_controller.dart';
import 'admin_sub_header.dart';

/// Admin · Cadastros: estabelecimentos reais + criar/editar (form).
class AdminCadastrosScreen extends ConsumerWidget {
  const AdminCadastrosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminOverviewProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          AdminSubHeader(
            title: 'Cadastros',
            trailing: GestureDetector(
              onTap: () => _openForm(context, ref, null),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(color: AppColors.coral, borderRadius: BorderRadius.circular(999)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Symbols.add, size: 15, color: Colors.white),
                    const SizedBox(width: 4),
                    Text('Cadastrar', style: AppText.body(size: 12, weight: FontWeight.w800, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.coral, strokeWidth: 3)),
              error: (_, _) => _error(ref),
              data: (ov) {
                final ests = ov?.establishments ?? const <AdminEstablishment>[];
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  children: [
                    Text('${ests.length} estabelecimento${ests.length == 1 ? '' : 's'} · toque para editar',
                        style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
                    const SizedBox(height: 12),
                    for (final e in ests) ...[
                      GestureDetector(onTap: () => _openForm(context, ref, e), child: _card(e)),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              },
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
              Text('Não foi possível carregar os cadastros.',
                  style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => ref.invalidate(adminOverviewProvider),
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

  Widget _card(AdminEstablishment e) {
    return BrutalCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(e.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.display(size: 14, weight: FontWeight.w700, letterSpacing: 0)),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.oceanDark.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
                          child: Text(e.type.toUpperCase(),
                              style: AppText.body(size: 9, weight: FontWeight.w800, color: AppColors.oceanDark)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('${e.city} · Plano ${e.plan}',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _statusBadge(e.active),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Symbols.person, size: 12, color: AppColors.inkA(0.4)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(e.ownerEmail.isEmpty ? '—' : e.ownerEmail,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: AppText.body(size: 10, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _cell('Faturamento', money(e.gmv))),
              const SizedBox(width: 6),
              Expanded(child: _cell('Pedidos', groupThousands(e.orders))),
              const SizedBox(width: 6),
              Expanded(child: _cell('Fee (${e.feePct}%)', money(e.fees), color: AppColors.successText)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(bool active) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: active ? AppColors.successBg : AppColors.inkA(0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(active ? 'Ativo' : 'Inativo',
            style: AppText.body(size: 10, weight: FontWeight.w700, color: active ? AppColors.successText : AppColors.inkA(0.5))),
      );

  Widget _cell(String label, String value, {Color? color}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
        decoration: BoxDecoration(color: AppColors.duneA(0.4), borderRadius: BorderRadius.circular(9)),
        child: Column(
          children: [
            Text(label.toUpperCase(),
                textAlign: TextAlign.center, style: AppText.body(size: 9, weight: FontWeight.w700, color: AppColors.inkA(0.5))),
            const SizedBox(height: 1),
            Text(value, style: AppText.display(size: 12, letterSpacing: 0, color: color ?? AppColors.ink)),
          ],
        ),
      );

  // ---- Form criar/editar ----
  Future<void> _openForm(BuildContext context, WidgetRef ref, AdminEstablishment? edit) async {
    final isEdit = edit != null;
    final name = TextEditingController(text: edit?.name ?? '');
    final owner = TextEditingController(text: edit?.owner ?? '');
    final type = TextEditingController(text: edit?.type ?? 'Bar');
    final city = TextEditingController(text: edit?.city == '—' ? '' : (edit?.city ?? ''));
    final plan = TextEditingController(text: edit?.plan ?? 'Básico');
    final fee = TextEditingController(text: (edit?.feePct ?? 8).toString());
    final loginEmail = TextEditingController(text: edit?.ownerEmail ?? '');
    final pass = TextEditingController();
    String? err;
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) {
          Future<void> save() async {
            final nm = name.text.trim();
            final ow = owner.text.trim();
            final tp = type.text.trim();
            final pl = plan.text.trim();
            final login = loginEmail.text.trim().toLowerCase();
            final feeInt = int.tryParse(fee.text.trim());
            if (nm.isEmpty || ow.isEmpty || tp.isEmpty || pl.isEmpty || login.isEmpty || feeInt == null) {
              setSheet(() => err = 'Preencha nome, responsável, tipo, plano, e-mail e fee.');
              return;
            }
            if (!isEdit && pass.text.trim().length < 6) {
              setSheet(() => err = 'Senha de acesso: mínimo 6 caracteres.');
              return;
            }
            final token = ref.read(authProvider).token;
            if (token == null) return;
            final messenger = ScaffoldMessenger.of(context);
            setSheet(() {
              err = null;
              saving = true;
            });
            try {
              await ref.read(publicApiProvider).saveEstablishment(token, {
                if (isEdit) 'id': edit.id,
                'name': nm,
                'owner': ow,
                'type': tp,
                'city': city.text.trim(),
                'plan': pl,
                'platformFeePct': feeInt,
                'user': login,
                if (pass.text.trim().isNotEmpty) 'password': pass.text.trim(),
              });
              ref.invalidate(adminOverviewProvider);
              if (sheetCtx.mounted) Navigator.pop(sheetCtx);
              messenger
                ..clearSnackBars()
                ..showSnackBar(SnackBar(
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppColors.ink,
                  content: Text(isEdit ? 'Estabelecimento atualizado' : 'Estabelecimento criado',
                      style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.dune)),
                ));
            } on DioException catch (e) {
              final code = e.response?.statusCode;
              setSheet(() {
                saving = false;
                err = code == 409
                    ? 'Esse e-mail de login já está em uso.'
                    : (code == 422 ? 'Dados inválidos (senha mín. 6).' : 'Não foi possível salvar.');
              });
            } catch (_) {
              setSheet(() {
                saving = false;
                err = 'Não foi possível salvar.';
              });
            }
          }

          final bottom = MediaQuery.viewInsetsOf(sheetCtx).bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.inkA(0.2), borderRadius: BorderRadius.circular(999)))),
                  const SizedBox(height: 16),
                  Text(isEdit ? 'Editar estabelecimento' : 'Novo estabelecimento',
                      style: AppText.display(size: 20, letterSpacing: -0.3)),
                  const SizedBox(height: 16),
                  _field(name, 'Nome'),
                  const SizedBox(height: 10),
                  _field(owner, 'Responsável'),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _field(type, 'Tipo (ex: Bar)')),
                    const SizedBox(width: 10),
                    Expanded(child: _field(plan, 'Plano')),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(flex: 2, child: _field(city, 'Cidade')),
                    const SizedBox(width: 10),
                    Expanded(child: _field(fee, 'Fee %', number: true)),
                  ]),
                  const SizedBox(height: 10),
                  _field(loginEmail, 'E-mail de login', keyboard: TextInputType.emailAddress),
                  const SizedBox(height: 10),
                  _field(pass, isEdit ? 'Nova senha (em branco = manter)' : 'Senha de acesso', obscure: true),
                  if (err != null) ...[
                    const SizedBox(height: 10),
                    Text(err!, style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.rose)),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: Material(
                      color: saving ? AppColors.coral.withValues(alpha: 0.6) : AppColors.coral,
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        onTap: saving ? null : save,
                        borderRadius: BorderRadius.circular(999),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          child: Center(
                            child: saving
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                                : Text(isEdit ? 'Salvar' : 'Criar estabelecimento',
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
        },
      ),
    );

    name.dispose();
    owner.dispose();
    type.dispose();
    city.dispose();
    plan.dispose();
    fee.dispose();
    loginEmail.dispose();
    pass.dispose();
  }

  Widget _field(TextEditingController c, String hint, {bool number = false, bool obscure = false, TextInputType? keyboard}) {
    return TextField(
      controller: c,
      obscureText: obscure,
      keyboardType: number ? const TextInputType.numberWithOptions(decimal: false) : keyboard,
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
