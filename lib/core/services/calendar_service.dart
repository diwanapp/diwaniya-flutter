import '../api/api_client.dart';
import '../models/mock_data.dart';

final Map<String, List<DiwaniyaCalendarEvent>> diwaniyaCalendarEvents =
    <String, List<DiwaniyaCalendarEvent>>{};

class DiwaniyaCalendarEvent {
  final String id;
  final String diwaniyaId;
  final String title;
  final String? description;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? location;
  final String createdByUserId;
  final String createdByName;
  final String sourceType;
  final bool isCancelled;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int attendeesCount;
  final bool isAttending;

  const DiwaniyaCalendarEvent({
    required this.id,
    required this.diwaniyaId,
    required this.title,
    required this.description,
    required this.startsAt,
    required this.endsAt,
    required this.location,
    required this.createdByUserId,
    required this.createdByName,
    required this.sourceType,
    required this.isCancelled,
    required this.createdAt,
    required this.updatedAt,
    required this.attendeesCount,
    required this.isAttending,
  });

  static String _stringValue(Map<String, dynamic> raw, String snake, String camel) {
    return (raw[snake] ?? raw[camel] ?? '').toString().trim();
  }

  static DateTime? _dateValue(Map<String, dynamic> raw, String snake, String camel) {
    final value = raw[snake] ?? raw[camel];
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  factory DiwaniyaCalendarEvent.fromBackend(Map<String, dynamic> raw) {
    return DiwaniyaCalendarEvent(
      id: _stringValue(raw, 'id', 'id'),
      diwaniyaId: _stringValue(raw, 'diwaniya_id', 'diwaniyaId'),
      title: _stringValue(raw, 'title', 'title'),
      description: (raw['description'] ?? raw['description'])?.toString(),
      startsAt: _dateValue(raw, 'starts_at', 'startsAt') ?? DateTime.now(),
      endsAt: _dateValue(raw, 'ends_at', 'endsAt'),
      location: (raw['location'] ?? raw['location'])?.toString(),
      createdByUserId: _stringValue(raw, 'created_by_user_id', 'createdByUserId'),
      createdByName: _stringValue(raw, 'created_by_name', 'createdByName'),
      sourceType: _stringValue(raw, 'source_type', 'sourceType').isEmpty
          ? 'member'
          : _stringValue(raw, 'source_type', 'sourceType'),
      isCancelled: (raw['is_cancelled'] ?? raw['isCancelled']) == true,
      createdAt: _dateValue(raw, 'created_at', 'createdAt') ?? DateTime.now(),
      updatedAt: _dateValue(raw, 'updated_at', 'updatedAt'),
      attendeesCount:
          ((raw['attendees_count'] ?? raw['attendeesCount']) as num?)?.toInt() ?? 0,
      isAttending: (raw['is_attending'] ?? raw['isAttending']) == true,
    );
  }
}

class CalendarService {
  CalendarService._();

  static String _eventsPath(
    String diwaniyaId, {
    DateTime? from,
    DateTime? to,
    int limit = 50,
  }) {
    final did = Uri.encodeComponent(diwaniyaId.trim());
    final parts = <String>['limit=$limit'];
    if (from != null) {
      parts.add('from=${Uri.encodeQueryComponent(from.toUtc().toIso8601String())}');
    }
    if (to != null) {
      parts.add('to=${Uri.encodeQueryComponent(to.toUtc().toIso8601String())}');
    }
    return '/diwaniyas/$did/calendar/events?${parts.join('&')}';
  }

  static String _eventPath(String diwaniyaId, String eventId) {
    final did = Uri.encodeComponent(diwaniyaId.trim());
    final eid = Uri.encodeComponent(eventId.trim());
    return '/diwaniyas/$did/calendar/events/$eid';
  }

  static String _attendPath(String diwaniyaId, String eventId) {
    final did = Uri.encodeComponent(diwaniyaId.trim());
    final eid = Uri.encodeComponent(eventId.trim());
    return '/diwaniyas/$did/calendar/events/$eid/attend';
  }

  static String _cancelAttendancePath(String diwaniyaId, String eventId) {
    final did = Uri.encodeComponent(diwaniyaId.trim());
    final eid = Uri.encodeComponent(eventId.trim());
    return '/diwaniyas/$did/calendar/events/$eid/cancel-attendance';
  }

  static Future<void> syncForDiwaniya(
    String diwaniyaId, {
    bool bumpVersion = true,
  }) async {
    final did = diwaniyaId.trim();
    if (did.isEmpty) return;

    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    final to = from.add(const Duration(days: 45));

    final raw = await ApiClient.get(_eventsPath(did, from: from, to: to, limit: 50));
    final eventsRaw = (raw['events'] as List? ?? const <dynamic>[]);

    final events = eventsRaw
        .whereType<Map>()
        .map((e) => DiwaniyaCalendarEvent.fromBackend(Map<String, dynamic>.from(e)))
        .where((e) => !e.isCancelled)
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    diwaniyaCalendarEvents[did] = events;
    if (bumpVersion) dataVersion.value++;
  }

  static Future<DiwaniyaCalendarEvent> createEvent(
    String diwaniyaId, {
    required String title,
    String? description,
    required DateTime startsAt,
    DateTime? endsAt,
    String? location,
  }) async {
    final raw = await ApiClient.post(
      _eventsPath(diwaniyaId, limit: 50).split('?').first,
      body: {
        'title': title.trim(),
        'description': description?.trim(),
        'starts_at': startsAt.toUtc().toIso8601String(),
        'ends_at': endsAt?.toUtc().toIso8601String(),
        'location': location?.trim(),
      },
    );
    final created = DiwaniyaCalendarEvent.fromBackend(Map<String, dynamic>.from(raw));
    await syncForDiwaniya(diwaniyaId);
    return created;
  }

  static Future<DiwaniyaCalendarEvent> updateEvent(
    String diwaniyaId,
    String eventId, {
    required String title,
    String? description,
    required DateTime startsAt,
    DateTime? endsAt,
    String? location,
  }) async {
    final raw = await ApiClient.patch(
      _eventPath(diwaniyaId, eventId),
      body: {
        'title': title.trim(),
        'description': description?.trim(),
        'starts_at': startsAt.toUtc().toIso8601String(),
        'ends_at': endsAt?.toUtc().toIso8601String(),
        'location': location?.trim(),
      },
    );
    final updated = DiwaniyaCalendarEvent.fromBackend(Map<String, dynamic>.from(raw));
    await syncForDiwaniya(diwaniyaId);
    return updated;
  }

  static Future<DiwaniyaCalendarEvent> setAttendance(
    String diwaniyaId,
    String eventId, {
    required bool attending,
  }) async {
    final raw = await ApiClient.post(
      attending ? _attendPath(diwaniyaId, eventId) : _cancelAttendancePath(diwaniyaId, eventId),
    );
    final updated = DiwaniyaCalendarEvent.fromBackend(Map<String, dynamic>.from(raw));
    await syncForDiwaniya(diwaniyaId);
    return updated;
  }

  static Future<void> deleteEvent(String diwaniyaId, String eventId) async {
    await ApiClient.delete(_eventPath(diwaniyaId, eventId));
    await syncForDiwaniya(diwaniyaId);
  }
}
