import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/data/models.dart';
import '../../../core/data/public_api.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_toggle.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../../core/widgets/dark_header.dart';
import '../../../core/widgets/filter_pill.dart';
import '../../auth/auth_controller.dart';
import 'estab_bulk_adjust_sheet.dart';
import '../../../l10n/i18n.dart';

/// Estab · Cardápio real: listar, pausar/ativar, criar, editar e excluir itens.
class EstabCardapioScreen extends ConsumerStatefulWidget {
  const EstabCardapioScreen({super.key});

  @override
  ConsumerState<EstabCardapioScreen> createState() => _EstabCardapioScreenState();
}

class _EstabCardapioScreenState extends ConsumerState<EstabCardapioScreen> {
  String _cat = 'Todos';
  final Set<String> _busy = {};

  // Controllers do formulário — donos do State (descartados no dispose da tela),
  // pra não serem usados após dispose enquanto o modal ainda anima o fechamento.
  final _fName = TextEditingController();
  final _fPrice = TextEditingController();
  final _fOldPrice = TextEditingController();
  final _fCat = TextEditingController();
  final _fSub = TextEditingController();
  final _fDesc = TextEditingController();
  final _fPhoto = TextEditingController();

  @override
  void dispose() {
    _fName.dispose();
    _fPrice.dispose();
    _fOldPrice.dispose();
    _fCat.dispose();
    _fSub.dispose();
    _fDesc.dispose();
    _fPhoto.dispose();
    super.dispose();
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

  Map<String, dynamic> _payload(PanelMenuItem m, {required bool active}) => {
        'id': m.dbId,
        'name': m.name,
        'price': m.price,
        if (m.oldPrice != null) 'oldPrice': m.oldPrice,
        'category': m.cat,
        'subcategory': m.sub.isEmpty ? m.cat : m.sub,
        if (m.desc.isNotEmpty) 'description': m.desc,
        if (m.photo.isNotEmpty) 'photo': m.photo,
        'active': active,
      };

  Future<void> _toggleActive(PanelMenuItem m) async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    setState(() => _busy.add(m.dbId));
    try {
      await ref.read(publicApiProvider).saveMenuItem(token, _payload(m, active: !m.active));
      ref.invalidate(establishmentMenuProvider);
    } catch (_) {
      _toast(tr('estabMenu.couldNotUpdate'));
    } finally {
      if (mounted) setState(() => _busy.remove(m.dbId));
    }
  }

  Future<void> _delete(PanelMenuItem m) async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    try {
      await ref.read(publicApiProvider).deleteMenuItem(token, m.dbId);
      ref.invalidate(establishmentMenuProvider);
      _toast(tr('estabMenu.itemDeleted'));
    } catch (_) {
      _toast(tr('estabMenu.couldNotDelete'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(establishmentMenuProvider);
    final estName = ref.watch(authProvider).name ?? context.tr('estab.venue');

    return Scaffold(
      backgroundColor: AppColors.canvas,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.coral,
        foregroundColor: Colors.white,
        onPressed: () => _openForm(null),
        icon: const Icon(Symbols.add, size: 20),
        label: Text(context.tr('estabMenu.newItem'), style: AppText.body(size: 14, weight: FontWeight.w800, color: Colors.white)),
      ),
      body: Column(
        children: [
          DarkHeader(eyebrow: estName, title: context.tr('estabMenu.title')),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.coral, strokeWidth: 3)),
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
              Text(context.tr('estabMenu.loadError'),
                  textAlign: TextAlign.center,
                  style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => ref.invalidate(establishmentMenuProvider),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(999)),
                  child: Text(context.tr('estab.retry'),
                      style: AppText.body(size: 13, weight: FontWeight.w800, color: AppColors.dune)),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _body(List<PanelMenuItem> all) {
    final cats = <String>['Todos', ...{for (final m in all) m.cat}..removeWhere((c) => c.isEmpty)];
    final items = _cat == 'Todos' ? all : all.where((m) => m.cat == _cat).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 90),
      children: [
        Text(context.tr('estabMenu.hint'),
            style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
        const SizedBox(height: 14),
        if (all.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Text(context.tr('estabMenu.empty'),
                  style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.inkA(0.45))),
            ),
          )
        else ...[
          GestureDetector(
            onTap: () => showBulkAdjustSheet(context, ref, all),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.ink, width: 2),
              ),
              child: Row(
                children: [
                  Icon(Symbols.percent, size: 18, color: AppColors.coralDeep),
                  const SizedBox(width: 8),
                  Text(context.tr('estabMenu.bulkAdjust'),
                      style: AppText.body(size: 13.5, weight: FontWeight.w800)),
                  const Spacer(),
                  Icon(Symbols.chevron_right, size: 20, color: AppColors.inkA(0.4)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 38,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < cats.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    FilterPill(label: cats[i] == 'Todos' ? context.tr('estabMenu.all') : cats[i], selected: cats[i] == _cat, onTap: () => setState(() => _cat = cats[i])),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          for (final m in items) ...[_itemRow(m), const SizedBox(height: 10)],
        ],
      ],
    );
  }

  Widget _itemRow(PanelMenuItem m) {
    final busy = _busy.contains(m.dbId);
    return Opacity(
      opacity: m.active ? 1 : 0.55,
      // BrutalCard (2 camadas): borda por cima + sombra fora do clip, então os
      // cantos ficam nítidos e a foto não vaza. `padding: zero` deixa a faixa
      // da imagem encostar na borda.
      child: BrutalCard(
        clip: true,
        padding: EdgeInsets.zero,
        onTap: () => _openForm(m),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  image: m.photo.isEmpty
                      ? null
                      : DecorationImage(image: NetworkImage(m.photo), fit: BoxFit.cover),
                ),
                child: m.photo.isEmpty
                    ? Icon(Symbols.restaurant, size: 22, color: AppColors.inkA(0.3))
                    : null,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(m.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.body(size: 14, weight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text.rich(TextSpan(children: [
                              TextSpan(text: money(m.price), style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.coralDeep)),
                              TextSpan(text: '  · ${m.active ? context.tr('estabMenu.onSale') : context.tr('estabMenu.paused')}',
                                  style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.inkA(0.4))),
                            ])),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      busy
                          ? const SizedBox(width: 30, height: 20, child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.coral))))
                          : AppToggle(value: m.active, onChanged: (_) => _toggleActive(m)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Form (criar/editar) ----
  Future<void> _openForm(PanelMenuItem? item) async {
    final isEdit = item != null;
    final name = _fName..text = item?.name ?? '';
    final price = _fPrice..text = (item != null ? item.price.toStringAsFixed(2) : '');
    final oldPrice = _fOldPrice..text = (item?.oldPrice != null ? item!.oldPrice!.toStringAsFixed(2) : '');
    final cat = _fCat..text = item?.cat ?? '';
    final sub = _fSub..text = item?.sub ?? '';
    final desc = _fDesc..text = item?.desc ?? '';
    final photo = _fPhoto..text = item?.photo ?? '';
    bool active = item?.active ?? true;
    String? err;
    bool saving = false;
    bool uploadingPhoto = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) {
          // Escolhe câmera/galeria, envia a foto pro Cloudinary e guarda a URL
          // resultante em `photo` (que o save() já usa).
          Future<void> pickPhoto() async {
            if (uploadingPhoto || saving) return;
            final source = await _pickSource(sheetCtx);
            if (source == null) return;
            final XFile? picked = await ImagePicker().pickImage(
              source: source,
              maxWidth: 1600,
              imageQuality: 82,
            );
            if (picked == null) return;
            setSheet(() => uploadingPhoto = true);
            try {
              final token = ref.read(authProvider).token;
              if (token == null) throw Exception('no-token');
              final url = await ref.read(publicApiProvider).uploadMenuPhoto(token, File(picked.path));
              photo.text = url;
              setSheet(() => uploadingPhoto = false);
            } catch (e) {
              setSheet(() => uploadingPhoto = false);
              final notConfigured = e is DioException && e.response?.statusCode == 503;
              _toast(notConfigured
                  ? tr('estabMenu.photosNotConfigured')
                  : tr('estabMenu.photoUploadError'));
            }
          }

          Future<void> save() async {
            final nm = name.text.trim();
            final pr = double.tryParse(price.text.trim().replaceAll(',', '.'));
            final ct = cat.text.trim();
            if (nm.isEmpty || pr == null || ct.isEmpty) {
              setSheet(() => err = tr('estabMenu.fillRequired'));
              return;
            }
            final token = ref.read(authProvider).token;
            if (token == null) return;
            setSheet(() {
              err = null;
              saving = true;
            });
            final op = oldPrice.text.trim().replaceAll(',', '.');
            try {
              await ref.read(publicApiProvider).saveMenuItem(token, {
                if (isEdit) 'id': item.dbId,
                'name': nm,
                'price': pr,
                if (op.isNotEmpty) 'oldPrice': double.tryParse(op),
                'category': ct,
                'subcategory': sub.text.trim().isEmpty ? ct : sub.text.trim(),
                if (desc.text.trim().isNotEmpty) 'description': desc.text.trim(),
                if (photo.text.trim().isNotEmpty) 'photo': photo.text.trim(),
                'active': active,
              });
              ref.invalidate(establishmentMenuProvider);
              if (sheetCtx.mounted) Navigator.pop(sheetCtx);
              _toast(isEdit ? tr('estabMenu.itemUpdated') : tr('estabMenu.itemCreated'));
            } catch (_) {
              setSheet(() {
                saving = false;
                err = tr('estabMenu.saveError');
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
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.inkA(0.2), borderRadius: BorderRadius.circular(999))),
                  ),
                  const SizedBox(height: 16),
                  Text(isEdit ? tr('estabMenu.editItem') : tr('estabMenu.newItem'), style: AppText.display(size: 20, letterSpacing: -0.3)),
                  const SizedBox(height: 16),
                  _sheetField(name, tr('estabMenu.fName')),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _sheetField(price, tr('estabMenu.fPrice'), number: true)),
                    const SizedBox(width: 10),
                    Expanded(child: _sheetField(oldPrice, tr('estabMenu.fOldPrice'), number: true)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _sheetField(cat, tr('estabMenu.fCategory'))),
                    const SizedBox(width: 10),
                    Expanded(child: _sheetField(sub, tr('estabMenu.fSubcategory'))),
                  ]),
                  const SizedBox(height: 10),
                  _sheetField(desc, tr('estabMenu.fDescription'), lines: 2),
                  const SizedBox(height: 10),
                  _photoField(
                    url: photo.text,
                    uploading: uploadingPhoto,
                    onPick: pickPhoto,
                    onRemove: () => setSheet(() => photo.text = ''),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(tr('estabMenu.onSale'), style: AppText.body(size: 14, weight: FontWeight.w700)),
                      const Spacer(),
                      AppToggle(value: active, onChanged: (v) => setSheet(() => active = v)),
                    ],
                  ),
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
                                : Text(isEdit ? tr('estabMenu.save') : tr('estabMenu.createItem'), style: AppText.body(size: 15, weight: FontWeight.w800, color: Colors.white)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (isEdit) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: saving
                            ? null
                            : () {
                                Navigator.pop(sheetCtx);
                                _delete(item);
                              },
                        child: Text(tr('estabMenu.deleteItem'), style: AppText.body(size: 13, weight: FontWeight.w800, color: AppColors.rose)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Pergunta câmera x galeria antes de abrir o seletor de imagem.
  Future<ImageSource?> _pickSource(BuildContext ctx) {
    return showModalBottomSheet<ImageSource>(
      context: ctx,
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.inkA(0.2), borderRadius: BorderRadius.circular(999))),
            const SizedBox(height: 6),
            ListTile(
              leading: const Icon(Symbols.photo_camera, color: AppColors.coralDeep),
              title: Text(tr('estabMenu.takePhoto'), style: AppText.body(size: 14, weight: FontWeight.w700)),
              onTap: () => Navigator.pop(c, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Symbols.photo_library, color: AppColors.coralDeep),
              title: Text(tr('estabMenu.fromGallery'), style: AppText.body(size: 14, weight: FontWeight.w700)),
              onTap: () => Navigator.pop(c, ImageSource.gallery),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// Campo de foto: preview + "Adicionar/Trocar/Remover". Upload vai pro
  /// Cloudinary; o que guardamos no item é a URL https resultante.
  Widget _photoField({
    required String url,
    required bool uploading,
    required VoidCallback onPick,
    required VoidCallback onRemove,
  }) {
    final hasPhoto = url.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('estabMenu.photoOptional'),
            style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.inkA(0.55))),
        const SizedBox(height: 8),
        Row(
          children: [
            GestureDetector(
              onTap: uploading ? null : onPick,
              child: Container(
                width: 76,
                height: 76,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.ink, width: 2),
                  image: hasPhoto ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover) : null,
                ),
                child: uploading
                    ? Container(
                        color: Colors.white.withValues(alpha: 0.65),
                        child: const Center(
                          child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.coral)),
                        ),
                      )
                    : (hasPhoto ? null : Icon(Symbols.add_a_photo, size: 24, color: AppColors.inkA(0.4))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: uploading ? null : onPick,
                    child: Text(uploading ? tr('estabMenu.uploading') : (hasPhoto ? tr('estabMenu.changePhoto') : tr('estabMenu.addPhoto')),
                        style: AppText.body(size: 14, weight: FontWeight.w800, color: AppColors.coralDeep)),
                  ),
                  const SizedBox(height: 2),
                  Text(tr('estabMenu.cameraOrGallery'),
                      style: AppText.body(size: 11.5, weight: FontWeight.w600, color: AppColors.inkA(0.45))),
                  if (hasPhoto && !uploading) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: onRemove,
                      child: Text(tr('estabMenu.remove'), style: AppText.body(size: 12, weight: FontWeight.w800, color: AppColors.rose)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sheetField(TextEditingController c, String hint, {bool number = false, int lines = 1}) {
    return TextField(
      controller: c,
      keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      maxLines: lines,
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
