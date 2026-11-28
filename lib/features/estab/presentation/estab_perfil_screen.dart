import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/data/public_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_toggle.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../../core/widgets/labeled_input.dart';
import '../../auth/auth_controller.dart';
import '../../shell/client_mode.dart';
import 'estab_kitchen_card.dart';
import 'estab_sub_header.dart';
import 'weekly_hours_editor.dart';
import '../../../l10n/i18n.dart';

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
  // Botão de entrega (módulo do garçom): null = ainda não lido do servidor.
  bool? _waiterModule;
  bool _savingWaiter = false;

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
    // Servidor antigo não manda `waiterModuleEnabled` → usa o flag do login.
    _waiterModule = (m['waiterModuleEnabled'] as bool?) ?? ref.read(authProvider).waiterModule;
  }

  /// Liga/desliga o botão de entrega. UI otimista: troca na hora e reverte se
  /// o servidor recusar.
  Future<void> _toggleWaiterModule(bool next) async {
    if (_savingWaiter) return;
    final token = ref.read(authProvider).token;
    if (token == null) return;
    final prev = _waiterModule ?? false;
    setState(() {
      _waiterModule = next;
      _savingWaiter = true;
    });
    try {
      final confirmed = await ref.read(publicApiProvider).setWaiterModule(token, next);
      if (!mounted) return;
      setState(() => _waiterModule = confirmed);
      ref.read(authProvider.notifier).setWaiterModule(confirmed); // gates de UI do painel
      _toast(confirmed ? tr('estabCfg.deliveryOn') : tr('estabCfg.deliveryOff'));
    } catch (_) {
      if (!mounted) return;
      setState(() => _waiterModule = prev);
      _toast(tr('estabCfg.deliveryError'));
    } finally {
      if (mounted) setState(() => _savingWaiter = false);
    }
  }

  /// "Ver como o cliente vê": abre o cardápio do próprio bar no MODO
  /// VISUALIZAÇÃO (cardápio + mesas iguais ao cliente, pagamento desativado),
  /// SEM deslogar (a sessão do estabelecimento continua salva).
  Future<void> _viewAsClient() async {
    final slug = await resolveOwnSlug(ref);
    if (!mounted) return;
    if (slug == null) {
      _toast(tr('estabCfg.openMenuError'));
      return;
    }
    enterClientMode(ref, context, slug);
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
      _toast(tr('estabCfg.nameRequired'));
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
      _toast(tr('estabCfg.profileSaved'));
    } catch (_) {
      if (mounted) _toast(tr('estabCfg.saveError'));
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
          EstabSubHeader(title: context.tr('estabCfg.profile')),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.coral, strokeWidth: 3)),
              error: (_, _) => Center(
                child: GestureDetector(
                  onTap: () => ref.invalidate(establishmentProfileProvider),
                  child: Text(context.tr('estab.loadErrorTap'),
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
          Text(context.tr('estabCfg.profileHint'),
              style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
          const SizedBox(height: 14),
          _waiterModuleCard(),
          const SizedBox(height: 14),
          BrutalCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LabeledInput(label: context.tr('estabCfg.fName'), controller: _nome),
                const SizedBox(height: 12),
                LabeledInput(label: context.tr('estabCfg.fTagline'), controller: _frase),
                const SizedBox(height: 12),
                LabeledInput(label: context.tr('estabCfg.fAddress'), controller: _endereco),
                const SizedBox(height: 16),
                _weeklyHours(),
                const SizedBox(height: 16),
                LabeledInput(label: 'WhatsApp', controller: _whatsapp, keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                LabeledInput(label: 'Instagram', controller: _instagram),
                const SizedBox(height: 14),
                AppButton.primary(label: _saving ? context.tr('estabCfg.saving') : context.tr('estabCfg.saveProfile'), onPressed: _save),
                const SizedBox(height: 8),
                Center(
                  child: Text(context.tr('estabCfg.changesLive'),
                      textAlign: TextAlign.center,
                      style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.4))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // Horário da cozinha: salva à parte (endpoint próprio).
          const EstabKitchenCard(),
          const SizedBox(height: 14),
          AppButton.ghost(label: context.tr('estabCfg.viewAsClient'), onPressed: _viewAsClient),
          const SizedBox(height: 6),
          Center(
            child: Text(context.tr('estabCfg.viewAsClientHint'),
                textAlign: TextAlign.center,
                style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.4))),
          ),
        ],
      ),
    );
  }

  Widget _waiterModuleCard() {
    final on = _waiterModule ?? false;
    return BrutalCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Symbols.room_service, size: 20, color: AppColors.coralDeep),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('estabCfg.deliveryBtn'),
                    style: AppText.body(size: 13, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                    on
                        ? context.tr('estabCfg.deliveryOnHint')
                        : context.tr('estabCfg.deliveryOffHint'),
                    style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Opacity(
            opacity: _savingWaiter ? 0.5 : 1,
            child: AppToggle(value: on, onChanged: _toggleWaiterModule),
          ),
        ],
      ),
    );
  }

  Widget _weeklyHours() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('estabCfg.hoursTitle'),
            style: AppText.body(size: 11, weight: FontWeight.w800, color: AppColors.inkA(0.55), letterSpacing: 0.4)),
        const SizedBox(height: 4),
        Text(context.tr('estabCfg.hoursHint'),
            style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.4))),
        const SizedBox(height: 8),
        WeeklyHoursEditor(week: _weekly, onChanged: () => setState(() {})),
      ],
    );
  }
}
