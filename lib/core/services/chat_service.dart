import 'dart:io';
import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/api_config.dart';
import '../api/token_storage.dart';
import '../models/chat_models.dart';
import '../models/mock_data.dart';
import 'album_service.dart';
import 'user_service.dart';

class ChatService {
  ChatService._();

  static const String chatAlbumName = 'الدردشة';
  static const int initialMessagesLimit = 50;

  static final Map<String, List<ChatMessage>> messages =
      <String, List<ChatMessage>>{};
  static final Map<String, int> _unreadByDiwaniya = <String, int>{};
  static final Map<String, Future<void>> _inFlightSyncs =
      <String, Future<void>>{};

  static Map<String, List<ChatMessage>> get messagesByDiwaniya => messages;

  static Map<String, String>? get mediaHeaders {
    final token = TokenStorage.accessToken?.trim();
    if (token == null || token.isEmpty) return null;
    return {'Authorization': 'Bearer $token'};
  }

  static List<ChatMessage> current([String? diwaniyaId]) {
    final did = diwaniyaId ?? currentDiwaniyaId;
    return messages[did] ??= <ChatMessage>[];
  }

  static void restore(String diwaniyaId, List<ChatMessage> restored) {
    messages[diwaniyaId] = List<ChatMessage>.from(restored)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  static List<ChatMessage> activeMessages([String? diwaniyaId]) {
    final list = current(diwaniyaId).where((m) => !m.isDeleted).toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  static String previewOf(ChatMessage msg) {
    switch (msg.messageType) {
      case 'image':
        return 'صورة';
      case 'voice':
        return 'رسالة صوتية';
      case 'file':
        return msg.text?.trim().isNotEmpty == true ? msg.text! : 'ملف';
      default:
        final t = msg.text ?? '';
        return t.length > 50 ? '${t.substring(0, 50)}...' : t;
    }
  }

  static String _messagesEndpoint(String diwaniyaId) =>
      '/diwaniyas/$diwaniyaId/chat/messages';
  static String _mediaEndpoint(String diwaniyaId) =>
      '/diwaniyas/$diwaniyaId/chat/messages/media';
  static String _readEndpoint(String diwaniyaId) =>
      '/diwaniyas/$diwaniyaId/chat/read';
  static String _unreadSummaryEndpoint() => '/me/chat/unread-summary';

  static String _resolveUrl(String value) {
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    final base = Uri.parse(ApiClientBase.baseUrl);
    return '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}$value';
  }

  static ChatMessage _messageFromApi(Map<String, dynamic> raw) {
    final out = Map<String, dynamic>.from(raw);
    final attachmentUrl =
        (out['attachment_url'] ?? out['attachmentUrl']) as String?;
    final isReadByMe =
        out['is_read_by_me'] == true || out['isReadByMe'] == true;
    final currentUserId = UserService.currentId;
    out['diwaniyaId'] = out['diwaniya_id'] ?? out['diwaniyaId'];
    out['senderUserId'] = out['sender_user_id'] ?? out['senderUserId'];
    out['senderName'] = out['sender_name'] ?? out['senderName'];
    out['messageType'] = out['message_type'] ?? out['messageType'];
    out['createdAt'] = out['created_at'] ?? out['createdAt'];
    out['editedAt'] = out['edited_at'] ?? out['editedAt'];
    out['deletedAt'] = out['deleted_at'] ?? out['deletedAt'];
    out['replyToMessageId'] =
        out['reply_to_message_id'] ?? out['replyToMessageId'];
    out['replyToSenderName'] =
        out['reply_to_sender_name'] ?? out['replyToSenderName'];
    out['replyToPreview'] = out['reply_to_preview'] ?? out['replyToPreview'];
    out['isPinned'] = out['is_pinned'] ?? out['isPinned'];
    out['attachmentPath'] = attachmentUrl != null
        ? _resolveUrl(attachmentUrl)
        : out['attachmentPath'];
    out['attachmentMimeType'] =
        out['attachment_mime_type'] ?? out['attachmentMimeType'];
    out['attachmentDurationMs'] =
        out['attachment_duration_ms'] ?? out['attachmentDurationMs'];
    out['attachmentSizeBytes'] =
        out['attachment_size_bytes'] ?? out['attachmentSizeBytes'];
    final rawReadBy = out['read_by'] ?? out['readBy'] ?? out['readers'];
    final rawReadCount = out['read_count'] ?? out['readCount'];
    final rawMemberCount = out['member_count'] ?? out['memberCount'];
    final readCount = rawReadCount is num ? rawReadCount.toInt() : 0;
    final memberCount = rawMemberCount is num ? rawMemberCount.toInt() : 1;
    out['readCount'] = readCount <= 0 ? 1 : readCount;
    out['memberCount'] = memberCount <= 0 ? 1 : memberCount;
    out['isMine'] = out['is_mine'] ?? out['isMine'] ?? false;
    out['isReadByMe'] = isReadByMe;
    if (rawReadBy is List) {
      out['readBy'] = rawReadBy;
    } else if (readCount > 0) {
      out['readBy'] =
          List<String>.generate(readCount, (index) => 'read_$index');
    } else {
      out['readBy'] = isReadByMe && currentUserId.isNotEmpty
          ? <String>[currentUserId]
          : const <String>[];
    }
    return ChatMessage.fromJson(out);
  }

  static List<String> readersFor(ChatMessage message, {String? diwaniyaId}) {
    final did = diwaniyaId ?? message.diwaniyaId;
    final raw = message.readBy
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    if (raw.isEmpty) return const <String>[];

    final members = diwaniyaMembers[did] ?? const <DiwaniyaMember>[];
    final names = <String>[];

    for (final item in raw) {
      if (item == UserService.currentId && UserService.currentName.isNotEmpty) {
        names.add(UserService.currentName);
        continue;
      }

      final byExactName = members.where((m) => m.name == item).toList();
      if (byExactName.isNotEmpty) {
        names.add(byExactName.first.name);
        continue;
      }

      if (!item.startsWith('usr_') && !item.startsWith('mem_')) {
        names.add(item);
      }
    }

    final unique = <String>[];
    for (final name in names) {
      if (!unique.contains(name)) unique.add(name);
    }
    return unique;
  }

  static List<DiwaniyaMember> mentionCandidates(String query,
      {String? diwaniyaId, int limit = 5}) {
    final did = diwaniyaId ?? currentDiwaniyaId;
    final normalized = query.trim().toLowerCase();
    final parts = normalized.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);

    final members = (diwaniyaMembers[did] ?? const <DiwaniyaMember>[])
        .where((m) => m.name != UserService.currentName)
        .where((m) {
      if (normalized.isEmpty) return true;
      final name = m.name.toLowerCase();
      return parts.every(name.contains);
    }).toList();

    members.sort((a, b) {
      final aIsManager = a.role == 'manager';
      final bIsManager = b.role == 'manager';
      if (aIsManager != bIsManager) return aIsManager ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return members.take(limit).toList();
  }

  static Future<void> ensureHydrated([String? diwaniyaId]) async {
    final did = diwaniyaId ?? currentDiwaniyaId;
    if (did.isEmpty) return;
    if ((messages[did] ?? const <ChatMessage>[]).isNotEmpty) return;
    await syncForDiwaniya(did, limit: initialMessagesLimit);
  }

  static Future<void> syncForDiwaniya(String diwaniyaId,
      {bool bumpVersion = true,
      int limit = initialMessagesLimit,
      bool refreshUnread = true}) {
    final existing = _inFlightSyncs[diwaniyaId];
    if (existing != null) return existing;
    final future = _syncForDiwaniyaInternal(diwaniyaId,
        bumpVersion: bumpVersion, limit: limit, refreshUnread: refreshUnread);
    _inFlightSyncs[diwaniyaId] = future;
    future.whenComplete(() => _inFlightSyncs.remove(diwaniyaId));
    return future;
  }

  static Future<void> _syncForDiwaniyaInternal(String diwaniyaId,
      {required bool bumpVersion,
      required int limit,
      required bool refreshUnread}) async {
    final res = await ApiClient.get(_messagesEndpoint(diwaniyaId),
        query: {'limit': '$limit'});
    final fetched = ((res['messages'] as List?) ?? const [])
        .map((e) => _messageFromApi(Map<String, dynamic>.from(e as Map)))
        .toList();
    fetched.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    messages[diwaniyaId] = fetched;
    if (refreshUnread) {
      await syncUnreadSummary(bumpVersion: false);
    }
    if (bumpVersion) dataVersion.value++;
  }

  static Future<void> syncUnreadSummary({bool bumpVersion = true}) async {
    final res = await ApiClient.get(_unreadSummaryEndpoint());
    _unreadByDiwaniya.clear();
    for (final item in ((res['items'] as List?) ?? const [])) {
      final map = Map<String, dynamic>.from(item as Map);
      final did = (map['diwaniya_id'] ?? map['diwaniyaId']) as String?;
      if (did == null || did.isEmpty) continue;
      _unreadByDiwaniya[did] =
          ((map['unread_count'] ?? map['unreadCount']) as num?)?.toInt() ?? 0;
    }
    if (bumpVersion) dataVersion.value++;
  }

  static Future<ChatMessage?> sendText(String text,
      {String? diwaniyaId, ReplyInfo? reply}) async {
    final did = diwaniyaId ?? currentDiwaniyaId;
    final trimmed = text.trim();
    if (trimmed.isEmpty || did.isEmpty) return null;
    final res = await ApiClient.post(_messagesEndpoint(did), body: {
      'message_type': 'text',
      'text': trimmed,
      'reply_to_message_id': reply?.messageId,
    });
    final message = _messageFromApi(Map<String, dynamic>.from(res as Map));
    final list = messages.putIfAbsent(did, () => <ChatMessage>[]);
    list.removeWhere((m) => m.id == message.id);
    list.add(message);
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final senderName = message.senderName;
    final preview =
        trimmed.length > 40 ? '${trimmed.substring(0, 40)}...' : trimmed;
    addGlobalActivity(did, 'chat_message', senderName, '$senderName: $preview',
        Icons.chat_bubble_rounded, const Color(0xFF60A5FA));
    addGlobalNotification(did, '$senderName: $preview', 'chat',
        Icons.chat_bubble_rounded, const Color(0xFF60A5FA));
    await syncUnreadSummary(bumpVersion: false);
    dataVersion.value++;
    return message;
  }

  static Future<ChatMessage> sendImage(String localPath,
      {String? diwaniyaId, ReplyInfo? reply}) async {
    final did = diwaniyaId ?? currentDiwaniyaId;
    final res = await ApiClient.postMultipart(
      _mediaEndpoint(did),
      file: File(localPath),
      fields: {
        'message_type': 'image',
        'reply_to_message_id': reply?.messageId ?? '',
      },
    );
    final message = _messageFromApi(Map<String, dynamic>.from(res as Map));
    final list = messages.putIfAbsent(did, () => <ChatMessage>[]);
    list.removeWhere((m) => m.id == message.id);
    list.add(message);
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final senderName = message.senderName;
    addGlobalActivity(did, 'chat_image', senderName, '$senderName أرسل صورة',
        Icons.image_rounded, const Color(0xFF60A5FA));
    addGlobalNotification(did, '$senderName أرسل صورة', 'chat',
        Icons.image_rounded, const Color(0xFF60A5FA));
    await syncUnreadSummary(bumpVersion: false);
    dataVersion.value++;
    return message;
  }

  static Future<ChatMessage> sendFile(
    String localPath, {
    required String fileName,
    int? fileSizeBytes,
    String? diwaniyaId,
    ReplyInfo? reply,
  }) async {
    final did = diwaniyaId ?? currentDiwaniyaId;
    final res = await ApiClient.postMultipart(
      _mediaEndpoint(did),
      file: File(localPath),
      fields: {
        'message_type': 'file',
        'text': fileName,
        'reply_to_message_id': reply?.messageId ?? '',
        'attachment_size_bytes': fileSizeBytes?.toString() ?? '',
      },
    );
    final message = _messageFromApi(Map<String, dynamic>.from(res as Map));
    final list = messages.putIfAbsent(did, () => <ChatMessage>[]);
    list.removeWhere((m) => m.id == message.id);
    list.add(message);
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final senderName = message.senderName;
    addGlobalActivity(
      did,
      'chat_file',
      senderName,
      '$senderName أرسل ملف',
      Icons.insert_drive_file_rounded,
      const Color(0xFF60A5FA),
    );
    addGlobalNotification(
      did,
      '$senderName أرسل ملف',
      'chat',
      Icons.insert_drive_file_rounded,
      const Color(0xFF60A5FA),
    );
    await syncUnreadSummary(bumpVersion: false);
    dataVersion.value++;
    return message;
  }

  static Future<ChatMessage> sendVoice(String localPath,
      {int? durationMs, String? diwaniyaId, ReplyInfo? reply}) async {
    final did = diwaniyaId ?? currentDiwaniyaId;
    final res = await ApiClient.postMultipart(
      _mediaEndpoint(did),
      file: File(localPath),
      fields: {
        'message_type': 'voice',
        'reply_to_message_id': reply?.messageId ?? '',
        'attachment_duration_ms': durationMs?.toString() ?? '',
      },
    );
    final message = _messageFromApi(Map<String, dynamic>.from(res as Map));
    final list = messages.putIfAbsent(did, () => <ChatMessage>[]);
    list.removeWhere((m) => m.id == message.id);
    list.add(message);
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final senderName = message.senderName;
    addGlobalActivity(
        did,
        'chat_voice',
        senderName,
        '$senderName أرسل رسالة صوتية',
        Icons.mic_rounded,
        const Color(0xFF60A5FA));
    addGlobalNotification(did, '$senderName أرسل رسالة صوتية', 'chat',
        Icons.mic_rounded, const Color(0xFF60A5FA));
    await syncUnreadSummary(bumpVersion: false);
    dataVersion.value++;
    return message;
  }

  static Future<void> mirrorImageToChatAlbum(
    String localPath, {
    String? diwaniyaId,
    String? caption,
  }) async {
    final did = diwaniyaId ?? currentDiwaniyaId;
    if (did.isEmpty) return;

    var chatAlbum = AlbumService.defaultChatFolder(did);
    if (chatAlbum == null) {
      await AlbumService.syncForDiwaniya(did, bumpVersion: false);
      chatAlbum = AlbumService.defaultChatFolder(did);
    }
    chatAlbum ??=
        await AlbumService.createAlbum(chatAlbumName, diwaniyaId: did);

    await AlbumService.uploadPhoto(
      File(localPath),
      diwaniyaId: did,
      caption: caption,
      albumId: chatAlbum.id,
    );
  }

  static ChatMessage? lastMessage([String? diwaniyaId]) {
    final list = activeMessages(diwaniyaId);
    return list.isEmpty ? null : list.last;
  }

  static int unreadCount([String? diwaniyaId]) {
    final did = diwaniyaId ?? currentDiwaniyaId;
    return _unreadByDiwaniya[did] ?? 0;
  }

  static int totalUnreadAcrossDiwaniyas() {
    var total = 0;
    for (final diwaniya in allDiwaniyas) {
      total += unreadCount(diwaniya.id);
    }
    return total;
  }

  static Future<void> markAllRead([String? diwaniyaId]) async {
    final userId = UserService.currentId;
    final did = diwaniyaId ?? currentDiwaniyaId;
    if (userId.isEmpty || did.isEmpty) return;
    final latest = lastMessage(did);
    if (latest == null) {
      _unreadByDiwaniya[did] = 0;
      dataVersion.value++;
      return;
    }
    await ApiClient.post(_readEndpoint(did),
        body: {'last_read_message_id': latest.id});
    final existing = current(did);
    var changed = false;
    for (var i = 0; i < existing.length; i++) {
      final message = existing[i];
      // Do not mutate read state for messages sent by the current user.
      // Backend read_count already includes the sender exactly once. Adding the
      // current user locally here would make an unread-by-others message look
      // fully read after simply reopening the screen.
      if (message.senderUserId == userId) continue;
      if (!message.isReadByMe) {
        final nextReadCount = (message.readCount + 1)
            .clamp(1, message.memberCount <= 0 ? 1 : message.memberCount)
            .toInt();
        existing[i] = message.copyWith(
          isReadByMe: true,
          readCount: nextReadCount,
          readBy: message.readBy.contains(userId)
              ? message.readBy
              : <String>[...message.readBy, userId],
        );
        changed = true;
      }
    }
    _unreadByDiwaniya[did] = 0;
    if (changed) dataVersion.value++;
  }
}

class ApiClientBase {
  static String get baseUrl => ApiConfig.baseUrl;
}
