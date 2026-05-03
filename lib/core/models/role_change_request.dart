enum RoleChangeStatus { pending, accepted, rejected, cancelled }

class RoleChangeRequest {
  final String id;
  final String diwaniyaId;
  final String requestedByUserId;
  final String requestedByName;
  final String targetUserId;
  final String targetName;
  final String fromRole;
  final String toRole;
  final RoleChangeStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const RoleChangeRequest({
    required this.id,
    required this.diwaniyaId,
    required this.requestedByUserId,
    required this.requestedByName,
    required this.targetUserId,
    required this.targetName,
    required this.fromRole,
    required this.toRole,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
  });

  bool get isPending => status == RoleChangeStatus.pending;

  RoleChangeRequest copyWith({RoleChangeStatus? status, DateTime? resolvedAt}) {
    return RoleChangeRequest(
      id: id,
      diwaniyaId: diwaniyaId,
      requestedByUserId: requestedByUserId,
      requestedByName: requestedByName,
      targetUserId: targetUserId,
      targetName: targetName,
      fromRole: fromRole,
      toRole: toRole,
      status: status ?? this.status,
      createdAt: createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'diwaniyaId': diwaniyaId,
        'requestedByUserId': requestedByUserId,
        'requestedByName': requestedByName,
        'targetUserId': targetUserId,
        'targetName': targetName,
        'fromRole': fromRole,
        'toRole': toRole,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'resolvedAt': resolvedAt?.toIso8601String(),
      };

  factory RoleChangeRequest.fromJson(Map<String, dynamic> j) => RoleChangeRequest(
        id: j['id'] as String,
        diwaniyaId: j['diwaniyaId'] as String,
        requestedByUserId: j['requestedByUserId'] as String,
        requestedByName: j['requestedByName'] as String,
        targetUserId: j['targetUserId'] as String,
        targetName: j['targetName'] as String,
        fromRole: j['fromRole'] as String,
        toRole: j['toRole'] as String,
        status: RoleChangeStatus.values.firstWhere(
          (e) => e.name == j['status'],
          orElse: () => RoleChangeStatus.pending,
        ),
        createdAt: DateTime.parse(j['createdAt'] as String),
        resolvedAt: j['resolvedAt'] != null ? DateTime.parse(j['resolvedAt'] as String) : null,
      );
}
