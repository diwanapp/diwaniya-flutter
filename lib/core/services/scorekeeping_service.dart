import '../api/api_client.dart';
import '../api/endpoints.dart';

class ScorekeepingRound {
  final String id;
  final String gameId;
  final int usPoints;
  final int themPoints;
  final DateTime createdAt;
  final String createdByUserId;

  const ScorekeepingRound({
    required this.id,
    required this.gameId,
    required this.usPoints,
    required this.themPoints,
    required this.createdAt,
    required this.createdByUserId,
  });

  factory ScorekeepingRound.fromJson(Map<String, dynamic> raw) {
    return ScorekeepingRound(
      id: (raw['id'] ?? '').toString(),
      gameId: (raw['game_id'] ?? raw['gameId'] ?? '').toString(),
      usPoints: ((raw['us_points'] ?? raw['usPoints'] ?? 0) as num).toInt(),
      themPoints:
          ((raw['them_points'] ?? raw['themPoints'] ?? 0) as num).toInt(),
      createdAt: DateTime.tryParse((raw['created_at'] ?? '').toString()) ??
          DateTime.now(),
      createdByUserId:
          (raw['created_by_user_id'] ?? raw['createdByUserId'] ?? '')
              .toString(),
    );
  }
}

class ScorekeepingGame {
  final String id;
  final String diwaniyaId;
  final int usScore;
  final int themScore;
  final String? usPlayer1Id;
  final String? usPlayer2Id;
  final String? themPlayer1Id;
  final String? themPlayer2Id;
  final String? usPlayer1Name;
  final String? usPlayer2Name;
  final String? themPlayer1Name;
  final String? themPlayer2Name;
  final int dealerTurn;
  final String? winnerSide;
  final bool leaderboardRecorded;
  final DateTime? finishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ScorekeepingRound> rounds;

  const ScorekeepingGame({
    required this.id,
    required this.diwaniyaId,
    required this.usScore,
    required this.themScore,
    required this.usPlayer1Id,
    required this.usPlayer2Id,
    required this.themPlayer1Id,
    required this.themPlayer2Id,
    required this.usPlayer1Name,
    required this.usPlayer2Name,
    required this.themPlayer1Name,
    required this.themPlayer2Name,
    required this.dealerTurn,
    required this.winnerSide,
    required this.leaderboardRecorded,
    required this.finishedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.rounds,
  });

  bool get isFinished => finishedAt != null || winnerSide != null;

  factory ScorekeepingGame.fromJson(Map<String, dynamic> raw) {
    String? clean(dynamic value) {
      final text = (value ?? '').toString().trim();
      return text.isEmpty ? null : text;
    }

    return ScorekeepingGame(
      id: (raw['id'] ?? '').toString(),
      diwaniyaId: (raw['diwaniya_id'] ?? raw['diwaniyaId'] ?? '').toString(),
      usScore: ((raw['us_score'] ?? raw['usScore'] ?? 0) as num).toInt(),
      themScore:
          ((raw['them_score'] ?? raw['themScore'] ?? 0) as num).toInt(),
      usPlayer1Id: clean(raw['us_player_1_id'] ?? raw['usPlayer1Id']),
      usPlayer2Id: clean(raw['us_player_2_id'] ?? raw['usPlayer2Id']),
      themPlayer1Id:
          clean(raw['them_player_1_id'] ?? raw['themPlayer1Id']),
      themPlayer2Id:
          clean(raw['them_player_2_id'] ?? raw['themPlayer2Id']),
      usPlayer1Name: clean(raw['us_player_1_name'] ?? raw['usPlayer1Name']),
      usPlayer2Name: clean(raw['us_player_2_name'] ?? raw['usPlayer2Name']),
      themPlayer1Name:
          clean(raw['them_player_1_name'] ?? raw['themPlayer1Name']),
      themPlayer2Name:
          clean(raw['them_player_2_name'] ?? raw['themPlayer2Name']),
      dealerTurn: ((raw['dealer_turn'] ?? raw['dealerTurn'] ?? 0) as num)
          .toInt()
          .clamp(0, 3),
      winnerSide: clean(raw['winner_side'] ?? raw['winnerSide']),
      leaderboardRecorded:
          (raw['leaderboard_recorded'] ?? raw['leaderboardRecorded']) == true,
      finishedAt: clean(raw['finished_at'] ?? raw['finishedAt']) == null
          ? null
          : DateTime.tryParse(
              clean(raw['finished_at'] ?? raw['finishedAt'])!,
            ),
      createdAt: DateTime.tryParse((raw['created_at'] ?? '').toString()) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse((raw['updated_at'] ?? '').toString()) ??
          DateTime.now(),
      rounds: (raw['rounds'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map((e) => ScorekeepingRound.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class ScorekeepingLeaderboardItem {
  final int rank;
  final String player1Id;
  final String player2Id;
  final String? player1Name;
  final String? player2Name;
  final int wins;

  const ScorekeepingLeaderboardItem({
    required this.rank,
    required this.player1Id,
    required this.player2Id,
    required this.player1Name,
    required this.player2Name,
    required this.wins,
  });

  factory ScorekeepingLeaderboardItem.fromJson(Map<String, dynamic> raw) {
    String? clean(dynamic value) {
      final text = (value ?? '').toString().trim();
      return text.isEmpty ? null : text;
    }

    return ScorekeepingLeaderboardItem(
      rank: ((raw['rank'] ?? 0) as num).toInt(),
      player1Id: (raw['player_1_id'] ?? raw['player1Id'] ?? '').toString(),
      player2Id: (raw['player_2_id'] ?? raw['player2Id'] ?? '').toString(),
      player1Name: clean(raw['player_1_name'] ?? raw['player1Name']),
      player2Name: clean(raw['player_2_name'] ?? raw['player2Name']),
      wins: ((raw['wins'] ?? 0) as num).toInt(),
    );
  }

  String get names {
    final a = player1Name?.trim().isNotEmpty == true ? player1Name! : 'لاعب';
    final b = player2Name?.trim().isNotEmpty == true ? player2Name! : 'لاعب';
    return '$a + $b';
  }
}

class ScorekeepingService {
  ScorekeepingService._();

  static Future<ScorekeepingGame> current(String diwaniyaId) async {
    final raw = await ApiClient.get(Endpoints.scorekeepingCurrent(diwaniyaId));
    return ScorekeepingGame.fromJson(Map<String, dynamic>.from(raw));
  }

  static Future<ScorekeepingGame> createGame(String diwaniyaId) async {
    final raw = await ApiClient.post(Endpoints.scorekeepingGames(diwaniyaId));
    return ScorekeepingGame.fromJson(Map<String, dynamic>.from(raw));
  }

  static Future<ScorekeepingGame> updatePlayers({
    required String diwaniyaId,
    required String gameId,
    required List<String> usPlayerIds,
    required List<String> themPlayerIds,
  }) async {
    final raw = await ApiClient.patch(
      Endpoints.scorekeepingPlayers(diwaniyaId, gameId),
      body: {
        'us_player_ids': usPlayerIds,
        'them_player_ids': themPlayerIds,
      },
    );
    return ScorekeepingGame.fromJson(Map<String, dynamic>.from(raw));
  }

  static Future<ScorekeepingGame> addRound({
    required String diwaniyaId,
    required String gameId,
    required int usPoints,
    required int themPoints,
  }) async {
    final raw = await ApiClient.post(
      Endpoints.scorekeepingRounds(diwaniyaId, gameId),
      body: {
        'us_points': usPoints,
        'them_points': themPoints,
      },
    );
    return ScorekeepingGame.fromJson(Map<String, dynamic>.from(raw));
  }

  static Future<ScorekeepingGame> updateDealer({
    required String diwaniyaId,
    required String gameId,
    required int dealerTurn,
  }) async {
    final raw = await ApiClient.patch(
      Endpoints.scorekeepingDealer(diwaniyaId, gameId),
      body: {'dealer_turn': dealerTurn},
    );
    return ScorekeepingGame.fromJson(Map<String, dynamic>.from(raw));
  }

  static Future<List<ScorekeepingLeaderboardItem>> leaderboard(
    String diwaniyaId,
  ) async {
    final raw = await ApiClient.get(Endpoints.scorekeepingLeaderboard(diwaniyaId));
    final items = (raw['items'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map(
          (e) => ScorekeepingLeaderboardItem.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList();
    return items;
  }
}
