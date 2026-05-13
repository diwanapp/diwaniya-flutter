import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../config/theme/app_colors.dart';
import '../../core/models/album_models.dart';
import '../../core/models/mock_data.dart';
import '../../core/repositories/app_repository.dart';
import '../../core/services/album_service.dart';
import '../../core/services/analytics_event_names.dart';
import '../../core/services/entitlement_service.dart';
import '../../core/services/paywall_service.dart';
import '../../l10n/ar.dart';

class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _loading = false;
  String? _preparedDiwaniyaId;
  String get _diwaniyaId => currentDiwaniyaId;
  String _selectedAlbumId = AlbumService.cameraAlbumId;

  @override
  void initState() {
    super.initState();
    dataVersion.addListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureAlbumReady(forceRefresh: true);
    });
  }

  @override
  void dispose() {
    dataVersion.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    final did = _diwaniyaId;
    if (_preparedDiwaniyaId != did &&
        AlbumService.orderedFolders(did).isNotEmpty) {
      _preparedDiwaniyaId = did;
    }
    setState(() {});
  }

  Future<void> _ensureAlbumReady({bool forceRefresh = false}) async {
    final did = _diwaniyaId;
    final hasFolders = AlbumService.orderedFolders(did).isNotEmpty;
    final hasPhotos = AlbumService.activePhotos(did).isNotEmpty;
    final needsColdLoad = forceRefresh || (!hasFolders && !hasPhotos);
    if (!needsColdLoad) {
      _preparedDiwaniyaId = did;
      return;
    }
    if (_loading) return;
    if (mounted) setState(() => _loading = true);
    try {
      await AlbumService.syncForDiwaniya(did,
          limit: AlbumService.initialPhotosLimit);
      _preparedDiwaniyaId = did;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _persistAlbumOnly() async {
    await AppRepository.saveAlbum();
  }

  Future<void> _persistAlbumWithFeed() async {
    await AppRepository.saveAlbum();
    await AppRepository.saveActivities();
    await AppRepository.saveNotifications();
  }

  Future<void> _capture() async {
    if (_loading) return;

    final status = EntitlementService.checkPhotoLimit(_diwaniyaId);
    if (status == LimitStatus.atLimit) {
      PaywallService.trackEvent(
        AnalyticsEvents.photoLimitHit,
        properties: {'diwaniyaId': _diwaniyaId},
      );
      await PaywallService.showContextualPaywall(
        context,
        trigger: PaywallTrigger.photoLimit,
        title: 'حد الصور للنسخة المجانية',
        message:
            'الخطة المجانية تسمح بـ ${EntitlementService.freeMaxPhotos} صور فقط لكل ديوانية. رقّ للترقية إلى عدد أكبر.',
        icon: Icons.photo_library_rounded,
      );
      return;
    }

    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 82,
      maxWidth: 2200,
      maxHeight: 2200,
    );
    if (picked == null) return;

    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    setState(() => _loading = true);
    try {
      final directory = await getApplicationDocumentsDirectory();
      final albumDir = Directory('${directory.path}/album/$_diwaniyaId');
      if (!await albumDir.exists()) {
        await albumDir.create(recursive: true);
      }
      final ext =
          picked.path.contains('.') ? picked.path.split('.').last : 'jpg';
      final fileName = 'photo_${DateTime.now().microsecondsSinceEpoch}.$ext';
      final savedFile =
          await File(picked.path).copy('${albumDir.path}/$fileName');

      if (!mounted) return;

      await AlbumService.addPhoto(
        savedFile.path,
        diwaniyaId: _diwaniyaId,
        caption: null,
        albumId: AlbumService.cameraAlbumId,
      );
      _selectedAlbumId = AlbumService.cameraAlbumId;
      await _persistAlbumWithFeed();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createAlbum() async {
    final ctrl = TextEditingController();
    final c = context.cl;
    final result = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('ألبوم جديد', style: TextStyle(color: c.t1)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(hintText: 'اسم الألبوم'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(),
            child: Text(Ar.cancel, style: TextStyle(color: c.t3)),
          ),
          TextButton(
            onPressed: () => Navigator.of(d).pop(ctrl.text.trim()),
            child: Text(Ar.confirm, style: TextStyle(color: c.accent)),
          ),
        ],
      ),
    );
    final name = result?.trim() ?? '';
    if (name.isEmpty || !mounted) return;

    final existing =
        AlbumService.findAlbumByName(name, diwaniyaId: _diwaniyaId);
    final folder =
        await AlbumService.createAlbum(name, diwaniyaId: _diwaniyaId);
    _selectedAlbumId = folder.id;
    await _persistAlbumOnly();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          existing == null
              ? 'تم إنشاء الألبوم'
              : 'الألبوم موجود مسبقًا وتم فتحه',
        ),
      ),
    );
  }

  Future<void> _renameSelectedAlbum() async {
    if (_selectedAlbumId == AlbumService.cameraAlbumId) return;
    final folder = AlbumService.folders(_diwaniyaId)
        .where((a) => a.id == _selectedAlbumId)
        .firstOrNull;
    if (folder == null) return;

    final ctrl = TextEditingController(text: folder.name);
    final c = context.cl;
    final result = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('تعديل الألبوم', style: TextStyle(color: c.t1)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(hintText: 'اسم الألبوم'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(),
            child: Text(Ar.cancel, style: TextStyle(color: c.t3)),
          ),
          TextButton(
            onPressed: () => Navigator.of(d).pop(ctrl.text.trim()),
            child: Text(Ar.confirm, style: TextStyle(color: c.accent)),
          ),
        ],
      ),
    );
    final name = result?.trim() ?? '';
    if (name.isEmpty || !mounted) return;

    AlbumService.renameAlbum(
      _selectedAlbumId,
      name,
      diwaniyaId: _diwaniyaId,
    );
    await _persistAlbumOnly();
  }

  Future<void> _deleteSelectedAlbum() async {
    if (_selectedAlbumId == AlbumService.cameraAlbumId) return;
    final c = context.cl;
    final ok = await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
            backgroundColor: c.card,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Text('حذف الألبوم', style: TextStyle(color: c.t1)),
            content: Text(
              'سيتم حذف الألبوم ونقل صوره إلى ألبوم الكاميرا.',
              style: TextStyle(color: c.t2),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(d).pop(false),
                child: Text(Ar.cancel, style: TextStyle(color: c.t3)),
              ),
              TextButton(
                onPressed: () => Navigator.of(d).pop(true),
                child: Text(Ar.delete, style: TextStyle(color: c.error)),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    AlbumService.deleteAlbum(_selectedAlbumId, diwaniyaId: _diwaniyaId);
    _selectedAlbumId = AlbumService.cameraAlbumId;
    await _persistAlbumOnly();
  }

  Future<String?> _showCaptionDialog({String? initial, bool isEdit = false}) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final c = dialogContext.cl;
        return AlertDialog(
          backgroundColor: c.card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            isEdit ? Ar.editCaption : Ar.addCaption,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: c.t1),
          ),
          content: _CaptionDialogContent(initial: initial),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(''),
              child: Text(Ar.skip, style: TextStyle(color: c.t3)),
            ),
            TextButton(
              onPressed: () {
                final text = _CaptionDialogContent.activeText;
                Navigator.of(dialogContext).pop(text);
              },
              child: Text(Ar.confirm,
                  style:
                      TextStyle(color: c.accent, fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editCaption(AlbumPhoto photo) async {
    final result =
        await _showCaptionDialog(initial: photo.caption, isEdit: true);
    if (!mounted || result == null) return;
    AlbumService.updateCaption(photo, result.isEmpty ? null : result);
    await _persistAlbumOnly();
  }

  Future<void> _movePhoto(AlbumPhoto photo) async {
    final folders = AlbumService.orderedFolders(_diwaniyaId)
        .where((f) => f.id != photo.albumId)
        .toList();
    if (folders.isEmpty) return;

    final target = await showModalBottomSheet<AlbumFolder>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final c = sheetCtx.cl;
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetCtx).size.height * 0.65,
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'نقل الصورة إلى ألبوم',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: c.t1,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: folders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, index) {
                      final f = folders[index];
                      final cover =
                          AlbumService.coverPhotoForAlbum(f.id, _diwaniyaId);
                      return ListTile(
                        leading: _AlbumAvatar(cover: cover, accent: c.accent),
                        title: Text(
                          f.name,
                          style: TextStyle(
                              color: c.t1, fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${AlbumService.photoCountForAlbum(f.id, _diwaniyaId)} صورة',
                          style: TextStyle(color: c.t3, fontSize: 12),
                        ),
                        onTap: () => Navigator.of(sheetCtx).pop(f),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (target == null) return;
    AlbumService.movePhoto(photo, target.id);
    await _persistAlbumOnly();
    if (mounted) setState(() => _selectedAlbumId = target.id);
  }

  Future<void> _confirmDelete(AlbumPhoto photo) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            final c = dialogContext.cl;
            return AlertDialog(
              backgroundColor: c.card,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              title: Text(Ar.deletePhotoTitle, style: TextStyle(color: c.t1)),
              content:
                  Text(Ar.deletePhotoConfirm, style: TextStyle(color: c.t2)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(Ar.cancel, style: TextStyle(color: c.t3)),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(Ar.delete,
                      style: TextStyle(
                          color: c.error, fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!ok || !mounted) return;
    AlbumService.deletePhoto(photo);
    await _persistAlbumWithFeed();
  }

  void _openViewer(AlbumPhoto photo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AlbumPhotoViewer(
          photo: photo,
          onDelete: (p) async => _confirmDelete(p),
          onEditCaption: (p) async => _editCaption(p),
          onMove: (p) async => _movePhoto(p),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    if (_preparedDiwaniyaId != _diwaniyaId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureAlbumReady(forceRefresh: true);
      });
    }
    final folders = AlbumService.orderedFolders(_diwaniyaId);
    final selectedAlbum =
        folders.where((f) => f.id == _selectedAlbumId).firstOrNull ??
            folders.first;
    if (_selectedAlbumId != selectedAlbum.id) {
      _selectedAlbumId = selectedAlbum.id;
    }

    final photos = AlbumService.activeForAlbum(_selectedAlbumId, _diwaniyaId);
    final isDefaultAlbum = _selectedAlbumId == AlbumService.cameraAlbumId;
    final totalPhotos = AlbumService.activePhotos(_diwaniyaId).length;
    final cover =
        AlbumService.coverPhotoForAlbum(_selectedAlbumId, _diwaniyaId);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(
          Ar.albumTitle,
          style: TextStyle(color: c.t1, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (!isDefaultAlbum)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'rename') {
                  _renameSelectedAlbum();
                } else if (value == 'delete') {
                  _deleteSelectedAlbum();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem<String>(
                  value: 'rename',
                  child: Text('تعديل الألبوم'),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('حذف الألبوم'),
                ),
              ],
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: BoxDecoration(
            color: c.card,
            border: Border(top: BorderSide(color: c.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _createAlbum,
                  icon: const Icon(Icons.create_new_folder_rounded),
                  label: const Text('إضافة ألبوم'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _capture,
                  icon: Icon(_loading
                      ? Icons.hourglass_top_rounded
                      : Icons.photo_camera_rounded),
                  label: Text(_loading ? Ar.loading : Ar.capturePhoto),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: _AlbumHeroCard(
                  title: selectedAlbum.name,
                  subtitle: isDefaultAlbum
                      ? 'ألبوم الصور الأساسية في الديوانية'
                      : selectedAlbum.name == AlbumService.chatAlbumName
                          ? 'صور الدردشة المحفوظة تلقائيًا'
                          : 'ألبوم مخصص لتنظيم الصور',
                  totalPhotos: totalPhotos,
                  albumCount: folders.length,
                  currentCount: photos.length,
                  cover: cover,
                ),
              ),
              SizedBox(
                height: 74,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  scrollDirection: Axis.horizontal,
                  itemCount: folders.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, index) {
                    final folder = folders[index];
                    final selected = folder.id == _selectedAlbumId;
                    final count =
                        AlbumService.photoCountForAlbum(folder.id, _diwaniyaId);
                    final folderCover =
                        AlbumService.coverPhotoForAlbum(folder.id, _diwaniyaId);
                    return _AlbumChipCard(
                      folder: folder,
                      count: count,
                      selected: selected,
                      cover: folderCover,
                      onTap: () => setState(() => _selectedAlbumId = folder.id),
                    );
                  },
                ),
              ),
              Expanded(
                child: photos.isEmpty
                    ? _AlbumEmptyState(
                        isDefaultAlbum: isDefaultAlbum,
                        isChatAlbum:
                            selectedAlbum.name == AlbumService.chatAlbumName,
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.86,
                        ),
                        itemCount: photos.length,
                        itemBuilder: (context, index) {
                          final photo = photos[index];
                          final canEdit = AlbumService.canEditCaption(photo);
                          final canDelete = AlbumService.canDeletePhoto(photo);
                          return GestureDetector(
                            onTap: () => _openViewer(photo),
                            child: Container(
                              decoration: BoxDecoration(
                                color: c.card,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: c.shadow.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        _AlbumImageView(
                                          photo: photo,
                                          fit: BoxFit.cover,
                                          fallback: Container(
                                            color: c.inputBg,
                                            child: Icon(
                                                Icons.broken_image_outlined,
                                                color: c.t3,
                                                size: 36),
                                          ),
                                        ),
                                        Positioned(
                                          right: 10,
                                          bottom: 10,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.black
                                                  .withValues(alpha: 0.42),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              _formatDate(photo.capturedAt),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (canEdit || canDelete)
                                          Positioned(
                                            top: 8,
                                            left: 8,
                                            child: Row(
                                              children: [
                                                if (canEdit) ...[
                                                  _OverlayButton(
                                                    icon: Icons
                                                        .drive_file_move_rounded,
                                                    onTap: () =>
                                                        _movePhoto(photo),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  _OverlayButton(
                                                    icon: Icons.edit_rounded,
                                                    onTap: () =>
                                                        _editCaption(photo),
                                                  ),
                                                ],
                                                if (canEdit && canDelete)
                                                  const SizedBox(width: 6),
                                                if (canDelete)
                                                  _OverlayButton(
                                                    icon: Icons
                                                        .delete_outline_rounded,
                                                    onTap: () =>
                                                        _confirmDelete(photo),
                                                  ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (photo.caption?.trim().isNotEmpty ==
                                            true)
                                          Text(
                                            photo.caption!.trim(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: c.t1,
                                            ),
                                          ),
                                        if (photo.caption?.trim().isNotEmpty ==
                                            true)
                                          const SizedBox(height: 4),
                                        Text(
                                          '${photo.capturedByName} · ${_formatDate(photo.capturedAt)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 11, color: c.t3),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          if (_loading)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.08),
                  alignment: Alignment.center,
                  child: CircularProgressIndicator(color: c.accent),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}

class _AlbumImageView extends StatelessWidget {
  final AlbumPhoto photo;
  final BoxFit fit;
  final Widget fallback;

  const _AlbumImageView({
    required this.photo,
    required this.fallback,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final localPath = photo.localPath.trim();
    final localFile = localPath.isNotEmpty ? File(localPath) : null;
    if (localFile != null && localFile.existsSync()) {
      return Image.file(
        localFile,
        fit: fit,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    final url = photo.fileUrl.trim();
    if (url.isNotEmpty) {
      return Image.network(
        url,
        fit: fit,
        headers: AlbumService.imageHeaders,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    return fallback;
  }
}

class _AlbumHeroCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int totalPhotos;
  final int albumCount;
  final int currentCount;
  final AlbumPhoto? cover;

  const _AlbumHeroCard({
    required this.title,
    required this.subtitle,
    required this.totalPhotos,
    required this.albumCount,
    required this.currentCount,
    required this.cover,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Container(
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            c.accent.withValues(alpha: 0.18),
            c.accent.withValues(alpha: 0.07),
          ],
        ),
        border: Border.all(color: c.accent.withValues(alpha: 0.18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (cover != null)
            Opacity(
              opacity: 0.18,
              child: _AlbumImageView(
                photo: cover!,
                fit: BoxFit.cover,
                fallback: const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: c.t1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.5,
                          color: c.t2,
                        ),
                      ),
                      const Spacer(),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MiniMetric(
                              label: 'صور الديوانية', value: '$totalPhotos'),
                          _MiniMetric(label: 'الألبومات', value: '$albumCount'),
                          _MiniMetric(
                              label: 'داخل الحالي', value: '$currentCount'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                _AlbumAvatar(cover: cover, accent: c.accent, large: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;

  const _MiniMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: c.card.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: c.t1,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: c.t3, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _AlbumAvatar extends StatelessWidget {
  final AlbumPhoto? cover;
  final Color accent;
  final bool large;

  const _AlbumAvatar({
    required this.cover,
    required this.accent,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = large ? 58.0 : 42.0;
    if (cover == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.photo_album_rounded,
          color: accent,
          size: large ? 28 : 22,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: _AlbumImageView(
        photo: cover!,
        fit: BoxFit.cover,
        fallback: Container(
          color: accent.withValues(alpha: 0.14),
          child: Icon(
            Icons.photo_album_rounded,
            color: accent,
            size: large ? 28 : 22,
          ),
        ),
      ),
    );
  }
}

class _AlbumChipCard extends StatelessWidget {
  final AlbumFolder folder;
  final int count;
  final bool selected;
  final AlbumPhoto? cover;
  final VoidCallback onTap;

  const _AlbumChipCard({
    required this.folder,
    required this.count,
    required this.selected,
    required this.cover,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 138,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? c.accentMuted : c.card,
          borderRadius: BorderRadius.circular(18),
          border: selected
              ? Border.all(color: c.accent.withValues(alpha: 0.35))
              : Border.all(color: c.border),
        ),
        child: Row(
          children: [
            _AlbumAvatar(cover: cover, accent: c.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folder.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? c.accent : c.t1,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$count صورة',
                    style: TextStyle(color: c.t3, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumEmptyState extends StatelessWidget {
  final bool isDefaultAlbum;
  final bool isChatAlbum;

  const _AlbumEmptyState({
    required this.isDefaultAlbum,
    required this.isChatAlbum,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final title = isChatAlbum
        ? 'لا توجد صور دردشة بعد'
        : isDefaultAlbum
            ? 'لا توجد صور في ألبوم الكاميرا'
            : 'لا توجد صور في هذا الألبوم';
    final subtitle = isChatAlbum
        ? 'صور الدردشة ستظهر هنا تلقائيًا عند إرسال صور داخل المحادثة.'
        : 'التقط صورة جديدة أو انقل صورًا من ألبوم آخر.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: c.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                isChatAlbum
                    ? Icons.chat_bubble_outline_rounded
                    : Icons.photo_library_outlined,
                size: 38,
                color: c.accent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.t1,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.t3, height: 1.7),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptionDialogContent extends StatefulWidget {
  final String? initial;
  const _CaptionDialogContent({this.initial});

  static TextEditingController? _activeController;
  static String get activeText => _activeController?.text.trim() ?? '';

  @override
  State<_CaptionDialogContent> createState() => _CaptionDialogContentState();
}

class _CaptionDialogContentState extends State<_CaptionDialogContent> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
    _CaptionDialogContent._activeController = _ctrl;
  }

  @override
  void dispose() {
    if (_CaptionDialogContent._activeController == _ctrl) {
      _CaptionDialogContent._activeController = null;
    }
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return TextField(
      controller: _ctrl,
      autofocus: true,
      maxLength: 120,
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
      style: TextStyle(color: c.t1),
      decoration: const InputDecoration(hintText: Ar.captionOptional),
    );
  }
}

class _OverlayButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _OverlayButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}

class _AlbumPhotoViewer extends StatefulWidget {
  final AlbumPhoto photo;
  final Future<void> Function(AlbumPhoto) onDelete;
  final Future<void> Function(AlbumPhoto) onEditCaption;
  final Future<void> Function(AlbumPhoto) onMove;

  const _AlbumPhotoViewer({
    required this.photo,
    required this.onDelete,
    required this.onEditCaption,
    required this.onMove,
  });

  @override
  State<_AlbumPhotoViewer> createState() => _AlbumPhotoViewerState();
}

class _AlbumPhotoViewerState extends State<_AlbumPhotoViewer> {
  late AlbumPhoto _photo;

  @override
  void initState() {
    super.initState();
    _photo = widget.photo;
    dataVersion.addListener(_syncPhoto);
  }

  @override
  void dispose() {
    dataVersion.removeListener(_syncPhoto);
    super.dispose();
  }

  void _syncPhoto() {
    if (!mounted) return;
    final fresh = AlbumService.activePhotos(_photo.diwaniyaId)
        .where((p) => p.id == _photo.id)
        .firstOrNull;
    if (fresh == null) {
      Navigator.of(context).pop();
      return;
    }
    if (fresh != _photo) {
      setState(() => _photo = fresh);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final canEdit = AlbumService.canEditCaption(_photo);
    final canDel = AlbumService.canDeletePhoto(_photo);
    final time =
        '${_photo.capturedAt.day}/${_photo.capturedAt.month}/${_photo.capturedAt.year}';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (canEdit)
            IconButton(
              onPressed: () => widget.onMove(_photo),
              icon: const Icon(Icons.drive_file_move_rounded),
              tooltip: 'نقل',
            ),
          if (canEdit)
            IconButton(
              onPressed: () => widget.onEditCaption(_photo),
              icon: const Icon(Icons.edit_rounded),
              tooltip: Ar.editCaption,
            ),
          if (canDel)
            IconButton(
              onPressed: () => widget.onDelete(_photo),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              child: Center(
                child: _AlbumImageView(
                  photo: _photo,
                  fit: BoxFit.contain,
                  fallback: const Icon(Icons.broken_image_outlined,
                      color: Colors.white70, size: 64),
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            color: c.card,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_photo.caption?.trim().isNotEmpty == true)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _photo.caption!.trim(),
                          style: TextStyle(
                            color: c.t1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (canEdit)
                        GestureDetector(
                          onTap: () => widget.onEditCaption(_photo),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(Icons.edit_rounded,
                                size: 16, color: c.accent),
                          ),
                        ),
                    ],
                  ),
                if (_photo.caption?.trim().isNotEmpty == true)
                  const SizedBox(height: 4),
                Text(
                  '${_photo.capturedByName} · $time',
                  style: TextStyle(color: c.t3, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
