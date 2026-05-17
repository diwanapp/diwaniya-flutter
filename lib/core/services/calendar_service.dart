import '../api/api_client.dart';
import '../models/mock_data.dart';

final Map<String, List<DiwaniyaCalendarEvent>> diwaniyaCalendarEvents =
    <String, List<DiwaniyaCalendarEvent>>{};

final Map<String, List<DiwaniyaCalendarDayAttendance>> diwaniyaCalendarDayAttendance =
    <String, List<DiwaniyaCalendarDayAttendance>>{};

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


class CalendarDayAttendee {
  final String userId;
  final String userName;
  final String source;

  const CalendarDayAttendee({
    required this.userId,
    required this.userName,
    required this.source,
  });

  factory CalendarDayAttendee.fromBackend(Map<String, dynamic> raw) {
    return CalendarDayAttendee(
      userId: (raw['user_id'] ?? raw['userId'] ?? '').toString(),
      userName: (raw['user_name'] ?? raw['userName'] ?? '').toString(),
      source: (raw['source'] ?? 'day').toString(),
    );
  }
}

class DiwaniyaCalendarDayAttendance {
  final DateTime date;
  final int dayAttendeesCount;
  final int eventAttendeesCount;
  final int totalUniqueAttendeesCount;
  final bool isCurrentUserAttending;
  final List<CalendarDayAttendee> attendees;

  const DiwaniyaCalendarDayAttendance({
    required this.date,
    required this.dayAttendeesCount,
    required this.eventAttendeesCount,
    required this.totalUniqueAttendeesCount,
    required this.isCurrentUserAttending,
    required this.attendees,
  });

  static DateTime _dateOnly(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  factory DiwaniyaCalendarDayAttendance.fromBackend(Map<String, dynamic> raw) {
    final parsed = DateTime.tryParse((raw['date'] ?? '').toString()) ?? DateTime.now();
    final attendeesRaw = raw['attendees'];
    return DiwaniyaCalendarDayAttendance(
      date: _dateOnly(parsed),
      dayAttendeesCount:
          ((raw['day_attendees_count'] ?? raw['dayAttendeesCount']) as num?)?.toInt() ?? 0,
      eventAttendeesCount:
          ((raw['event_attendees_count'] ?? raw['eventAttendeesCount']) as num?)?.toInt() ?? 0,
      totalUniqueAttendeesCount:
          ((raw['total_unique_attendees_count'] ?? raw['totalUniqueAttendeesCount']) as num?)?.toInt() ?? 0,
      isCurrentUserAttending:
          (raw['is_current_user_attending'] ?? raw['isCurrentUserAttending']) == true,
      attendees: attendeesRaw is List
          ? attendeesRaw
              .whereType<Map>()
              .map((e) => CalendarDayAttendee.fromBackend(Map<String, dynamic>.from(e)))
              .toList()
          : const <CalendarDayAttendee>[],
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

  static String _dateParam(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  static String _dayAttendancePath(
    String diwaniyaId, {
    required DateTime from,
    required DateTime to,
  }) {
    final did = Uri.encodeComponent(diwaniyaId.trim());
    return '/diwaniyas/$did/calendar/day-attendance?from=${_dateParam(from)}&to=${_dateParam(to)}';
  }

  static String _dayAttendanceDatePath(String diwaniyaId, DateTime day) {
    final did = Uri.encodeComponent(diwaniyaId.trim());
    return '/diwaniyas/$did/calendar/day-attendance/${_dateParam(day)}';
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

    final results = await Future.wait<dynamic>([
      ApiClient.get(_eventsPath(did, from: from, to: to, limit: 50)),
      ApiClient.get(_dayAttendancePath(did, from: from, to: to)),
    ]);

    final eventsResponse = Map<String, dynamic>.from(results[0] as Map);
    final daysResponse = Map<String, dynamic>.from(results[1] as Map);

    final eventsRaw = (eventsResponse['events'] as List? ?? const <dynamic>[]);
    final daysRaw = (daysResponse['days'] as List? ?? const <dynamic>[]);

    final events = eventsRaw
        .whereType<Map>()
        .map((e) => DiwaniyaCalendarEvent.fromBackend(Map<String, dynamic>.from(e)))
        .where((e) => !e.isCancelled)
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    final days = daysRaw
        .whereType<Map>()
        .map((e) => DiwaniyaCalendarDayAttendance.fromBackend(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    diwaniyaCalendarEvents[did] = events;
    diwaniyaCalendarDayAttendance[did] = days;
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

  static Future<void> setDayAttendance(
    String diwaniyaId,
    DateTime day, {
    required bool attending,
  }) async {
    final path = _dayAttendanceDatePath(diwaniyaId, day);
    if (attending) {
      await ApiClient.post(path);
    } else {
      await ApiClient.delete(path);
    }
    await syncForDiwaniya(diwaniyaId);
  }
}
