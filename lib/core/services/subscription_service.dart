import 'dart:convert';

import 'package:hive/hive.dart';

import '../models/mock_data.dart';
import '../models/subscription_status.dart';
import '../storage/hive_storage.dart';
import 'session_service.dart';

class SubscriptionService {
  SubscriptionService._();

  static const _prefix = 'sub_';
  static const _accountPrefix = 'user_subscriptions_';

  static Box get _authBox => Hive.box(HiveBoxes.auth);

  static String? _currentUserIdFromSession() {
    final raw = SessionService.get<String>('userProfile');
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = Map<String, dynamic>.from(jsonDecode(raw));
      final userId = (json['userId'] as String?)?.trim();
      return userId == null || userId.isEmpty ? null : userId;
    } catch (_) {
      return null;
    }
  }

  static String _accountKey(String userId) => '$_accountPrefix$userId';

  static Map<String, dynamic> _readAccountMap(String userId) {
    final raw = _authBox.get(_accountKey(userId));
    if (raw is! String || raw.isEmpty) {
      return <String, dynamic>{};
    }
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static Future<void> _writeAccountMap(String userId, Map<String, dynamic> map) async {
    await _authBox.put(_accountKey(userId), jsonEncode(map));
  }
  /// Get subscription for a specific diwaniya.
  static SubscriptionStatus? forDiwaniya(String diwaniyaId) {
    final raw = SessionService.get<String>('$_prefix$diwaniyaId');
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return SubscriptionStatus.fromJson(Map<String, dynamic>.from(jsonDecode(raw)));
  }

  /// Get subscription for the currently selected diwaniya.
  static SubscriptionStatus? get current => forDiwaniya(currentDiwaniyaId);

  /// Save subscription for a specific diwaniya.
  static Future<void> save(SubscriptionStatus status, {String? diwaniyaId}) async {
    final did = diwaniyaId ?? status.diwaniyaId ?? currentDiwaniyaId;
    if (did.isEmpty) return;

    final withId = SubscriptionStatus(
      plan: status.plan,
      isCreator: status.isCreator,
      billingStartsAt: status.billingStartsAt,
      amountSar: status.amountSar,
      active: status.active,
      diwaniyaId: did,
    );
    final encoded = jsonEncode(withId.toJson());
    await SessionService.put('$_prefix$did', encoded);

    final userId = _currentUserIdFromSession();
    if (userId != null) {
      final map = _readAccountMap(userId);
      map[did] = withId.toJson();
      await _writeAccountMap(userId, map);
    }
  }

  static Future<void> restoreForUser({
    required String userId,
    required List<DiwaniyaInfo> visibleDiwaniyas,
  }) async {
    if (userId.trim().isEmpty) return;

    final map = _readAccountMap(userId);
    var changed = false;

    for (final d in visibleDiwaniyas) {
      final stored = map[d.id];
      SubscriptionStatus resolved;
      if (stored is Map) {
        resolved = SubscriptionStatus.fromJson(Map<String, dynamic>.from(stored));
      } else {
        final ownerLike = d.creatorUserId == userId || d.managerId == userId;
        resolved = SubscriptionStatus(
          plan: ownerLike ? SubscriptionPlan.free : SubscriptionPlan.joined,
          isCreator: ownerLike,
          amountSar: 0,
          active: true,
          diwaniyaId: d.id,
        );
        map[d.id] = resolved.toJson();
        changed = true;
      }
      await SessionService.put('$_prefix${d.id}', jsonEncode(resolved.toJson()));
    }

    if (changed) {
      await _writeAccountMap(userId, map);
    }
  }

  static Future<void> removeForUser({
    required String userId,
    required String diwaniyaId,
  }) async {
    if (userId.trim().isEmpty || diwaniyaId.trim().isEmpty) return;
    final map = _readAccountMap(userId);
    if (map.remove(diwaniyaId) != null) {
      await _writeAccountMap(userId, map);
    }
  }

  static Future<void> removeForCurrentUser(String diwaniyaId) async {
    final userId = _currentUserIdFromSession();
    if (userId == null) return;
    await removeForUser(userId: userId, diwaniyaId: diwaniyaId);
  }

  /// Clear subscription for the currently selected diwaniya only.
  static Future<void> clear() async {
    if (currentDiwaniyaId.isNotEmpty) {
      await SessionService.put('$_prefix$currentDiwaniyaId', null);
    }
  }

  /// Clear all subscriptions (called during sign-out).
  static Future<void> clearAll() async {
    for (final d in allDiwaniyas) {
      await SessionService.put('$_prefix${d.id}', null);
    }
  }
}
