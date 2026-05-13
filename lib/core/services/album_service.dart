import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../api/api_client.dart';
import '../api/endpoints.dart';
import '../api/token_storage.dart';
import '../models/album_models.dart';
import '../models/mock_data.dart';
import 'user_service.dart';

class AlbumService {
  AlbumService._();

  static const String cameraAlbumId = 'camera';
  static const String chatAlbumId = 'chat';
  static const String chatAlbumName = 'الدردشة';
  static const String cameraAlbumName = 'الكاميرا';
  static const int initialPhotosLimit = 60;

  static final Map<String, List<AlbumPhoto>> photos = {};
  static final Map<String, List<AlbumFolder>> albums = {};
  static final Map<String, Future<void>> _inFlightSyncs = {};

  static Map<String, String>? get imageHeaders {
    final token = TokenStorage.accessToken?.trim();
    if (token == null || token.isEmpty) return null;
    return {'Authorization': 'Bearer $token'};
  }

  static void restore(
    String diwaniyaId,
    List<AlbumPhoto> restoredPhotos, {
    List<AlbumFolder>? restoredAlbums,
  }) {
    photos[diwaniyaId] = List<AlbumPhoto>.from(restoredPhotos);
    if (restoredAlbums != null) {
      albums[diwaniyaId] = List<AlbumFolder>.from(restoredAlbums);
    }
  }

  static List<AlbumPhoto> activePhotos([String? diwaniyaId]) {
    final did = diwaniyaId ?? currentDiwaniyaId;
    final list = List<AlbumPhoto>.from(photos[did] ?? const []);
    list.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return list.where((p) => !p.isDeleted).toList();
  }

  static List<AlbumFolder> current([String? diwaniyaId]) =>
      orderedFolders(diwaniyaId);

  static List<AlbumFolder> orderedFolders([String? diwaniyaId]) {
    final did = diwaniyaId ?? currentDiwaniyaId;
    final list = List<AlbumFolder>.from(albums[did] ?? const []);
    list.sort((a, b) {
      final ap = _folderPriority(a);
      final bp = _folderPriority(b);
      if (ap != bp) return ap.compareTo(bp);
      return a.createdAt.compareTo(b.createdAt);
    });
    return list;
  }

  static int _folderPriority(AlbumFolder folder) {
    final normalized = folder.name.trim();
    if (folder.id == cameraAlbumId || normalized == cameraAlbumName) return 0;
    if (folder.id == chatAlbumId || normalized == chatAlbumName) return 1;
    if (folder.isDefault) return 2;
    return 3;
  }

  static AlbumFolder? defaultCameraFolder([String? diwaniyaId]) {
    final folders = orderedFolders(diwaniyaId);
    return folders
            .firstWhere(
              (f) => f.id == cameraAlbumId || f.name.trim() == cameraAlbumName,
              orElse: () => folders.isNotEmpty ? folders.first : _emptyFolder,
            )
            .id
            .isEmpty
        ? null
        : folders.firstWhere(
            (f) => f.id == cameraAlbumId || f.name.trim() == cameraAlbumName,
            orElse: () => folders.first,
          );
  }

  static AlbumFolder? defaultChatFolder([String? diwaniyaId]) {
    final folders = orderedFolders(diwaniyaId);
    if (folders.isEmpty) return null;
    final match = folders
        .where((f) => f.id == chatAlbumId || f.name.trim() == chatAlbumName);
    return match.isEmpty ? null : match.first;
  }

  static AlbumFolder? findAlbumByName(String name, {String? diwaniyaId}) {
    final normalized = name.trim();
    if (normalized.isEmpty) return null;
    for (final folder in orderedFolders(diwaniyaId)) {
      if (folder.name.trim() == normalized) return folder;
    }
    return null;
  }

  static bool canDelete(AlbumFolder folder) => !folder.isDefault;

  static bool canDeletePhoto(AlbumPhoto photo) {
    if (photo.isDeleted) return false;
    final ownerId = photo.capturedByUserId.trim();
    return ownerId == UserService.currentId ||
        UserService.isManager(photo.diwaniyaId);
  }

  static bool canEditCaption(AlbumPhoto photo) => !photo.isDeleted;

  static List<AlbumPhoto> activeForAlbum(String albumId, [String? diwaniyaId]) {
    final resolved = resolveAlbumSelection(albumId, diwaniyaId);
    return activePhotos(diwaniyaId)
        .where((p) => p.albumId == resolved)
        .toList();
  }

  static String resolveAlbumSelection(String? selectedAlbumId,
      [String? diwaniyaId]) {
    final folders = orderedFolders(diwaniyaId);
    if (folders.isEmpty) return cameraAlbumId;
    final candidate = selectedAlbumId?.trim();
    if (candidate != null && candidate.isNotEmpty) {
      if (folders.any((f) => f.id == candidate)) return candidate;
      if (candidate == cameraAlbumId) {
        final camera = defaultCameraFolder(diwaniyaId);
        if (camera != null) return camera.id;
      }
      if (candidate == chatAlbumId) {
        final chat = defaultChatFolder(diwaniyaId);
        if (chat != null) return chat.id;
      }
    }
    return defaultCameraFolder(diwaniyaId)?.id ?? folders.first.id;
  }

  static int photoCountForAlbum(String albumId, [String? diwaniyaId]) =>
      activeForAlbum(albumId, diwaniyaId).length;

  static AlbumPhoto? coverPhotoForAlbum(String albumId, [String? diwaniyaId]) {
    final list = activeForAlbum(albumId, diwaniyaId);
    return list.isEmpty ? null : list.first;
  }

  static Future<void> syncForDiwaniya(
    String diwaniyaId, {
    bool bumpVersion = true,
    int limit = initialPhotosLimit,
  }) async {
    final existing = _inFlightSyncs[diwaniyaId];
    if (existing != null) {
      await existing;
      return;
    }

    final future = () async {
      final foldersRes = Map<String, dynamic>.from(
        await ApiClient.get(Endpoints.albumFolders(diwaniyaId)) as Map,
      );
      final fetchedFolders = ((foldersRes['folders'] as List?) ?? const [])
          .map((e) => AlbumFolder.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      albums[diwaniyaId] = fetchedFolders;

      final photosRes = Map<String, dynamic>.from(
        await ApiClient.get(
          Endpoints.albumPhotos(diwaniyaId),
          query: {'limit': '$limit'},
        ) as Map,
      );
      final merged = <String, AlbumPhoto>{};
      for (final photo in _photosFromResponse(diwaniyaId, photosRes)) {
        merged[photo.id] = photo;
      }

      final hasChatFolder = fetchedFolders.any(
        (f) => f.id == chatAlbumId || f.name.trim() == chatAlbumName,
      );
      if (hasChatFolder) {
        try {
          final chatPhotosRes = Map<String, dynamic>.from(
            await ApiClient.get(
              Endpoints.albumPhotos(diwaniyaId),
              query: {'album_id': chatAlbumId, 'limit': '$limit'},
            ) as Map,
          );
          for (final photo in _photosFromResponse(diwaniyaId, chatPhotosRes)) {
            merged[photo.id] = photo;
          }
        } catch (e) {
          // Do not fail the whole album if the chat folder query has a transient error.
          // The general album query above remains the safe fallback.
          debugPrint('[AlbumService] chat-album-sync failed: $e');
        }
      }

      final fetchedPhotos = merged.values.toList()
        ..sort((a, b) {
          final timeOrder = b.capturedAt.compareTo(a.capturedAt);
          if (timeOrder != 0) return timeOrder;
          return b.id.compareTo(a.id);
        });
      photos[diwaniyaId] = fetchedPhotos;
      if (bumpVersion) dataVersion.value++;
    }();

    _inFlightSyncs[diwaniyaId] = future;
    try {
      await future;
    } finally {
      _inFlightSyncs.remove(diwaniyaId);
    }
  }

  static List<AlbumPhoto> _photosFromResponse(
    String diwaniyaId,
    Map<String, dynamic> response,
  ) {
    return ((response['photos'] as List?) ?? const [])
        .map(
          (e) => AlbumPhoto.fromJson(
            _normalizePhotoJson(
                diwaniyaId, Map<String, dynamic>.from(e as Map)),
          ),
        )
        .toList();
  }

  static Map<String, dynamic> _normalizePhotoJson(
    String diwaniyaId,
    Map<String, dynamic> json,
  ) {
    final out = Map<String, dynamic>.from(json);
    final fileUrl = (json['file_url'] ?? json['fileUrl']) as String?;
    if (fileUrl != null && fileUrl.startsWith('/')) {
      final base = Uri.parse(ApiClientBase.baseUrl);
      out['file_url'] =
          '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}$fileUrl';
    }
    out['diwaniya_id'] ??= diwaniyaId;
    return out;
  }

  static Future<AlbumPhoto> uploadPhoto(
    File file, {
    String? caption,
    String? diwaniyaId,
    String albumId = cameraAlbumId,
  }) async {
    final did = diwaniyaId ?? currentDiwaniyaId;
    final resolvedAlbumId = resolveAlbumSelection(albumId, did);
    final res = await ApiClient.postMultipart(
      Endpoints.albumPhotos(did),
      file: file,
      fields: {
        'caption': caption ?? '',
        'album_id': resolvedAlbumId,
      },
    );
    final photo = AlbumPhoto.fromJson(
      _normalizePhotoJson(did, Map<String, dynamic>.from(res as Map)),
    );
    final list = photos.putIfAbsent(did, () => []);
    list.removeWhere((p) => p.id == photo.id);
    list.insert(0, photo);
    dataVersion.value++;
    return photo;
  }

  static Future<AlbumFolder> createAlbum(String name,
      {String? diwaniyaId}) async {
    final did = diwaniyaId ?? currentDiwaniyaId;
    final existing = findAlbumByName(name, diwaniyaId: did);
    if (existing != null) return existing;
    try {
      final res = await ApiClient.post(
        Endpoints.albumFolders(did),
        body: {'name': name},
      );
      final folder =
          AlbumFolder.fromJson(Map<String, dynamic>.from(res as Map));
      final list = albums.putIfAbsent(did, () => []);
      list.removeWhere((f) => f.id == folder.id);
      list.add(folder);
      dataVersion.value++;
      return folder;
    } catch (e) {
      final message = e.toString();
      final looksLikeAlreadyExists = message.contains('409') ||
          message.contains('already_exists') ||
          message.contains('الألبوم موجود مسبقاً');
      if (!looksLikeAlreadyExists) rethrow;
      await syncForDiwaniya(did, limit: initialPhotosLimit);
      final synced = findAlbumByName(name, diwaniyaId: did);
      if (synced != null) return synced;
      rethrow;
    }
  }

  static Future<AlbumFolder?> renameAlbum(
    String albumId,
    String newName, {
    String? diwaniyaId,
  }) async {
    final did = diwaniyaId ?? currentDiwaniyaId;
    final resolvedAlbumId = resolveAlbumSelection(albumId, did);
    final res = await ApiClient.patch(
      Endpoints.albumFolder(did, resolvedAlbumId),
      body: {'name': newName},
    );
    final folder = AlbumFolder.fromJson(Map<String, dynamic>.from(res as Map));
    final list = albums.putIfAbsent(did, () => []);
    final idx = list.indexWhere((f) => f.id == folder.id);
    if (idx >= 0) {
      list[idx] = folder;
    } else {
      list.add(folder);
    }
    dataVersion.value++;
    return folder;
  }

  static Future<bool> deleteAlbum(String albumId, {String? diwaniyaId}) async {
    final did = diwaniyaId ?? currentDiwaniyaId;
    final resolvedAlbumId = resolveAlbumSelection(albumId, did);
    final folder = orderedFolders(did).firstWhere(
      (f) => f.id == resolvedAlbumId,
      orElse: () => _emptyFolder,
    );
    if (folder.id.isEmpty || folder.isDefault) return false;
    final cameraId = defaultCameraFolder(did)?.id ?? cameraAlbumId;
    await ApiClient.delete(Endpoints.albumFolder(did, resolvedAlbumId));
    albums[did]?.removeWhere((f) => f.id == resolvedAlbumId);
    for (var i = 0; i < (photos[did]?.length ?? 0); i++) {
      final p = photos[did]![i];
      if (p.albumId == resolvedAlbumId) {
        photos[did]![i] = p.copyWith(albumId: cameraId);
      }
    }
    dataVersion.value++;
    return true;
  }

  static Future<AlbumPhoto?> updateCaption(
      AlbumPhoto photo, String? caption) async {
    final did = photo.diwaniyaId;
    final res = await ApiClient.patch(
      Endpoints.albumPhoto(did, photo.id),
      body: {'caption': caption},
    );
    final updated = AlbumPhoto.fromJson(
      _normalizePhotoJson(did, Map<String, dynamic>.from(res as Map)),
    );
    final idx = photos[did]?.indexWhere((p) => p.id == updated.id) ?? -1;
    if (idx >= 0) photos[did]![idx] = updated;
    dataVersion.value++;
    return updated;
  }

  static Future<AlbumPhoto?> movePhoto(
      AlbumPhoto photo, String targetAlbumId) async {
    final did = photo.diwaniyaId;
    final resolvedAlbumId = resolveAlbumSelection(targetAlbumId, did);
    final res = await ApiClient.patch(
      Endpoints.albumPhoto(did, photo.id),
      body: {'album_id': resolvedAlbumId},
    );
    final updated = AlbumPhoto.fromJson(
      _normalizePhotoJson(did, Map<String, dynamic>.from(res as Map)),
    );
    final idx = photos[did]?.indexWhere((p) => p.id == updated.id) ?? -1;
    if (idx >= 0) photos[did]![idx] = updated;
    dataVersion.value++;
    return updated;
  }

  static Future<bool> deletePhoto(AlbumPhoto photo) async {
    final did = photo.diwaniyaId;
    await ApiClient.delete(Endpoints.albumPhoto(did, photo.id));
    photos[did]?.removeWhere((p) => p.id == photo.id);
    dataVersion.value++;
    return true;
  }

  static Future<File> downloadPhotoToTemp(AlbumPhoto photo) async {
    final uri = Uri.parse(photo.fileUrl);
    final client = HttpClient();
    final request = await client.getUrl(uri);
    final token = TokenStorage.accessToken?.trim();
    if (token != null && token.isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    final response = await request.close();
    if (response.statusCode != 200) {
      throw HttpException('Failed to download photo: ${response.statusCode}');
    }
    final bytes = await consolidateHttpClientResponseBytes(response);
    final tempDir = await getTemporaryDirectory();
    final ext = _extensionFromUrl(photo.fileUrl);
    final file = File('${tempDir.path}/diwaniya_export_${photo.id}$ext');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static String _extensionFromUrl(String url) {
    final uri = Uri.tryParse(url);
    final path = uri?.path ?? url;
    final dot = path.lastIndexOf('.');
    if (dot <= 0 || dot == path.length - 1) {
      return '.jpg';
    }
    return path.substring(dot);
  }

  static List<AlbumFolder> folders([String? diwaniyaId]) =>
      orderedFolders(diwaniyaId);

  static Future<AlbumPhoto> addPhoto(
    String localPath, {
    String? caption,
    String? diwaniyaId,
    String albumId = cameraAlbumId,
  }) async {
    return uploadPhoto(
      File(localPath),
      caption: caption,
      diwaniyaId: diwaniyaId,
      albumId: albumId,
    );
  }

  static final AlbumFolder _emptyFolder = AlbumFolder(
    id: '',
    diwaniyaId: '',
    name: '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  );
}

class ApiClientBase {
  static String get baseUrl => const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://localhost:8000',
      );
}
