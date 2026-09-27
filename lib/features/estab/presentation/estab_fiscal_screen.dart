import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/data/models.dart';
import '../../../core/data/public_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../auth/auth_controller.dart';
import 'estab_sub_header.dart';

/// Estab · Conta → Notas fiscais. Lista os pedidos pagos e o estado da NFC-e,
/// permite emitir/reemitir. A CONFIG fiscal (certificado/CSC/token) fica no
/// painel web (padrão pagamentos) — aqui só operação.
class EstabFiscalScreen extends ConsumerStatefulWidget {
  const EstabFiscalScreen({super.key});

  @override
  ConsumerState<EstabFiscalScreen> createState() => _EstabFiscalScreenState();
}

class _EstabFiscalScreenState extends ConsumerState<EstabFiscalScreen> {
  String? _emitting;

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        content: Text(msg, style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.dune)),
      ));
  }

  Future<void> _openPanel() async {
    final ok = await launchUrl(Uri.parse('https://jurandir.app.br/pt/painel'),
        mode: LaunchMode.externalApplication);
    if (!ok && mounted) _toast('Não foi possível abrir o painel.');
  }

  Future<void> _emit(FiscalNota n) async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    setState(() => _emitting = n.orderId);
    final r = await ref.read(publicApiProvider).emitFiscal(token, n.orderId);
    if (!mounted) return;
    setState(() => _emitting = null);
    _toast(r.ok ? 'Nota enviada para emissão.' : (r.error ?? 'Não foi possível emitir a nota.'));
    ref.invalidate(fiscalDataProvider);
  }

  Future<void> _openDanfe(String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) _toast('Não foi possível abrir o DANFE.');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(fiscalDataProvider);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          const EstabSubHeader(title: 'Notas fiscais'),
          Expanded(
            child: async.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator(color: AppColors.coral, strokeWidth: 3)),
              error: (_, _) => _errorState(),
              data: _body,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Symbols.cloud_off, size: 40, color: AppColors.inkA(0.4)),
              const SizedBox(height: 12),
              Text('Não foi possível carregar as notas.',
                  style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.inkA(0.6))),
              const SizedBox(height: 12),
              AppButton.ghost(label: 'Tentar de novo', onPressed: () => ref.invalidate(fiscalDataProvider)),
            ],
          ),
        ),
      );

  Widget _body(FiscalData data) {
    final off = data.mode == 'OFF';
    return RefreshIndicator(
      color: AppColors.coral,
      onRefresh: () async => ref.invalidate(fiscalDataProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        children: [
          if (off) _offCard() else _modeCard(data),
          const SizedBox(height: 14),
          if (data.rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Text('Nenhum pedido pago recente.',
                    style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
              ),
            )
          else
            for (final n in data.rows) ...[
              _notaTile(n, off),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Widget _offCard() => BrutalCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Symbols.receipt_long, size: 18, color: AppColors.inkA(0.65)),
              const SizedBox(width: 8),
              Text('EMISSÃO DESLIGADA', style: AppText.display(size: 13)),
            ]),
            const SizedBox(height: 8),
            Text(
              'A nota fiscal está desligada. A configuração (certificado, CSC e provedor) é feita no painel web — leva pouco e só precisa fazer uma vez.',
              style: AppText.body(size: 12.5, weight: FontWeight.w600, color: AppColors.inkA(0.6)),
            ),
            const SizedBox(height: 12),
            AppButton.ghost(label: 'Configurar no painel web', onPressed: _openPanel),
          ],
        ),
      );

  Widget _modeCard(FiscalData data) {
    final auto = data.mode == 'AUTO_ON_PRINT';
    final homolog = data.env == 'HOMOLOGACAO';
    return BrutalCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(auto ? Symbols.bolt : Symbols.touch_app, size: 18, color: AppColors.coralDeep),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              auto ? 'Emissão automática ligada' : 'Emissão manual',
              style: AppText.body(size: 13, weight: FontWeight.w800),
            ),
          ),
          if (homolog)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF9C3),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('HOMOLOGAÇÃO',
                  style: AppText.body(size: 9, weight: FontWeight.w800, color: const Color(0xFF854D0E))),
            ),
        ],
      ),
    );
  }

  ({Color bg, Color fg, String label}) _statusStyle(String? s) {
    switch (s) {
      case 'AUTHORIZED':
        return (bg: const Color(0xFFDCFCE7), fg: const Color(0xFF166534), label: 'Autorizada');
      case 'PROCESSING':
        return (bg: const Color(0xFFFEF9C3), fg: const Color(0xFF854D0E), label: 'Processando');
      case 'QUEUED':
        return (bg: const Color(0xFFFEF9C3), fg: const Color(0xFF854D0E), label: 'Na fila');
      case 'REJECTED':
        return (bg: const Color(0xFFFEE2E2), fg: const Color(0xFF991B1B), label: 'Rejeitada');
      case 'ERROR':
        return (bg: const Color(0xFFFEE2E2), fg: const Color(0xFF991B1B), label: 'Erro');
      default:
        return (bg: const Color(0xFFF1F5F9), fg: const Color(0xFF64748B), label: 'Sem nota');
    }
  }

  Widget _notaTile(FiscalNota n, bool off) {
    final st = _statusStyle(n.status);
    final canEmit = !off && (n.status == null || n.status == 'ERROR' || n.status == 'REJECTED');
    return BrutalCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(n.orderCode,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(size: 13, weight: FontWeight.w800)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: st.bg, borderRadius: BorderRadius.circular(999)),
                child: Text(st.label.toUpperCase(),
                    style: AppText.body(size: 9, weight: FontWeight.w800, color: st.fg)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              'R\$ ${n.total.toStringAsFixed(2).replaceAll('.', ',')}',
              if (n.numero != null) 'NFC-e nº ${n.numero}',
            ].join('  ·  '),
            style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.inkA(0.5)),
          ),
          if (n.rejeicao != null && n.rejeicao!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(n.rejeicao!,
                style: AppText.body(size: 11, weight: FontWeight.w600, color: const Color(0xFF991B1B))),
          ],
          if (n.danfeUrl != null || canEmit) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (n.danfeUrl != null && n.danfeUrl!.isNotEmpty)
                  Expanded(child: AppButton.ghost(label: 'DANFE', onPressed: () => _openDanfe(n.danfeUrl!))),
                if (n.danfeUrl != null && n.danfeUrl!.isNotEmpty && canEmit) const SizedBox(width: 10),
                if (canEmit)
                  Expanded(
                    child: AppButton.dark(
                      label: _emitting == n.orderId
                          ? 'Emitindo…'
                          : (n.status == null ? 'Emitir' : 'Reemitir'),
                      onPressed: _emitting == n.orderId ? null : () => _emit(n),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
