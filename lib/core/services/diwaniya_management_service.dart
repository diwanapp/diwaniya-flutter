import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../api/diwaniya_api.dart';
import '../api/diwaniya_management_api.dart';
import '../models/mock_data.dart';
import '../models/role_change_request.dart';
import '../repositories/app_repository.dart';
import 'user_service.dart';
import 'session_service.dart';

/// Backend-authoritative diwaniya management.
///
/// Every state-changing action calls the backend first, then refreshes
/// local state from the server or applies a minimal local mutation.
/// Local guards remain UX hints only. The backend is the source of truth.
class DiwaniyaManagementService {
  DiwaniyaManagementService._();

  // Deprecated local approval flow kept only to avoid breaking old call sites.
  static final Map<String, List<RoleChangeRequest>> requests = {};

  static List<RoleChangeRequest> requestsFor(String diwaniyaId) =>
      requests[diwaniyaId] ??= <RoleChangeRequest>[];

  static void restore(String diwaniyaId, List<RoleChangeRequest> restored) {
    requests[diwaniyaId] = List<RoleChangeRequest>.from(restored)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @Deprecated('Local approval flow superseded by backend demote endpoint. Use demoteMember.')
  static List<RoleChangeRequest> pendingForMe(String diwaniyaId) =>
      const <RoleChangeRequest>[];

  @Deprecated('Local approval flow superseded by backend demote endpoint.')
  static List<RoleChangeRequest> pendingByMe(String diwaniyaId) =>
      const <RoleChangeRequest>[];

  @Deprecated('Use demoteMember which goes directly through the backend.')
  static RoleChangeRequest? requestDemotion(String diwaniyaId, String targetName) =>
      null;

  @Deprecated('No-op. Use demoteMember directly.')
  static bool acceptDemotion(String diwaniyaId, String requestId) => false;

  @Deprecated('No-op. Use demoteMember directly.')
  static bool rejectDemotion(String diwaniyaId, String requestId) => false;

  @Deprecated('No-op. Use demoteMember directly.')
  static bool cancelDemotion(String diwaniyaId, String requestId) => false;

  static bool isMemberManager(String diwaniyaId, String memberName) {
    final members = diwaniyaMembers[diwaniyaId] ?? [];
    return members.any((m) => m.name == memberName && m.role == 'manager');
  }

  static int managerCount(String diwaniyaId) {
    return (diwaniyaMembers[diwaniyaId] ?? [])
        .where((m) => m.role == 'manager')
        .length;
  }

  static bool isLastManager(String diwaniyaId, String memberName) {
    return isMemberManager(diwaniyaId, memberName) &&
        managerCount(diwaniyaId) <= 1;
  }

  static void updateDiwaniyaInfo(
    String diwaniyaId, {
    String? name,
    String? city,
    String? district,
    String? imagePath,
    String? invitationCode,
    bool removeImage = false,
  }) {
    final idx = allDiwaniyas.indexWhere((d) => d.id == diwaniyaId);
    if (idx < 0) return;

    final old = allDiwaniyas[idx];
    final newName = name?.trim() ?? old.name;
    final newCity = city?.trim() ?? old.city;
    final newDistrict = district?.trim() ?? old.district;
    final newImage = removeImage ? null : (imagePath ?? old.imagePath);
    final newCode = invitationCode ?? old.invitationCode;

    allDiwaniyas[idx] = DiwaniyaInfo(
      id: old.id,
      name: newName,
      district: newDistrict,
      city: newCity,
      managerId: old.managerId,
      color: old.color,
      invitationCode: newCode,
      creatorUserId: old.creatorUserId,
      imagePath: newImage,
    );

    final actor = UserService.currentName;
    if (city != null && city.trim() != old.city) {
      _activity(
        diwaniyaId,
        'city_changed',
        '$actor غيّر المدينة إلى $newCity',
        Icons.location_city_rounded,
        const Color(0xFF60A5FA),
      );
    }
    if (district != null && district.trim() != old.district) {
      _activity(
        diwaniyaId,
        'district_changed',
        '$actor غيّر الحي إلى $newDistrict',
        Icons.place_rounded,
        const Color(0xFF60A5FA),
      );
    }

    AppRepository.saveDiwaniyas();
    dataVersion.value++;
  }

  @Deprecated('No backend endpoint yet. Local removal only — will not sync to other devices.')
  static bool removeMember(String diwaniyaId, String memberName) {
    final members = diwaniyaMembers[diwaniyaId];
    if (members == null) return false;

    final target = members.where((m) => m.name == memberName).firstOrNull;
    if (target == null) return false;
    if (target.role == 'manager' && managerCount(diwaniyaId) <= 1) {
      return false;
    }

    members.removeWhere((m) => m.name == memberName);

    final actor = UserService.currentName;
    _activity(
      diwaniyaId,
      'member_removed',
      '$actor أزال $memberName من الديوانية',
      Icons.person_remove_rounded,
      const Color(0xFFF87171),
    );

    AppRepository.saveDiwaniyas();
    AppRepository.saveActivities();
    AppRepository.saveNotifications();
    dataVersion.value++;
    return true;
  }

  static Future<void> promoteMember({
    required String diwaniyaId,
    required String userId,
  }) async {
    await DiwaniyaManagementApi.promote(
      diwaniyaId: diwaniyaId,
      userId: userId,
    );
    await _refreshMembersFromServer(diwaniyaId);
  }

  static Future<void> demoteMember({
    required String diwaniyaId,
    required String userId,
  }) async {
    await DiwaniyaManagementApi.demote(
      diwaniyaId: diwaniyaId,
      userId: userId,
    );
    await _refreshMembersFromServer(diwaniyaId);
  }

  static Future<void> leaveDiwaniya(String diwaniyaId) async {
    await DiwaniyaManagementApi.leave(diwaniyaId);
    await _removeDiwaniyaLocally(diwaniyaId);
  }

  static Future<void> deleteDiwaniya(String diwaniyaId) async {
    await DiwaniyaManagementApi.deleteDiwaniya(diwaniyaId);
    await _removeDiwaniyaLocally(diwaniyaId);
  }

  static Future<String> regenerateInviteCode(String diwaniyaId) async {
    final result = await DiwaniyaManagementApi.regenerateInvite(diwaniyaId);
    final newCode = (result['invitation_code'] as String?) ?? '';
    await _applyInvitationCodeLocally(diwaniyaId, newCode);
    return newCode;
  }

  static Future<void> _refreshMembersFromServer(String diwaniyaId) async {
    try {
      final serverMembers = await DiwaniyaApi.getMembers(diwaniyaId);
      final rebuilt = <DiwaniyaMember>[];

      for (final raw in serverMembers) {
        final name = (raw['display_name'] as String?) ?? '';
        if (name.isEmpty) continue;

        final roleTypesRaw = raw['role_types'];
        final roleTypes = roleTypesRaw is List
            ? roleTypesRaw.map((e) => e.toString()).toList()
            : const <String>[];

        final isElevated = roleTypes.contains('manager') ||
            roleTypes.contains('founder') ||
            roleTypes.contains('billing_owner');

        final initialsParts =
            name.trim().split(' ').where((s) => s.isNotEmpty).toList();

        rebuilt.add(
          DiwaniyaMember(
            name: name,
            initials: initialsParts.isEmpty
                ? '?'
                : (initialsParts.length == 1
                    ? initialsParts.first.substring(0, 1)
                    : '${initialsParts.first.substring(0, 1)}${initialsParts.last.substring(0, 1)}'),
            role: isElevated ? 'manager' : 'member',
            avatarColor: const Color(0xFF60A5FA),
            joinedAt: DateTime.now(),
            userId: (raw['user_id'] as String?) ?? '',
          ),
        );
      }

      diwaniyaMembers[diwaniyaId] = rebuilt;
      await AppRepository.saveDiwaniyas();
      dataVersion.value++;
    } on ApiException {
      // Non-fatal. The action already succeeded on the backend.
    } catch (_) {
      // Non-fatal.
    }
  }

  static Future<void> _applyInvitationCodeLocally(
    String diwaniyaId,
    String newCode,
  ) async {
    if (newCode.isEmpty) return;

    final idx = allDiwaniyas.indexWhere((d) => d.id == diwaniyaId);
    if (idx < 0) return;

    final old = allDiwaniyas[idx];
    allDiwaniyas[idx] = DiwaniyaInfo(
      id: old.id,
      name: old.name,
      district: old.district,
      city: old.city,
      managerId: old.managerId,
      color: old.color,
      invitationCode: newCode,
      creatorUserId: old.creatorUserId,
      imagePath: old.imagePath,
    );

    await AppRepository.saveDiwaniyas();
    dataVersion.value++;
  }

  static Future<void> _removeDiwaniyaLocally(String diwaniyaId) async {
    allDiwaniyas.removeWhere((d) => d.id == diwaniyaId);
    diwaniyaMembers.remove(diwaniyaId);

    if (currentDiwaniyaId == diwaniyaId) {
      currentDiwaniyaId = allDiwaniyas.isNotEmpty ? allDiwaniyas.first.id : '';
    }

    await AppRepository.clearDiwaniyaData(diwaniyaId);
    await AppRepository.saveSelectedDiwaniya(currentDiwaniyaId);
    await SessionService.put('membershipCompleted', allDiwaniyas.isNotEmpty);
    await AppRepository.saveDiwaniyas();
    dataVersion.value++;
  }

  static void _activity(
    String diwaniyaId,
    String type,
    String message,
    IconData icon,
    Color color,
  ) {
    addGlobalActivity(
      diwaniyaId,
      type,
      UserService.currentName,
      message,
      icon,
      color,
    );
  }
}
