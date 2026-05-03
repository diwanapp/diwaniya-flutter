/// Local mirror of the backend `MyJoinRequestOut` shape returned by
/// `GET /me/join-requests`. Pending and resolved (approved/rejected)
/// requests both live in this model — `status` distinguishes them.
///
/// Kept deliberately separate from `DiwaniyaInfo`: pending users are
/// not yet members and must not pollute `AuthService.allDiwaniyas`,
/// which the home screen treats as the approved-membership list.
class JoinRequest {
  final String id;
  final String diwaniyaId;
  final String diwaniyaName;
  final String diwaniyaCity;
  /// 'pending' | 'approved' | 'rejected'
  final String status;
  final DateTime requestedAt;
  final DateTime? resolvedAt;

  const JoinRequest({
    required this.id,
    required this.diwaniyaId,
    required this.diwaniyaName,
    required this.diwaniyaCity,
    required this.status,
    required this.requestedAt,
    this.resolvedAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  Map<String, dynamic> toJson() => {
        'id': id,
        'diwaniya_id': diwaniyaId,
        'diwaniya_name': diwaniyaName,
        'diwaniya_city': diwaniyaCity,
        'status': status,
        'requested_at': requestedAt.toIso8601String(),
        'resolved_at': resolvedAt?.toIso8601String(),
      };

  factory JoinRequest.fromJson(Map<String, dynamic> j) => JoinRequest(
        id: (j['id'] as String?) ?? '',
        diwaniyaId: (j['diwaniya_id'] as String?) ?? '',
        diwaniyaName: (j['diwaniya_name'] as String?) ?? '',
        diwaniyaCity: (j['diwaniya_city'] as String?) ?? '',
        status: (j['status'] as String?) ?? 'pending',
        requestedAt: DateTime.tryParse((j['requested_at'] as String?) ?? '') ??
            DateTime.now(),
        resolvedAt: j['resolved_at'] != null
            ? DateTime.tryParse(j['resolved_at'] as String)
            : null,
      );
}
