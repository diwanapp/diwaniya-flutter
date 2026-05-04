import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════
// MODEL CLASSES
// ═══════════════════════════════════════════════════════════

class DiwaniyaInfo {
  final String id, name, district, city, managerId;
  final String country;
  final int? expectedMembers;
  final Color color;
  final String? invitationCode;
  final String? creatorUserId;
  final String? imagePath;
  final int? memberCount;

  const DiwaniyaInfo({
    required this.id,
    required this.name,
    required this.district,
    required this.city,
    required this.managerId,
    this.country = 'السعودية',
    this.expectedMembers,
    required this.color,
    this.invitationCode,
    this.creatorUserId,
    this.imagePath,
    this.memberCount,
  });
}

class DiwaniyaMember {
  final String name, initials, role;
  final Color avatarColor;
  final DateTime? joinedAt;

  /// Backend user id when hydrated from the API. May be null for
  /// legacy locally-created members until the next server refresh.
  final String? userId;

  const DiwaniyaMember({
    required this.name,
    required this.initials,
    required this.role,
    required this.avatarColor,
    this.joinedAt,
    this.userId,
  });
}

class DiwaniyaPoll {
  final String id, question, diwaniyaId, createdBy;
  final List<String> options;
  final Map<String, int> votesPerOption;
  final Map<String, String> votedMembers;
  final int totalMembers;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? closedAt;
  int get totalVotes => votedMembers.length;
  DiwaniyaPoll(
      {required this.id,
      required this.question,
      required this.diwaniyaId,
      required this.createdBy,
      required this.options,
      required this.votesPerOption,
      required this.votedMembers,
      required this.totalMembers,
      required this.isActive,
      required this.createdAt,
      this.closedAt});
}

class DiwaniyaActivity {
  final String type, diwaniyaId, actor, message;
  final DateTime createdAt;
  final IconData icon;
  final Color iconColor;
  const DiwaniyaActivity(
      {required this.type,
      required this.diwaniyaId,
      required this.actor,
      required this.message,
      required this.createdAt,
      required this.icon,
      required this.iconColor});
}

class DiwaniyaNotification {
  final String id, diwaniyaId, message, type;
  final String? referenceId;
  final DateTime createdAt;
  final bool isRead;
  final IconData icon;
  final Color iconColor;
  const DiwaniyaNotification(
      {required this.id,
      required this.diwaniyaId,
      required this.message,
      required this.type,
      required this.createdAt,
      required this.isRead,
      required this.icon,
      required this.iconColor,
      this.referenceId});
}

class ExpenseCategory {
  final String name;
  final IconData icon;
  final Color color;
  const ExpenseCategory(
      {required this.name, required this.icon, required this.color});
}

class MockShoppingItem {
  final String id, name, category, status;
  final String? updatedBy, note;
  final DateTime? updatedAt;
  final IconData icon;
  MockShoppingItem(
      {required this.id,
      required this.name,
      required this.category,
      required this.status,
      this.updatedBy,
      this.updatedAt,
      this.note,
      required this.icon});
}

// ═══════════════════════════════════════════════════════════
// STATIC DEFAULTS (UI config, not operational data)
// ═══════════════════════════════════════════════════════════

final List<ExpenseCategory> defaultExpenseCategories = [
  const ExpenseCategory(
      name: 'الإيجار', icon: Icons.home_rounded, color: Color(0xFF60A5FA)),
  const ExpenseCategory(
      name: 'فواتير', icon: Icons.receipt_rounded, color: Color(0xFF38BDF8)),
  const ExpenseCategory(
      name: 'راتب العامل',
      icon: Icons.person_rounded,
      color: Color(0xFFFB923C)),
  const ExpenseCategory(
      name: 'لوازم الكيف',
      icon: Icons.smoking_rooms_rounded,
      color: Color(0xFFA78BFA)),
  const ExpenseCategory(
      name: 'مشروبات',
      icon: Icons.local_drink_rounded,
      color: Color(0xFF34D399)),
  const ExpenseCategory(
      name: 'طعام', icon: Icons.restaurant_rounded, color: Color(0xFFFBBF24)),
  const ExpenseCategory(
      name: 'مستلزمات',
      icon: Icons.inventory_2_rounded,
      color: Color(0xFFFB923C)),
  const ExpenseCategory(
      name: 'أخرى', icon: Icons.more_horiz_rounded, color: Color(0xFF9CA3AF)),
];

// ═══════════════════════════════════════════════════════════
// RUNTIME STATE (empty on fresh launch — all per-diwaniya)
// ═══════════════════════════════════════════════════════════

/// All diwaniyas the user belongs to (populated after onboarding/auth).
final List<DiwaniyaInfo> allDiwaniyas = [];

/// Per-diwaniya data maps — start empty.
final Map<String, List<DiwaniyaMember>> diwaniyaMembers = {};
final Map<String, List<DiwaniyaPoll>> diwaniyaPolls = {};
final Map<String, List<DiwaniyaActivity>> diwaniyaActivities = {};
final Map<String, List<DiwaniyaNotification>> diwaniyaNotifications = {};
final Map<String, List<MockShoppingItem>> diwaniyaShoppingItems = {};

/// Per-diwaniya custom categories (manager-created).
final Map<String, List<String>> diwaniyaCustomCategories = {};

/// Currently selected diwaniya.
String currentDiwaniyaId = '';

/// Global change notifier — bumped on every mutation.
final dataVersion = ValueNotifier<int>(0);

// ═══════════════════════════════════════════════════════════
// GLOBAL HELPERS
// ═══════════════════════════════════════════════════════════

void addGlobalActivity(String diwaniyaId, String type, String actor,
    String message, IconData icon, Color iconColor) {
  diwaniyaActivities[diwaniyaId] ??= [];
  diwaniyaActivities[diwaniyaId]!.insert(
      0,
      DiwaniyaActivity(
          type: type,
          diwaniyaId: diwaniyaId,
          actor: actor,
          message: message,
          createdAt: DateTime.now(),
          icon: icon,
          iconColor: iconColor));
  dataVersion.value++;
}

void addGlobalNotification(String diwaniyaId, String message, String type,
    IconData icon, Color iconColor,
    {String? referenceId}) {
  diwaniyaNotifications[diwaniyaId] ??= [];
  diwaniyaNotifications[diwaniyaId]!.insert(
      0,
      DiwaniyaNotification(
          id: 'n_${DateTime.now().millisecondsSinceEpoch}',
          diwaniyaId: diwaniyaId,
          message: message,
          type: type,
          createdAt: DateTime.now(),
          isRead: false,
          icon: icon,
          iconColor: iconColor,
          referenceId: referenceId));
}

/// Get current diwaniya members (used by expenses split UI etc).
List<DiwaniyaMember> get currentMembers =>
    diwaniyaMembers[currentDiwaniyaId] ?? [];
