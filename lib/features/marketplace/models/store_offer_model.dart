class StoreOffer {
  final String id;
  final String title;
  final String? description;
  final String? badgeText;
  final DateTime? startAt;
  final DateTime? endAt;

  const StoreOffer({
    required this.id,
    required this.title,
    this.description,
    this.badgeText,
    this.startAt,
    this.endAt,
  });

  bool get isActive {
    final now = DateTime.now();
    if (startAt != null && now.isBefore(startAt!)) return false;
    if (endAt != null && now.isAfter(endAt!)) return false;
    return true;
  }
}
