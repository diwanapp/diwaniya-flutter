class AlbumFolder {
  final String id;
  final String diwaniyaId;
  final String name;
  final DateTime createdAt;
  final bool isDefault;

  const AlbumFolder({
    required this.id,
    required this.diwaniyaId,
    required this.name,
    required this.createdAt,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'diwaniyaId': diwaniyaId,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'isDefault': isDefault,
      };

  factory AlbumFolder.fromJson(Map<String, dynamic> json) => AlbumFolder(
        id: json['id'] as String,
        diwaniyaId: (json['diwaniyaId'] ?? json['diwaniya_id']) as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(
          (json['createdAt'] ?? json['created_at']) as String,
        ),
        isDefault: (json['isDefault'] ?? json['is_default']) == true,
      );
}

class AlbumPhoto {
  final String id;
  final String diwaniyaId;
  final String albumId;
  final String capturedByUserId;
  final String capturedByName;
  final DateTime capturedAt;
  final String fileUrl;
  final String? caption;
  final bool isDeleted;

  const AlbumPhoto._internal({
    required this.id,
    required this.diwaniyaId,
    required this.albumId,
    required this.capturedByUserId,
    required this.capturedByName,
    required this.capturedAt,
    required this.fileUrl,
    this.caption,
    this.isDeleted = false,
  });

  factory AlbumPhoto({
    required String id,
    required String diwaniyaId,
    String albumId = 'camera',
    required String capturedByUserId,
    required String capturedByName,
    required DateTime capturedAt,
    String? fileUrl,
    String? localPath,
    String? caption,
    bool isDeleted = false,
  }) {
    return AlbumPhoto._internal(
      id: id,
      diwaniyaId: diwaniyaId,
      albumId: albumId,
      capturedByUserId: capturedByUserId,
      capturedByName: capturedByName,
      capturedAt: capturedAt,
      fileUrl: fileUrl ?? localPath ?? '',
      caption: caption,
      isDeleted: isDeleted,
    );
  }

  String get localPath => fileUrl;

  AlbumPhoto copyWith({String? caption, String? albumId, bool? isDeleted, String? fileUrl}) => AlbumPhoto(
        id: id,
        diwaniyaId: diwaniyaId,
        albumId: albumId ?? this.albumId,
        capturedByUserId: capturedByUserId,
        capturedByName: capturedByName,
        capturedAt: capturedAt,
        fileUrl: fileUrl ?? this.fileUrl,
        caption: caption ?? this.caption,
        isDeleted: isDeleted ?? this.isDeleted,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'diwaniyaId': diwaniyaId,
        'albumId': albumId,
        'capturedByUserId': capturedByUserId,
        'capturedByName': capturedByName,
        'capturedAt': capturedAt.toIso8601String(),
        'fileUrl': fileUrl,
        'caption': caption,
        'isDeleted': isDeleted,
      };

  factory AlbumPhoto.fromJson(Map<String, dynamic> json) => AlbumPhoto(
        id: json['id'] as String,
        diwaniyaId: (json['diwaniyaId'] ?? json['diwaniya_id']) as String,
        albumId: (json['albumId'] ?? json['album_id'] ?? 'camera') as String,
        capturedByUserId: (json['capturedByUserId'] ?? json['captured_by_user_id']) as String,
        capturedByName: (json['capturedByName'] ?? json['captured_by_name']) as String,
        capturedAt: DateTime.parse((json['capturedAt'] ?? json['captured_at']) as String),
        fileUrl: (json['fileUrl'] ?? json['file_url'] ?? json['localPath']) as String?,
        localPath: (json['localPath']) as String?,
        caption: json['caption'] as String?,
        isDeleted: (json['isDeleted'] ?? json['is_deleted']) == true,
      );
}
