import 'session_service.dart';

/// Per-type notification toggles. Stored as booleans in SessionService.
/// Defaults are all enabled. Manager-specific toggles are stored even
/// for non-managers (no-op since non-manager UI hides them) so the
/// state persists if the user later becomes a manager.
class NotificationPreferencesService {
  NotificationPreferencesService._();

  // ── Keys ──
  static const _kChat = 'notif_chat';
  static const _kPoll = 'notif_poll';
  static const _kMaqadi = 'notif_maqadi';
  static const _kActivity = 'notif_activity';
  static const _kManagerJoinRequests = 'notif_mgr_join_requests';
  static const _kManagerRoleRequests = 'notif_mgr_role_requests';
  static const _kManagerApprovals = 'notif_mgr_approvals';

  // ── Read ──
  static bool get chat => _read(_kChat);
  static bool get poll => _read(_kPoll);
  static bool get maqadi => _read(_kMaqadi);
  static bool get activity => _read(_kActivity);
  static bool get managerJoinRequests => _read(_kManagerJoinRequests);
  static bool get managerRoleRequests => _read(_kManagerRoleRequests);
  static bool get managerApprovals => _read(_kManagerApprovals);

  static bool _read(String key) =>
      SessionService.get<bool>(key, defaultValue: true) == true;

  // ── Write ──
  static Future<void> setChat(bool v) => SessionService.put(_kChat, v);
  static Future<void> setPoll(bool v) => SessionService.put(_kPoll, v);
  static Future<void> setMaqadi(bool v) => SessionService.put(_kMaqadi, v);
  static Future<void> setActivity(bool v) =>
      SessionService.put(_kActivity, v);
  static Future<void> setManagerJoinRequests(bool v) =>
      SessionService.put(_kManagerJoinRequests, v);
  static Future<void> setManagerRoleRequests(bool v) =>
      SessionService.put(_kManagerRoleRequests, v);
  static Future<void> setManagerApprovals(bool v) =>
      SessionService.put(_kManagerApprovals, v);

  /// Returns true if the given notification type is allowed by the
  /// user's current preferences. Used by the home screen's notification
  /// helper to gate in-app notification creation.
  ///
  /// Type strings come from existing call sites in home_screen:
  /// 'chat', 'poll', 'maqadi', 'activity', and various others.
  /// Unknown types default to allowed (fail open).
  static bool isTypeAllowed(String type) {
    switch (type) {
      case 'chat':
        return chat;
      case 'poll':
        return poll;
      case 'maqadi':
      case 'shopping':
        return maqadi;
      case 'activity':
      case 'expense':
      case 'photo':
        return activity;
      default:
        return true;
    }
  }
}
