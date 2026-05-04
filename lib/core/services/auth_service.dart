import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../config/theme/app_colors.dart';
import '../api/api_exception.dart';
import '../api/auth_api.dart';
import '../api/diwaniya_api.dart';
import '../api/join_request_api.dart';
import '../api/me_api.dart';
import '../api/token_storage.dart';
import '../models/join_request.dart';
import '../models/mock_data.dart';
import '../models/subscription_status.dart';
import '../models/user_profile.dart';
import '../repositories/app_repository.dart';
import '../storage/hive_storage.dart';
import 'diwaniya_management_service.dart';
import 'session_service.dart';
import 'subscription_service.dart';

class AuthService {
  AuthService._();

  static const _profileKey = 'userProfile';
  static const _otpVerifiedKey = 'otpVerified';
  static const _avatarKey = 'avatarSelected';
  static const _pendingCreateKey = 'pendingCreateDiwaniya';

  static UserProfile? get profile {
    final raw = SessionService.get<String>(_profileKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return UserProfile.fromJson(Map<String, dynamic>.from(jsonDecode(raw)));
  }

  static String get currentUserId => profile?.userId ?? '';
  static String get currentPhone => profile?.phone ?? '';
  static String get displayName => profile?.fullName ?? '';
  static String? get avatarPresetId => profile?.avatarPresetId;
  static String? get profileImagePath => profile?.profileImagePath;

  static bool get otpVerified =>
      SessionService.get<bool>(_otpVerifiedKey, defaultValue: false) == true;

  static bool get hasAvatar =>
      SessionService.get<bool>(_avatarKey, defaultValue: false) == true;

  static bool get hasDiwaniya =>
      SessionService.get<bool>('membershipCompleted', defaultValue: false) ==
          true &&
      currentDiwaniyaId.isNotEmpty;

  /// In-memory only. Resets on cold boot.
  static bool otpRequestedInSession = false;

  /// Pending + resolved join requests for the current user, hydrated
  /// separately from approved memberships.
  static final List<JoinRequest> pendingJoinRequests = <JoinRequest>[];

  static bool get hasPendingJoinRequest =>
      pendingJoinRequests.any((r) => r.isPending);

  /// Silent session bootstrap on app launch.
  static Future<bool> bootstrapSession() async {
    if (!TokenStorage.hasAccessToken || profile == null || !otpVerified) {
      await AppRepository.clearAllPersistedDomainData(clearSession: false);
      await SessionService.put('membershipCompleted', false);
      return false;
    }

    try {
      final me = await AuthApi.getMe();
      final existing = profile;
      final serverDisplayName = ((me['display_name'] as String?) ?? '').trim();
      final serverPhone =
          (me['mobile_number'] as String?) ?? existing?.phone ?? '';

      String firstName = existing?.firstName ?? '';
      String lastName = existing?.lastName ?? '';

      if (serverDisplayName.isNotEmpty) {
        final parts =
            serverDisplayName.split(' ').where((s) => s.isNotEmpty).toList();
        if (parts.isNotEmpty) {
          firstName = parts.first;
          lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
        }
      }

      final merged = UserProfile(
        userId: (me['id'] as String?) ?? existing?.userId ?? '',
        firstName: firstName,
        lastName: lastName,
        phone: serverPhone,
        avatarPresetId: existing?.avatarPresetId,
        profileImagePath: existing?.profileImagePath,
      );
      await SessionService.put(_profileKey, jsonEncode(merged.toJson()));

      await _hydrateMembershipState();
      if (merged.userId.trim().isNotEmpty && allDiwaniyas.isNotEmpty) {
        await SubscriptionService.restoreForUser(
          userId: merged.userId.trim(),
          visibleDiwaniyas: List<DiwaniyaInfo>.from(allDiwaniyas),
        );
      }
      await _hydrateJoinRequestsState();
      await SessionService.activate();
      return true;
    } on ApiException catch (e) {
      if (e.code == ApiErrorCode.unauthorized) {
        await TokenStorage.clear();
        await signOut();
        return false;
      }
      await AppRepository.clearAllPersistedDomainData(clearSession: false);
      await SessionService.put('membershipCompleted', false);
      pendingJoinRequests.clear();
      return false;
    } catch (_) {
      await AppRepository.clearAllPersistedDomainData(clearSession: false);
      await SessionService.put('membershipCompleted', false);
      pendingJoinRequests.clear();
      return false;
    }
  }

  static Future<void> createOrUpdateProfileDraft({
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    final existing = profile;
    final updated = UserProfile(
      userId: (existing?.userId.trim().isNotEmpty ?? false)
          ? existing!.userId
          : 'u_${DateTime.now().millisecondsSinceEpoch}',
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      phone: phone.trim(),
      avatarPresetId: existing?.avatarPresetId,
      profileImagePath: existing?.profileImagePath,
    );
    await SessionService.put(_profileKey, jsonEncode(updated.toJson()));
  }

  static Future<void> markOtpVerified() async {
    await SessionService.put(_otpVerifiedKey, true);
    await SessionService.activate();
  }

  static Future<OtpRequestResult> requestOtpViaApi({
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    await createOrUpdateProfileDraft(
      firstName: '',
      lastName: '',
      phone: phone,
    );

    final result = await AuthApi.requestOtp(mobileNumber: phone);
    otpRequestedInSession = true;

    if (result.isNewUser == true) {
      await createOrUpdateProfileDraft(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
      );
    }

    return result;
  }

  static Future<void> verifyOtpViaApi({
    required String phone,
    required String otpCode,
  }) async {
    final response = await AuthApi.verifyOtp(
      mobileNumber: phone,
      otpCode: otpCode,
    );

    final accessToken = response['access_token'];
    final refreshToken = response['refresh_token'];
    if (accessToken is! String || accessToken.isEmpty) {
      throw const ApiException(
        code: ApiErrorCode.parse,
        message: 'Missing access_token in verify response',
      );
    }

    await TokenStorage.save(
      accessToken: accessToken,
      refreshToken: refreshToken is String ? refreshToken : '',
    );

    final userPayload = response['user'];
    if (userPayload is Map) {
      final user = Map<String, dynamic>.from(userPayload);
      final existing = profile;

      final incomingUserId = (user['id'] as String?)?.trim() ?? '';
      final existingUserId = existing?.userId.trim() ?? '';
      final hasStableExistingIdentity = otpVerified &&
          existingUserId.isNotEmpty &&
          !existingUserId.startsWith('u_');
      final switchingAccounts = hasStableExistingIdentity &&
          incomingUserId.isNotEmpty &&
          existingUserId != incomingUserId;

      if (switchingAccounts) {
        final preservedAccessToken = accessToken;
        final preservedRefreshToken =
            refreshToken is String ? refreshToken : '';
        await AppRepository.clearAllPersistedDomainData();
        await TokenStorage.save(
          accessToken: preservedAccessToken,
          refreshToken: preservedRefreshToken,
        );
      }

      final serverDisplayName =
          ((user['display_name'] as String?) ?? '').trim();
      final serverPhone =
          (user['mobile_number'] as String?) ?? existing?.phone ?? phone;

      String firstName = existing?.firstName ?? '';
      String lastName = existing?.lastName ?? '';

      if (serverDisplayName.isNotEmpty) {
        final parts =
            serverDisplayName.split(' ').where((s) => s.isNotEmpty).toList();
        if (parts.isNotEmpty) {
          firstName = parts.first;
          lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
        }
      }

      final merged = UserProfile(
        userId: incomingUserId.isNotEmpty
            ? incomingUserId
            : (existing?.userId ?? ''),
        firstName: firstName,
        lastName: lastName,
        phone: serverPhone,
        avatarPresetId: existing?.avatarPresetId,
        profileImagePath: existing?.profileImagePath,
      );
      await SessionService.put(_profileKey, jsonEncode(merged.toJson()));

      final mergedFullName = merged.fullName.trim();
      if (serverDisplayName.isEmpty && mergedFullName.isNotEmpty) {
        try {
          final updated =
              await MeApi.updateProfile(displayName: mergedFullName);
          final updatedName =
              ((updated['display_name'] as String?) ?? '').trim();

          if (updatedName.isNotEmpty) {
            final parts =
                updatedName.split(' ').where((s) => s.isNotEmpty).toList();

            final refreshed = UserProfile(
              userId: (updated['id'] as String?) ?? merged.userId,
              firstName: parts.isNotEmpty ? parts.first : merged.firstName,
              lastName: parts.length > 1
                  ? parts.sublist(1).join(' ')
                  : merged.lastName,
              phone: (updated['mobile_number'] as String?) ?? merged.phone,
              avatarPresetId: merged.avatarPresetId,
              profileImagePath: merged.profileImagePath,
            );

            await SessionService.put(
              _profileKey,
              jsonEncode(refreshed.toJson()),
            );
          }
        } catch (_) {
          // Non-fatal.
        }
      }
    }

    await _hydrateMembershipState();
    await _hydrateJoinRequestsState();
    await markOtpVerified();
  }

  static Future<void> _hydrateMembershipState() async {
    await refreshMembershipsFromServer();
  }

  static Future<bool> refreshMembershipsFromServer({
    String? preferredDiwaniyaId,
    String? removedDiwaniyaId,
  }) async {
    try {
      final serverDiwaniyas = await MeApi.getMyDiwaniyas();
      final previousActiveId = currentDiwaniyaId;
      final cachedDiwaniyas = List<DiwaniyaInfo>.from(allDiwaniyas);
      final preferredId = preferredDiwaniyaId?.trim() ?? '';
      final removedId = removedDiwaniyaId?.trim() ?? '';

      allDiwaniyas.clear();
      diwaniyaMembers.clear();

      for (final raw in serverDiwaniyas) {
        final id = (raw['id'] as String?) ?? '';
        if (id.isEmpty) continue;

        final roleTypesRaw = raw['role_types'];
        final roleTypes = roleTypesRaw is List
            ? roleTypesRaw.map((e) => e.toString()).toList()
            : const <String>[];
        final managerId = roleTypes.contains('manager') ||
                roleTypes.contains('founder') ||
                roleTypes.contains('billing_owner')
            ? currentUserId
            : '';

        final existing = cachedDiwaniyas.where((d) => d.id == id).firstOrNull;

        allDiwaniyas.add(
          DiwaniyaInfo(
            id: id,
            name: (raw['name'] as String?) ?? existing?.name ?? '',
            city: (raw['city'] as String?) ?? existing?.city ?? '',
            district: (raw['district'] as String?) ?? existing?.district ?? '',
            invitationCode: (raw['invitation_code'] as String?) ??
                existing?.invitationCode ??
                '',
            color: existing?.color ?? AppColors.accent,
            managerId: managerId,
            creatorUserId: (raw['creator_user_id'] as String?) ??
                existing?.creatorUserId ??
                '',
            imagePath: existing?.imagePath,
            memberCount:
                _readPositiveInt(raw['member_count']) ?? existing?.memberCount,
          ),
        );
      }

      if (allDiwaniyas.isEmpty) {
        currentDiwaniyaId = '';
        await SessionService.put('membershipCompleted', false);
        await AppRepository.saveSelectedDiwaniya('');
        await AppRepository.clearAllPersistedDomainData(clearSession: false);
        dataVersion.value++;
        return true;
      }

      final candidateIds = <String>[
        if (preferredId.isNotEmpty) preferredId,
        if (previousActiveId.isNotEmpty && previousActiveId != removedId)
          previousActiveId,
      ];

      String resolvedId = '';
      for (final candidate in candidateIds) {
        final exists = allDiwaniyas.any((d) => d.id == candidate);
        if (exists) {
          resolvedId = candidate;
          break;
        }
      }
      resolvedId = resolvedId.isNotEmpty ? resolvedId : allDiwaniyas.first.id;

      currentDiwaniyaId = resolvedId;
      await SessionService.put('membershipCompleted', true);
      await AppRepository.saveSelectedDiwaniya(resolvedId);
      await AppRepository.saveDiwaniyas();
      await _syncSelectedDiwaniyaMembersSilently();
      dataVersion.value++;
      return true;
    } on ApiException {
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _syncSelectedDiwaniyaMembersSilently() async {
    if (currentDiwaniyaId.isEmpty) return;
    try {
      await syncCurrentDiwaniyaFromApi();
    } catch (_) {
      // Non-fatal. Membership shell is already hydrated.
    }
  }

  static Future<bool> switchSelectedDiwaniya(String diwaniyaId) async {
    final normalizedId = diwaniyaId.trim();
    if (normalizedId.isEmpty) return false;

    final target = allDiwaniyas.where((d) => d.id == normalizedId).firstOrNull;
    if (target == null) return false;

    if (currentDiwaniyaId == normalizedId) {
      await AppRepository.saveSelectedDiwaniya(normalizedId);
      await _syncSelectedDiwaniyaMembersSilently();
      dataVersion.value++;
      return true;
    }

    currentDiwaniyaId = normalizedId;
    await AppRepository.saveSelectedDiwaniya(normalizedId);
    await _syncSelectedDiwaniyaMembersSilently();
    dataVersion.value++;
    return true;
  }

  static Future<void> _hydrateJoinRequestsState() async {
    try {
      final serverRequests = await JoinRequestApi.getMyJoinRequests();
      pendingJoinRequests
        ..clear()
        ..addAll(serverRequests.map(JoinRequest.fromJson));
      await AppRepository.saveJoinRequests();
    } catch (_) {
      // Non-fatal.
    }
  }

  static Future<void> updateDisplayName(String newDisplayName) async {
    final updated = await MeApi.updateProfile(displayName: newDisplayName);
    final serverName = ((updated['display_name'] as String?) ?? '').trim();
    final existing = profile;
    if (existing == null) return;

    final previousName = existing.fullName.trim();
    final parts = serverName.split(' ').where((s) => s.isNotEmpty).toList();
    final firstName = parts.isNotEmpty ? parts.first : '';
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    final merged = UserProfile(
      userId: (updated['id'] as String?) ?? existing.userId,
      firstName: firstName,
      lastName: lastName,
      phone: (updated['mobile_number'] as String?) ?? existing.phone,
      avatarPresetId: existing.avatarPresetId,
      profileImagePath: existing.profileImagePath,
    );
    await SessionService.put(_profileKey, jsonEncode(merged.toJson()));

    final updatedName = merged.fullName.trim();
    if (updatedName.isNotEmpty) {
      for (final entry in diwaniyaMembers.entries) {
        final members = entry.value;
        for (var i = 0; i < members.length; i++) {
          final member = members[i];
          final isCurrentUserById = member.userId != null &&
              member.userId!.isNotEmpty &&
              member.userId == merged.userId;
          final isCurrentUserByName =
              previousName.isNotEmpty && member.name.trim() == previousName;
          if (!isCurrentUserById && !isCurrentUserByName) continue;

          members[i] = DiwaniyaMember(
            name: updatedName,
            initials: _initialsFor(updatedName),
            role: member.role,
            avatarColor: member.avatarColor,
            joinedAt: member.joinedAt,
            userId: member.userId,
          );
        }
      }
      await AppRepository.saveDiwaniyas();
    }

    dataVersion.value++;
  }

  static const String devFallbackOtpCode = '000000';

  static Future<OtpRequestResult> requestOtpViaDevFallback({
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    await createOrUpdateProfileDraft(
      firstName: firstName,
      lastName: lastName,
      phone: phone,
    );
    otpRequestedInSession = true;
    return const OtpRequestResult(isNewUser: null);
  }

  static Future<void> verifyOtpViaDevFallback({
    required String code,
  }) async {
    if (code != devFallbackOtpCode) {
      throw const ApiException(
        code: ApiErrorCode.validation,
        message: 'Dev OTP code mismatch',
      );
    }

    await TokenStorage.save(
      accessToken: 'dev-access',
      refreshToken: 'dev-refresh',
    );

    final existing = profile;
    if (existing != null && existing.userId.isEmpty) {
      final withId = UserProfile(
        userId: 'dev-${existing.phone}',
        firstName: existing.firstName,
        lastName: existing.lastName,
        phone: existing.phone,
        avatarPresetId: existing.avatarPresetId,
        profileImagePath: existing.profileImagePath,
      );
      await SessionService.put(_profileKey, jsonEncode(withId.toJson()));
    }

    await markOtpVerified();
  }

  static Future<void> signOutFromApi() async {
    await TokenStorage.clear();
    await signOut();
  }

  static Future<void> selectAvatar(String avatarId) async {
    final existing = profile;
    if (existing == null) return;
    await SessionService.put(
      _profileKey,
      jsonEncode(existing.copyWith(avatarPresetId: avatarId).toJson()),
    );
    await SessionService.put(_avatarKey, true);
  }

  static Future<void> updateProfileImage(String? imagePath) async {
    final existing = profile;
    if (existing == null) return;
    final updated = existing.copyWith(profileImagePath: () => imagePath);
    await SessionService.put(_profileKey, jsonEncode(updated.toJson()));
  }

  static Future<void> savePendingCreateDraft({
    required String name,
    required String city,
    required String district,
    required String invitationCode,
    required Color color,
    List<String> initialMembers = const [],
  }) async {
    final payload = {
      'name': name.trim(),
      'city': city.trim(),
      'district': district.trim(),
      'invitationCode': invitationCode.trim().toUpperCase(),
      'color': color.toARGB32(),
      'initialMembers': initialMembers,
    };
    await SessionService.put(_pendingCreateKey, jsonEncode(payload));
  }

  static Map<String, dynamic>? get pendingCreateDraft {
    final raw = SessionService.get<String>(_pendingCreateKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return Map<String, dynamic>.from(jsonDecode(raw));
  }

  static Future<void> clearPendingCreateDraft() async {
    await SessionService.put(_pendingCreateKey, null);
  }

  static int? _readPositiveInt(dynamic value) {
    if (value is int) {
      return value >= 0 ? value : null;
    }
    if (value is num) {
      final parsed = value.toInt();
      return parsed >= 0 ? parsed : null;
    }
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      return parsed != null && parsed >= 0 ? parsed : null;
    }
    return null;
  }

  static int memberCountFor(String diwaniyaId, {int? fallback}) {
    final normalizedId = diwaniyaId.trim();
    if (normalizedId.isEmpty) {
      return fallback ?? 0;
    }

    final members = diwaniyaMembers[normalizedId];
    if (members != null && members.isNotEmpty) {
      return members.length;
    }

    final info = allDiwaniyas.where((d) => d.id == normalizedId).firstOrNull;
    if (info?.memberCount != null) {
      return info!.memberCount!;
    }

    return fallback ?? 0;
  }

  static bool isFounder(Object diwaniyaOrId) {
    String diwaniyaId;
    if (diwaniyaOrId is DiwaniyaInfo) {
      diwaniyaId = diwaniyaOrId.id;
      final creatorId = (diwaniyaOrId.creatorUserId ?? '').trim();
      if (creatorId.isNotEmpty && currentUserId.isNotEmpty) {
        return creatorId == currentUserId;
      }
    } else {
      diwaniyaId = diwaniyaOrId.toString();
    }

    final normalizedId = diwaniyaId.trim();
    if (normalizedId.isEmpty || currentUserId.isEmpty) {
      return false;
    }

    final info = allDiwaniyas.where((d) => d.id == normalizedId).firstOrNull;
    final creatorId = (info?.creatorUserId ?? '').trim();
    if (creatorId.isNotEmpty) {
      return creatorId == currentUserId;
    }

    final members = diwaniyaMembers[normalizedId] ?? const <DiwaniyaMember>[];
    return members.any(
      (member) =>
          member.userId == currentUserId && member.role.trim() == 'founder',
    );
  }

  static List<DiwaniyaInfo> getLocalDiwaniyaDirectory() {
    final box = Hive.box(HiveBoxes.diwaniyas);
    final raw = box.get('list');
    if (raw == null) {
      return List<DiwaniyaInfo>.from(allDiwaniyas);
    }
    final data = List<Map<String, dynamic>>.from(
      (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)),
    );
    return data
        .map(
          (j) => DiwaniyaInfo(
            id: j['id'] as String,
            name: j['name'] as String,
            district: j['district'] as String? ?? '',
            city: j['city'] as String? ?? '',
            managerId: j['managerId'] as String? ?? '',
            color: Color((j['color'] as num).toInt()),
            invitationCode: j['invitationCode'] as String?,
            creatorUserId: j['creatorUserId'] as String?,
            memberCount: _readPositiveInt(j['memberCount']),
          ),
        )
        .toList();
  }

  static Future<void> completeCreatorOnboarding({
    required SubscriptionPlan plan,
  }) async {
    final draft = pendingCreateDraft;
    final current = profile;
    if (draft == null || current == null) {
      return;
    }

    final diwaniyaId = 'd_${DateTime.now().millisecondsSinceEpoch}';
    final info = DiwaniyaInfo(
      id: diwaniyaId,
      name: draft['name'] as String,
      district: draft['district'] as String,
      city: draft['city'] as String,
      managerId: current.userId,
      color: Color((draft['color'] as num).toInt()),
      invitationCode: draft['invitationCode'] as String,
      creatorUserId: current.userId,
      memberCount: 1,
    );

    allDiwaniyas.removeWhere((d) => d.id == diwaniyaId);
    allDiwaniyas.add(info);
    currentDiwaniyaId = diwaniyaId;

    final initials = current.initials;
    diwaniyaMembers[diwaniyaId] = [
      DiwaniyaMember(
        name: current.fullName,
        initials: initials,
        role: 'manager',
        avatarColor: info.color,
        userId: current.userId,
      ),
    ];

    final rawMembers = draft['initialMembers'];
    if (rawMembers is List) {
      for (final memberName in rawMembers) {
        final name = memberName.toString().trim();
        if (name.isEmpty) continue;
        final parts = name.split(' ').where((s) => s.isNotEmpty).toList();
        final mi = parts.length >= 2
            ? '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
            : name.substring(0, 1);
        diwaniyaMembers[diwaniyaId]!.add(
          DiwaniyaMember(
            name: name,
            initials: mi,
            role: 'member',
            avatarColor: info.color,
          ),
        );
      }
    }

    await SubscriptionService.save(
      SubscriptionStatus(
        plan: plan,
        isCreator: true,
        billingStartsAt: DateTime.now(),
        amountSar: _priceFor(plan),
        active: true,
        diwaniyaId: diwaniyaId,
      ),
      diwaniyaId: diwaniyaId,
    );

    addGlobalActivity(
      diwaniyaId,
      'diwaniya_created',
      current.fullName,
      '${current.fullName} أنشأ ${info.name}',
      Icons.celebration_rounded,
      info.color,
    );

    await SessionService.put('membershipCompleted', true);
    await AppRepository.saveSelectedDiwaniya(diwaniyaId);
    await AppRepository.saveDiwaniyas();
    await AppRepository.saveActivities();
    await clearPendingCreateDraft();
  }

  static Future<bool> createDiwaniyaViaApi({
    required SubscriptionPlan plan,
  }) async {
    final draft = pendingCreateDraft;
    final current = profile;
    if (draft == null || current == null) {
      return false;
    }

    final name = (draft['name'] as String?) ?? '';
    final city = (draft['city'] as String?) ?? '';
    final district = (draft['district'] as String?) ?? '';
    final invitationCode = (draft['invitationCode'] as String?) ?? '';
    final colorValue = (draft['color'] as num?)?.toInt();

    try {
      final response = await DiwaniyaApi.create(
        name: name,
        city: city.isEmpty ? null : city,
        invitationCode: invitationCode,
      );

      final serverId = response['id'];
      if (serverId is! String || serverId.isEmpty) {
        throw const ApiException(
          code: ApiErrorCode.parse,
          message: 'Missing id in create response',
        );
      }

      final serverName = (response['name'] as String?) ?? name;
      final serverCity = (response['city'] as String?) ?? city;
      final info = DiwaniyaInfo(
        id: serverId,
        name: serverName,
        district: district,
        city: serverCity,
        managerId: current.userId,
        color: Color(colorValue ?? 0xFF000000),
        invitationCode:
            ((response['invitation_code'] as String?) ?? invitationCode),
        creatorUserId: current.userId,
        memberCount: 1,
      );

      final refreshed = await refreshMembershipsFromServer(
        preferredDiwaniyaId: serverId,
      );
      if (!refreshed) {
        allDiwaniyas.removeWhere((d) => d.id == serverId);
        allDiwaniyas.add(info);
        currentDiwaniyaId = serverId;

        diwaniyaMembers[serverId] = [
          DiwaniyaMember(
            name: current.fullName,
            initials: current.initials,
            role: 'manager',
            avatarColor: info.color,
            userId: current.userId,
          ),
        ];
      }

      await SubscriptionService.save(
        SubscriptionStatus(
          plan: plan,
          isCreator: true,
          billingStartsAt: DateTime.now(),
          amountSar: _priceFor(plan),
          active: true,
          diwaniyaId: serverId,
        ),
        diwaniyaId: serverId,
      );

      addGlobalActivity(
        serverId,
        'diwaniya_created',
        current.fullName,
        '${current.fullName} أنشأ ${info.name}',
        Icons.celebration_rounded,
        info.color,
      );

      await SessionService.put('membershipCompleted', true);
      await AppRepository.saveSelectedDiwaniya(currentDiwaniyaId);
      await AppRepository.saveDiwaniyas();
      await AppRepository.saveActivities();
      await clearPendingCreateDraft();
      return true;
    } on ApiException catch (e, stackTrace) {
      debugPrint('❌ createDiwaniyaViaApi failed: $e');
      debugPrint(
        '❌ status=${e.statusCode} code=${e.code} details=${e.details}',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  static int _priceFor(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.yearly:
        return 294;
      case SubscriptionPlan.monthly:
        return 49;
      case SubscriptionPlan.free:
      case SubscriptionPlan.joined:
        return 0;
    }
  }

  static Future<bool> upgradeCurrentDiwaniyaToPlan({
    required SubscriptionPlan plan,
  }) async {
    final id = currentDiwaniyaId;
    if (id.isEmpty) return false;
    if (plan != SubscriptionPlan.monthly && plan != SubscriptionPlan.yearly) {
      return false;
    }

    final existing = SubscriptionService.forDiwaniya(id);
    final wasCreator = existing?.isCreator ?? false;

    await SubscriptionService.save(
      SubscriptionStatus(
        plan: plan,
        isCreator: wasCreator,
        billingStartsAt: DateTime.now(),
        amountSar: _priceFor(plan),
        active: true,
        diwaniyaId: id,
      ),
      diwaniyaId: id,
    );

    dataVersion.value++;
    return true;
  }

  static Future<bool> joinDiwaniyaByCode(String code) async {
    final current = profile;
    if (current == null) {
      return false;
    }

    final normalized = code.trim().toUpperCase();
    final directory = getLocalDiwaniyaDirectory();
    final target =
        directory.where((d) => d.invitationCode == normalized).firstOrNull;

    if (target == null) {
      return false;
    }

    final list = diwaniyaMembers[target.id] ?? <DiwaniyaMember>[];
    final exists = list.any((m) => m.name == current.fullName);

    final alreadyVisible = allDiwaniyas.any((d) => d.id == target.id);
    if (!alreadyVisible) {
      allDiwaniyas.add(target);
    }
    currentDiwaniyaId = target.id;

    if (!exists) {
      list.add(
        DiwaniyaMember(
          name: current.fullName,
          initials: current.initials,
          role: 'member',
          avatarColor: target.color,
          userId: current.userId,
        ),
      );
      diwaniyaMembers[target.id] = list;
    }

    await SubscriptionService.save(
      SubscriptionStatus(
        plan: SubscriptionPlan.joined,
        isCreator: false,
        amountSar: 0,
        active: true,
        diwaniyaId: target.id,
      ),
      diwaniyaId: target.id,
    );

    addGlobalActivity(
      target.id,
      'member_joined',
      current.fullName,
      '${current.fullName} انضم إلى ${target.name}',
      Icons.group_add_rounded,
      target.color,
    );
    addGlobalNotification(
      target.id,
      '${current.fullName} انضم إلى الديوانية',
      'members',
      Icons.group_add_rounded,
      target.color,
    );

    await SessionService.put('membershipCompleted', true);
    await AppRepository.saveSelectedDiwaniya(target.id);
    await AppRepository.saveDiwaniyas();
    await AppRepository.saveActivities();
    await AppRepository.saveNotifications();

    return true;
  }

  static Future<bool> joinDiwaniyaByCodeViaApi(String code) async {
    final current = profile;
    if (current == null) {
      return false;
    }

    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      return false;
    }

    try {
      final response = await DiwaniyaApi.acceptInvite(normalized);

      final serverId = response['diwaniya_id'];
      if (serverId is! String || serverId.isEmpty) {
        throw const ApiException(
          code: ApiErrorCode.parse,
          message: 'Missing diwaniya_id in acceptInvite response',
        );
      }

      final existing = allDiwaniyas.where((d) => d.id == serverId).firstOrNull;
      final target = existing ??
          DiwaniyaInfo(
            id: serverId,
            name: 'ديوانية',
            district: '',
            city: '',
            managerId: '',
            color: const Color(0xFF2E7D8C),
            invitationCode: normalized,
            creatorUserId: '',
            memberCount: 0,
          );

      final refreshed = await refreshMembershipsFromServer(
        preferredDiwaniyaId: serverId,
      );
      if (!refreshed) {
        final alreadyVisible = allDiwaniyas.any((d) => d.id == serverId);
        if (!alreadyVisible) {
          allDiwaniyas.add(target);
        }
        currentDiwaniyaId = serverId;

        final list = diwaniyaMembers[serverId] ?? <DiwaniyaMember>[];
        final alreadyMember = list.any((m) => m.name == current.fullName);
        if (!alreadyMember) {
          list.add(
            DiwaniyaMember(
              name: current.fullName,
              initials: current.initials,
              role: 'member',
              avatarColor: target.color,
              userId: current.userId,
            ),
          );
          diwaniyaMembers[serverId] = list;
        }
      }

      await SubscriptionService.save(
        SubscriptionStatus(
          plan: SubscriptionPlan.joined,
          isCreator: false,
          amountSar: 0,
          active: true,
          diwaniyaId: serverId,
        ),
        diwaniyaId: serverId,
      );

      addGlobalActivity(
        serverId,
        'member_joined',
        current.fullName,
        '${current.fullName} انضم إلى ${target.name}',
        Icons.group_add_rounded,
        target.color,
      );
      addGlobalNotification(
        serverId,
        '${current.fullName} انضم إلى الديوانية',
        'members',
        Icons.group_add_rounded,
        target.color,
      );

      await SessionService.put('membershipCompleted', true);
      await AppRepository.saveSelectedDiwaniya(currentDiwaniyaId);
      await AppRepository.saveDiwaniyas();
      await AppRepository.saveActivities();
      await AppRepository.saveNotifications();
      return true;
    } on ApiException {
      return joinDiwaniyaByCode(code);
    }
  }

  static Future<bool> syncCurrentDiwaniyaFromApi() async {
    final id = currentDiwaniyaId;
    if (id.isEmpty) return false;

    try {
      final results = await Future.wait<dynamic>([
        DiwaniyaApi.getById(id),
        DiwaniyaApi.getMembers(id),
      ]);
      final detailResponse = results[0] as Map<String, dynamic>;
      final memberResponse = results[1] as List<Map<String, dynamic>>;

      final existing = allDiwaniyas.where((d) => d.id == id).firstOrNull;
      final mergedName =
          (detailResponse['name'] as String?) ?? existing?.name ?? 'ديوانية';
      final mergedCity =
          (detailResponse['city'] as String?) ?? existing?.city ?? '';
      final merged = DiwaniyaInfo(
        id: id,
        name: mergedName,
        district: existing?.district ?? '',
        city: mergedCity,
        managerId: existing?.managerId ?? '',
        color: existing?.color ?? const Color(0xFF2E7D8C),
        invitationCode: existing?.invitationCode,
        creatorUserId: existing?.creatorUserId ?? '',
        memberCount: memberResponse.length,
      );
      allDiwaniyas.removeWhere((d) => d.id == id);
      allDiwaniyas.add(merged);

      final mapped = memberResponse.map((m) {
        final rawDisplayName = ((m['display_name'] as String?) ?? '').trim();
        final rawUserId = ((m['user_id'] as String?) ?? '').trim();
        final localSelfName = displayName.trim();

        final effectiveDisplayName = rawDisplayName.isNotEmpty
            ? rawDisplayName
            : (rawUserId == currentUserId && localSelfName.isNotEmpty
                ? localSelfName
                : 'عضو');

        final roleTypesRaw = m['role_types'];
        final roleTypes = roleTypesRaw is List
            ? roleTypesRaw.map((e) => e.toString()).toList()
            : const <String>[];

        final isElevated = roleTypes.contains('manager') ||
            roleTypes.contains('founder') ||
            roleTypes.contains('billing_owner');

        return DiwaniyaMember(
          name: effectiveDisplayName,
          initials: _initialsFor(effectiveDisplayName),
          role: isElevated ? 'manager' : 'member',
          avatarColor: merged.color,
          userId: rawUserId.isNotEmpty ? rawUserId : null,
        );
      }).toList();

      diwaniyaMembers[id] = mapped;

      await AppRepository.saveDiwaniyas();
      dataVersion.value++;
      return true;
    } on ApiException {
      return false;
    }
  }

  static String _initialsFor(String name) {
    final parts = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '؟';
    if (parts.length == 1) return parts.first.substring(0, 1);
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}';
  }

  static Future<bool> updateDiwaniyaViaApi(
    String diwaniyaId, {
    String? name,
    String? city,
    String? district,
  }) async {
    if (diwaniyaId.isEmpty) return false;

    final trimmedName = name?.trim();
    final shouldCallApi = trimmedName != null && trimmedName.isNotEmpty;

    try {
      if (shouldCallApi) {
        await DiwaniyaApi.update(diwaniyaId, name: trimmedName);
      }
      DiwaniyaManagementService.updateDiwaniyaInfo(
        diwaniyaId,
        name: name,
        city: city,
        district: district,
      );
      return true;
    } on ApiException {
      DiwaniyaManagementService.updateDiwaniyaInfo(
        diwaniyaId,
        name: name,
        city: city,
        district: district,
      );
      return false;
    }
  }

  static String nextRoute() {
    if (profile == null) {
      return '/auth';
    }
    if (!otpVerified) {
      return otpRequestedInSession ? '/otp' : '/auth';
    }
    if (pendingCreateDraft != null) {
      return '/diwaniya-access';
    }
    if (!hasDiwaniya) {
      return hasPendingJoinRequest
          ? '/join-request-pending'
          : '/diwaniya-access';
    }
    return '/home';
  }

  static Future<void> markWelcomeSeen() async {
    await SessionService.put('hasSeenWelcomeCurtain', true);
  }

  static Future<void> signOut() async {
    final seenWelcome = SessionService.get<bool>(
          'hasSeenWelcomeCurtain',
          defaultValue: false,
        ) ==
        true;

    await AppRepository.clearAllPersistedDomainData(clearSession: false);
    await SessionService.clear();
    pendingJoinRequests.clear();
    otpRequestedInSession = false;

    if (seenWelcome) {
      await SessionService.put('hasSeenWelcomeCurtain', true);
    }
  }
}
