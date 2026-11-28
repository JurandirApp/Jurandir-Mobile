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
import '../../../l10n/i18n.dart';

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
            title: tr('admin.signups'),
            trailing: GestureDetector(
              onTap: () => _openForm(context, null),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(color: AppColors.coral, borderRadius: BorderRadius.circular(999)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Symbols.add, size: 15, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(tr('admin.register'), style: AppText.body(size: 12, weight: FontWeight.w800, color: Colors.white)),
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
                    Text(trn('admin.venuesTapEdit', ests.length),
                        style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
                    const SizedBox(height: 12),
                    for (final e in ests) ...[
                      GestureDetector(onTap: () => _openForm(context, e), child: _card(e)),
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

  /// Abre o form de criar/editar. O conteúdo é um StatefulWidget próprio
  /// (`_EstabFormSheet`) que dona e descarta os controllers no seu dispose() —
  /// NÃO descartar aqui depois do await evita o crash "ChangeNotifier used after
  /// dispose" (o sheet ainda anima a saída com os TextFields vivos).
  void _openForm(BuildContext context, AdminEstablishment? edit) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _EstabFormSheet(edit: edit),
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
              Text(tr('admin.loadSignupsError'),
                  style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => ref.invalidate(adminOverviewProvider),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(999)),
                  child: Text(tr('admin.retry'),
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
                    Text(tr('admin.cityPlan', {'city': e.city, 'plan': e.plan}),
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
              Expanded(child: _cell(tr('admin.revenue'), money(e.gmv))),
              const SizedBox(width: 6),
              Expanded(child: _cell(tr('admin.orders'), groupThousands(e.orders))),
              const SizedBox(width: 6),
              Expanded(child: _cell(tr('admin.feePct', {'pct': e.feePct}), money(e.fees), color: AppColors.successText)),
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
        child: Text(active ? tr('admin.active') : tr('admin.inactive'),
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
}

/// Form de criar/editar estabelecimento (conteúdo do bottom sheet). É um
/// StatefulWidget próprio pra donar os TextEditingController e descartá-los no
/// `dispose()` — que roda só quando o sheet sai da árvore de verdade (fim da
/// animação), evitando o crash "ChangeNotifier used after dispose".
class _EstabFormSheet extends ConsumerStatefulWidget {
  const _EstabFormSheet({required this.edit});

  final AdminEstablishment? edit;

  @override
  ConsumerState<_EstabFormSheet> createState() => _EstabFormSheetState();
}

class _EstabFormSheetState extends ConsumerState<_EstabFormSheet> {
  late final bool _isEdit = widget.edit != null;
  late final _name = TextEditingController(text: widget.edit?.name ?? '');
  late final _owner = TextEditingController(text: widget.edit?.owner ?? '');
  late final _type = TextEditingController(text: widget.edit?.type ?? 'Bar');
  late final _city = TextEditingController(text: widget.edit?.city == '—' ? '' : (widget.edit?.city ?? ''));
  late final _plan = TextEditingController(text: widget.edit?.plan ?? 'Básico');
  late final _fee = TextEditingController(text: (widget.edit?.feePct ?? 8).toString());
  late final _loginEmail = TextEditingController(text: widget.edit?.ownerEmail ?? '');
  late final _pass = TextEditingController();
  late bool _waiterModule = widget.edit?.waiterModule ?? false;
  String? _err;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _owner, _type, _city, _plan, _fee, _loginEmail, _pass]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final nm = _name.text.trim();
    final ow = _owner.text.trim();
    final tp = _type.text.trim();
    final pl = _plan.text.trim();
    final login = _loginEmail.text.trim().toLowerCase();
    final feeInt = int.tryParse(_fee.text.trim());
    if (nm.isEmpty || ow.isEmpty || tp.isEmpty || pl.isEmpty || login.isEmpty || feeInt == null) {
      setState(() => _err = tr('admin.fillAll'));
      return;
    }
    if (!_isEdit && _pass.text.trim().length < 6) {
      setState(() => _err = tr('admin.pwMin'));
      return;
    }
    final token = ref.read(authProvider).token;
    if (token == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _err = null;
      _saving = true;
    });
    try {
      await ref.read(publicApiProvider).saveEstablishment(token, {
        if (_isEdit) 'id': widget.edit!.id,
        'name': nm,
        'owner': ow,
        'type': tp,
        'city': _city.text.trim(),
        'plan': pl,
        'platformFeePct': feeInt,
        'user': login,
        if (_pass.text.trim().isNotEmpty) 'password': _pass.text.trim(),
        'waiterModuleEnabled': _waiterModule,
      });
      ref.invalidate(adminOverviewProvider);
      if (mounted) Navigator.pop(context);
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.ink,
          content: Text(_isEdit ? tr('admin.venueUpdated') : tr('admin.venueCreated'),
              style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.dune)),
        ));
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (!mounted) return;
      setState(() {
        _saving = false;
        _err = code == 409
            ? tr('admin.emailInUse')
            : (code == 422 ? tr('admin.invalidData') : tr('admin.saveError'));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _err = tr('admin.saveError');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.inkA(0.2), borderRadius: BorderRadius.circular(999)))),
            const SizedBox(height: 16),
            Text(_isEdit ? tr('admin.editVenue') : tr('admin.newVenue'),
                style: AppText.display(size: 20, letterSpacing: -0.3)),
            const SizedBox(height: 16),
            _field(_name, tr('admin.fName')),
            const SizedBox(height: 10),
            _field(_owner, tr('admin.fOwner')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _field(_type, tr('admin.fType'))),
              const SizedBox(width: 10),
              Expanded(child: _field(_plan, tr('admin.fPlan'))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(flex: 2, child: _field(_city, tr('admin.fCity'))),
              const SizedBox(width: 10),
              Expanded(child: _field(_fee, tr('admin.fFee'), number: true)),
            ]),
            const SizedBox(height: 10),
            _field(_loginEmail, tr('admin.fLoginEmail'), keyboard: TextInputType.emailAddress),
            const SizedBox(height: 10),
            _field(_pass, _isEdit ? tr('admin.fNewPwKeep') : tr('admin.fPw'), obscure: true),
            const SizedBox(height: 12),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _waiterModule = !_waiterModule),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.inkA(0.15), width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Symbols.room_service, size: 20, color: AppColors.coralDeep),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('admin.waiterModule'), style: AppText.body(size: 14, weight: FontWeight.w700)),
                          const SizedBox(height: 1),
                          Text(tr('admin.waiterModuleHint'),
                              style: AppText.body(size: 11, weight: FontWeight.w500, color: AppColors.inkA(0.45))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 46,
                      height: 26,
                      alignment: _waiterModule ? Alignment.centerRight : Alignment.centerLeft,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: _waiterModule ? AppColors.coral : AppColors.inkA(0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: SizedBox(width: 20, height: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_err != null) ...[
              const SizedBox(height: 10),
              Text(_err!, style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.rose)),
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
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                          : Text(_isEdit ? tr('admin.save') : tr('admin.createVenue'),
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
