import '../models/mock_data.dart';
import 'auth_service.dart';

class UserService {
  UserService._();

  static String get currentName => AuthService.displayName;
  static String get currentId => AuthService.currentUserId;
  static String? get avatarPresetId => AuthService.avatarPresetId;

  /// Check if current user is a manager in a diwaniya.
  /// Checks member list role first, falls back to DiwaniyaInfo.managerId.
  static bool isManager([String? diwaniyaId]) {
    final did = diwaniyaId ?? currentDiwaniyaId;
    final members = diwaniyaMembers[did] ?? [];
    final me = members.where((m) => m.name == currentName).firstOrNull;
    if (me != null) {
      return me.role == 'manager' ||
          me.role == 'founder' ||
          me.role == 'billing_owner';
    }
    // Fallback: check creator/managerId
    final diw = allDiwaniyas.where((d) => d.id == did).firstOrNull;
    return diw?.managerId == currentId;
  }
}
