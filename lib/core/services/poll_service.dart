import '../api/api_client.dart';
import '../models/mock_data.dart';
import '../repositories/app_repository.dart';

class PollService {
  PollService._();

  static String _pollsPath(
    String diwaniyaId, {
    int endedLimit = 30,
    int recentDays = 7,
  }) {
    final encodedDiwaniyaId = Uri.encodeComponent(diwaniyaId.trim());
    return '/diwaniyas/$encodedDiwaniyaId/polls?ended_limit=$endedLimit&recent_days=$recentDays';
  }

  static String _createPath(String diwaniyaId) {
    final encodedDiwaniyaId = Uri.encodeComponent(diwaniyaId.trim());
    return '/diwaniyas/$encodedDiwaniyaId/polls';
  }

  static String _votePath(String diwaniyaId, String pollId) {
    final encodedDiwaniyaId = Uri.encodeComponent(diwaniyaId.trim());
    final encodedPollId = Uri.encodeComponent(pollId.trim());
    return '/diwaniyas/$encodedDiwaniyaId/polls/$encodedPollId/vote';
  }

  static String _closePath(String diwaniyaId, String pollId) {
    final encodedDiwaniyaId = Uri.encodeComponent(diwaniyaId.trim());
    final encodedPollId = Uri.encodeComponent(pollId.trim());
    return '/diwaniyas/$encodedDiwaniyaId/polls/$encodedPollId/close';
  }

  static Future<void> syncForDiwaniya(
    String diwaniyaId, {
    int endedLimit = 30,
    int recentDays = 7,
    bool bumpVersion = true,
  }) async {
    if (diwaniyaId.trim().isEmpty) return;
    final raw = await ApiClient.get(
      _pollsPath(diwaniyaId, endedLimit: endedLimit, recentDays: recentDays),
    );
    final pollsRaw = (raw['polls'] as List? ?? const <dynamic>[]);
    diwaniyaPolls[diwaniyaId] = pollsRaw
        .whereType<Map>()
        .map((rawPoll) => _pollFromBackend(Map<String, dynamic>.from(rawPoll)))
        .toList();
    await AppRepository.savePolls();
    if (bumpVersion) dataVersion.value++;
  }

  static Future<DiwaniyaPoll> createPoll(
    String diwaniyaId, {
    required String question,
    required List<String> options,
  }) async {
    final raw = await ApiClient.post(
      _createPath(diwaniyaId),
      body: {
        'question': question.trim(),
        'options': options.map((o) => o.trim()).where((o) => o.isNotEmpty).toList(),
      },
    );
    final created = _pollFromBackend(Map<String, dynamic>.from(raw));
    await syncForDiwaniya(diwaniyaId);
    return created;
  }

  static Future<DiwaniyaPoll> vote(
    String diwaniyaId,
    String pollId,
    String option,
  ) async {
    final raw = await ApiClient.post(
      _votePath(diwaniyaId, pollId),
      body: {'option': option.trim()},
    );
    final updated = _pollFromBackend(Map<String, dynamic>.from(raw));
    await syncForDiwaniya(diwaniyaId);
    return updated;
  }

  static Future<DiwaniyaPoll> close(
    String diwaniyaId,
    String pollId,
  ) async {
    final raw = await ApiClient.post(_closePath(diwaniyaId, pollId));
    final updated = _pollFromBackend(Map<String, dynamic>.from(raw));
    await syncForDiwaniya(diwaniyaId);
    return updated;
  }

  static String _stringValue(Map<String, dynamic> raw, String snake, String camel) {
    return (raw[snake] ?? raw[camel] ?? '').toString().trim();
  }

  static DateTime? _dateValue(Map<String, dynamic> raw, String snake, String camel) {
    final value = raw[snake] ?? raw[camel];
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static DiwaniyaPoll _pollFromBackend(Map<String, dynamic> raw) {
    final options = List<String>.from(raw['options'] ?? const <String>[]);
    final rawVotes = (raw['votes_per_option'] ?? raw['votesPerOption']) as Map? ?? const {};
    final votesMap = <String, int>{for (final o in options) o: 0};
    rawVotes.forEach((key, value) {
      votesMap[key.toString()] = (value as num?)?.toInt() ?? 0;
    });

    return DiwaniyaPoll(
      id: _stringValue(raw, 'id', 'id'),
      question: _stringValue(raw, 'question', 'question'),
      diwaniyaId: _stringValue(raw, 'diwaniya_id', 'diwaniyaId'),
      createdBy: _stringValue(raw, 'created_by', 'createdBy'),
      options: options,
      votesPerOption: votesMap,
      votedMembers: Map<String, String>.from(raw['voted_members'] ?? raw['votedMembers'] ?? const {}),
      totalMembers: ((raw['total_members'] ?? raw['totalMembers']) as num?)?.toInt() ?? 0,
      isActive: (raw['is_active'] ?? raw['isActive']) == true,
      createdAt: _dateValue(raw, 'created_at', 'createdAt') ?? DateTime.now(),
      closedAt: _dateValue(raw, 'closed_at', 'closedAt'),
    );
  }
}
