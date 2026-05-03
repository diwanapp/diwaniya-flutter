class ChatMessage {
  final String id;
  final String diwaniyaId;
  final String senderUserId;
  final String senderName;
  final String messageType;
  final String? text;
  final DateTime createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final String? replyToMessageId;
  final String? replyToSenderName;
  final String? replyToPreview;
  final bool isPinned;
  final List<String> readBy;
  final int readCount;
  final int memberCount;
  final bool isMine;
  final bool isReadByMe;
  final String? attachmentPath;
  final String? attachmentMimeType;
  final int? attachmentDurationMs;
  final int? attachmentSizeBytes;

  const ChatMessage({
    required this.id,
    required this.diwaniyaId,
    required this.senderUserId,
    required this.senderName,
    required this.messageType,
    required this.createdAt,
    this.text,
    this.editedAt,
    this.deletedAt,
    this.replyToMessageId,
    this.replyToSenderName,
    this.replyToPreview,
    this.isPinned = false,
    this.readBy = const [],
    this.readCount = 1,
    this.memberCount = 1,
    this.isMine = false,
    this.isReadByMe = false,
    this.attachmentPath,
    this.attachmentMimeType,
    this.attachmentDurationMs,
    this.attachmentSizeBytes,
  });

  bool get isDeleted => deletedAt != null;
  bool get isReply => replyToMessageId != null;

  ChatMessage copyWith({
    String? text,
    DateTime? editedAt,
    DateTime? deletedAt,
    String? replyToMessageId,
    String? replyToSenderName,
    String? replyToPreview,
    List<String>? readBy,
    int? readCount,
    int? memberCount,
    bool? isMine,
    bool? isReadByMe,
    bool? isPinned,
    String? attachmentPath,
    String? attachmentMimeType,
    int? attachmentDurationMs,
    int? attachmentSizeBytes,
  }) {
    return ChatMessage(
      id: id,
      diwaniyaId: diwaniyaId,
      senderUserId: senderUserId,
      senderName: senderName,
      messageType: messageType,
      text: text ?? this.text,
      createdAt: createdAt,
      editedAt: editedAt ?? this.editedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToSenderName: replyToSenderName ?? this.replyToSenderName,
      replyToPreview: replyToPreview ?? this.replyToPreview,
      isPinned: isPinned ?? this.isPinned,
      readBy: readBy ?? this.readBy,
      readCount: readCount ?? this.readCount,
      memberCount: memberCount ?? this.memberCount,
      isMine: isMine ?? this.isMine,
      isReadByMe: isReadByMe ?? this.isReadByMe,
      attachmentPath: attachmentPath ?? this.attachmentPath,
      attachmentMimeType: attachmentMimeType ?? this.attachmentMimeType,
      attachmentDurationMs: attachmentDurationMs ?? this.attachmentDurationMs,
      attachmentSizeBytes: attachmentSizeBytes ?? this.attachmentSizeBytes,
    );
  }

  static List<String> _parseReadBy(dynamic value) {
    if (value is! Iterable) return const <String>[];

    final out = <String>[];
    for (final item in value) {
      String parsed = '';
      if (item is String) {
        parsed = item;
      } else if (item is Map) {
        parsed = (item['display_name'] ??
                item['name'] ??
                item['user_id'] ??
                item['id'] ??
                '')
            .toString();
      } else {
        parsed = item.toString();
      }

      parsed = parsed.trim();
      if (parsed.isNotEmpty && !out.contains(parsed)) {
        out.add(parsed);
      }
    }
    return out;
  }

  static int _parseInt(dynamic value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'diwaniyaId': diwaniyaId,
        'senderUserId': senderUserId,
        'senderName': senderName,
        'messageType': messageType,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'editedAt': editedAt?.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
        'replyToMessageId': replyToMessageId,
        'replyToSenderName': replyToSenderName,
        'replyToPreview': replyToPreview,
        'isPinned': isPinned,
        'readBy': readBy,
        'readCount': readCount,
        'memberCount': memberCount,
        'isMine': isMine,
        'isReadByMe': isReadByMe,
        'attachmentPath': attachmentPath,
        'attachmentMimeType': attachmentMimeType,
        'attachmentDurationMs': attachmentDurationMs,
        'attachmentSizeBytes': attachmentSizeBytes,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final parsedReadBy = _parseReadBy(
      json['readBy'] ?? json['read_by'] ?? json['readers'],
    );
    final parsedMemberCount = _parseInt(
      json['memberCount'] ?? json['member_count'],
      fallback: 1,
    );
    final parsedReadCount = _parseInt(
      json['readCount'] ?? json['read_count'],
      fallback: parsedReadBy.isNotEmpty ? parsedReadBy.length : 1,
    );
    final safeMemberCount = parsedMemberCount <= 0 ? 1 : parsedMemberCount;
    final safeReadCount = parsedReadCount.clamp(1, safeMemberCount).toInt();

    return ChatMessage(
      id: json['id'] as String,
      diwaniyaId: (json['diwaniyaId'] ?? json['diwaniya_id']) as String,
      senderUserId: (json['senderUserId'] ?? json['sender_user_id']) as String,
      senderName: (json['senderName'] ?? json['sender_name']) as String,
      messageType: (json['messageType'] ?? json['message_type']) as String,
      text: json['text'] as String?,
      createdAt: DateTime.parse(
        (json['createdAt'] ?? json['created_at']) as String,
      ),
      editedAt: (json['editedAt'] ?? json['edited_at']) != null
          ? DateTime.parse((json['editedAt'] ?? json['edited_at']) as String)
          : null,
      deletedAt: (json['deletedAt'] ?? json['deleted_at']) != null
          ? DateTime.parse((json['deletedAt'] ?? json['deleted_at']) as String)
          : null,
      replyToMessageId:
          (json['replyToMessageId'] ?? json['reply_to_message_id']) as String?,
      replyToSenderName: (json['replyToSenderName'] ??
          json['reply_to_sender_name']) as String?,
      replyToPreview:
          (json['replyToPreview'] ?? json['reply_to_preview']) as String?,
      isPinned: json['isPinned'] == true || json['is_pinned'] == true,
      readBy: parsedReadBy,
      readCount: safeReadCount,
      memberCount: safeMemberCount,
      isMine: json['isMine'] == true || json['is_mine'] == true,
      isReadByMe: json['isReadByMe'] == true || json['is_read_by_me'] == true,
      attachmentPath: (json['attachmentPath'] ??
          json['attachment_path'] ??
          json['attachmentUrl'] ??
          json['attachment_url']) as String?,
      attachmentMimeType: (json['attachmentMimeType'] ??
          json['attachment_mime_type']) as String?,
      attachmentDurationMs: _parseInt(
                json['attachmentDurationMs'] ?? json['attachment_duration_ms'],
                fallback: 0,
              ) ==
              0
          ? null
          : _parseInt(
              json['attachmentDurationMs'] ?? json['attachment_duration_ms']),
      attachmentSizeBytes: _parseInt(
                json['attachmentSizeBytes'] ?? json['attachment_size_bytes'],
                fallback: 0,
              ) ==
              0
          ? null
          : _parseInt(
              json['attachmentSizeBytes'] ?? json['attachment_size_bytes']),
    );
  }
}

class ReplyInfo {
  final String messageId;
  final String senderName;
  final String preview;
  const ReplyInfo(
      {required this.messageId,
      required this.senderName,
      required this.preview});
}
