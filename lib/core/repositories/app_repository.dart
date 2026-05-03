import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../models/album_models.dart';
import '../models/chat_models.dart';
import '../models/expense_models.dart';
import '../models/join_request.dart';
import '../models/mock_data.dart';
import '../models/role_change_request.dart';
import '../services/album_service.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/diwaniya_management_service.dart';
import '../services/expense_service.dart';
import '../services/session_service.dart';
import '../services/subscription_service.dart';
import '../storage/hive_storage.dart';

class AppRepository {
  AppRepository._();

  static Future<void> _syncBoxKeys(
    Box box,
    Iterable<String> expectedKeys,
  ) async {
    final expected = expectedKeys.toSet();
    final existing = box.keys.whereType<String>().toList();

    for (final key in existing) {
      if (!expected.contains(key)) {
        await box.delete(key);
      }
    }
  }

  static void _clearRuntimeState() {
    allDiwaniyas.clear();
    currentDiwaniyaId = '';
    diwaniyaMembers.clear();
    diwaniyaPolls.clear();
    diwaniyaActivities.clear();
    diwaniyaNotifications.clear();
    diwaniyaShoppingItems.clear();
    diwaniyaCustomCategories.clear();
    ExpenseService.expenses.clear();
    ExpenseService.settlements.clear();
    ChatService.messages.clear();
    AlbumService.photos.clear();
    DiwaniyaManagementService.requests.clear();
  }

  static Future<void> saveDiwaniyas() async {
    final box = Hive.box(HiveBoxes.diwaniyas);
    await box.put(
      'list',
      jsonEncode(
        allDiwaniyas
            .map(
              (d) => {
                'id': d.id,
                'name': d.name,
                'district': d.district,
                'city': d.city,
                'managerId': d.managerId,
                'country': d.country,
                if (d.expectedMembers != null) 'expectedMembers': d.expectedMembers,
                'color': d.color.toARGB32(),
                if (d.invitationCode != null) 'invitationCode': d.invitationCode,
                if (d.creatorUserId != null) 'creatorUserId': d.creatorUserId,
                if (d.imagePath != null) 'imagePath': d.imagePath,
              },
            )
            .toList(),
      ),
    );

    final membersBox = Hive.box(HiveBoxes.members);
    await _syncBoxKeys(membersBox, diwaniyaMembers.keys);

    for (final entry in diwaniyaMembers.entries) {
      await membersBox.put(
        entry.key,
        jsonEncode(
          entry.value
              .map(
                (m) => {
                  'name': m.name,
                  'initials': m.initials,
                  'role': m.role,
                  'color': m.avatarColor.toARGB32(),
                  if (m.joinedAt != null) 'joinedAt': m.joinedAt!.toIso8601String(),
                },
              )
              .toList(),
        ),
      );
    }
  }

  static Future<void> saveExpenses() async {
    final expensesBox = Hive.box(HiveBoxes.expenses);
    await _syncBoxKeys(expensesBox, ExpenseService.expenses.keys);

    for (final entry in ExpenseService.expenses.entries) {
      await expensesBox.put(
        entry.key,
        jsonEncode(entry.value.map((e) => e.toJson()).toList()),
      );
    }

    final settlementsBox = Hive.box(HiveBoxes.settlements);
    await _syncBoxKeys(settlementsBox, ExpenseService.settlements.keys);

    for (final entry in ExpenseService.settlements.entries) {
      await settlementsBox.put(
        entry.key,
        jsonEncode(entry.value.map((s) => s.toJson()).toList()),
      );
    }
  }

  static Future<void> saveShoppingItems() async {
    final box = Hive.box(HiveBoxes.shoppingItems);
    await _syncBoxKeys(box, diwaniyaShoppingItems.keys);

    for (final entry in diwaniyaShoppingItems.entries) {
      await box.put(
        entry.key,
        jsonEncode(
          entry.value
              .map(
                (i) => {
                  'id': i.id,
                  'name': i.name,
                  'category': i.category,
                  'status': i.status,
                  'updatedBy': i.updatedBy,
                  'note': i.note,
                  'icon': i.icon.codePoint,
                  if (i.updatedAt != null)
                    'updatedAt': i.updatedAt!.toIso8601String(),
                },
              )
              .toList(),
        ),
      );
    }
  }

  static Future<void> saveCustomCategories() async {
    final box = Hive.box(HiveBoxes.customCategories);
    await _syncBoxKeys(box, diwaniyaCustomCategories.keys);

    for (final entry in diwaniyaCustomCategories.entries) {
      await box.put(entry.key, jsonEncode(entry.value));
    }
  }

  static Future<void> savePolls() async {
    final box = Hive.box(HiveBoxes.polls);
    await _syncBoxKeys(box, diwaniyaPolls.keys);

    for (final entry in diwaniyaPolls.entries) {
      await box.put(
        entry.key,
        jsonEncode(
          entry.value
              .map(
                (p) => {
                  'id': p.id,
                  'question': p.question,
                  'diwaniyaId': p.diwaniyaId,
                  'createdBy': p.createdBy,
                  'options': p.options,
                  'votesPerOption': p.votesPerOption,
                  'votedMembers': p.votedMembers,
                  'totalMembers': p.totalMembers,
                  'isActive': p.isActive,
                  'createdAt': p.createdAt.toIso8601String(),
                  if (p.closedAt != null)
                    'closedAt': p.closedAt!.toIso8601String(),
                },
              )
              .toList(),
        ),
      );
    }
  }

  static Future<void> saveActivities() async {
    final box = Hive.box(HiveBoxes.activities);
    await _syncBoxKeys(box, diwaniyaActivities.keys);

    for (final entry in diwaniyaActivities.entries) {
      await box.put(
        entry.key,
        jsonEncode(
          entry.value
              .map(
                (a) => {
                  'type': a.type,
                  'diwaniyaId': a.diwaniyaId,
                  'actor': a.actor,
                  'message': a.message,
                  'createdAt': a.createdAt.toIso8601String(),
                  'icon': a.icon.codePoint,
                  'iconColor': a.iconColor.toARGB32(),
                },
              )
              .toList(),
        ),
      );
    }
  }

  static Future<void> saveNotifications() async {
    final box = Hive.box(HiveBoxes.notifications);
    await _syncBoxKeys(box, diwaniyaNotifications.keys);

    for (final entry in diwaniyaNotifications.entries) {
      await box.put(
        entry.key,
        jsonEncode(
          entry.value
              .map(
                (n) => {
                  'id': n.id,
                  'diwaniyaId': n.diwaniyaId,
                  'message': n.message,
                  'type': n.type,
                  'createdAt': n.createdAt.toIso8601String(),
                  'isRead': n.isRead,
                  'icon': n.icon.codePoint,
                  'iconColor': n.iconColor.toARGB32(),
                  if (n.referenceId != null) 'referenceId': n.referenceId,
                },
              )
              .toList(),
        ),
      );
    }
  }

  static Future<void> saveChat() async {
    final box = Hive.box(HiveBoxes.chat);
    await _syncBoxKeys(box, ChatService.messages.keys);

    for (final entry in ChatService.messages.entries) {
      await box.put(
        entry.key,
        jsonEncode(entry.value.map((m) => m.toJson()).toList()),
      );
    }
  }

  static Future<void> saveAlbum() async {
    final box = Hive.box(HiveBoxes.album);
    await _syncBoxKeys(box, AlbumService.photos.keys);

    for (final entry in AlbumService.photos.entries) {
      await box.put(
        entry.key,
        jsonEncode(entry.value.map((p) => p.toJson()).toList()),
      );
    }
  }

  static Future<void> saveRoleChangeRequests() async {
    final box = Hive.box(HiveBoxes.roleChangeRequests);
    await _syncBoxKeys(box, DiwaniyaManagementService.requests.keys);

    for (final entry in DiwaniyaManagementService.requests.entries) {
      await box.put(
        entry.key,
        jsonEncode(entry.value.map((r) => r.toJson()).toList()),
      );
    }
  }


  static Future<void> restoreSessionSelectionOnly() async {
    _clearRuntimeState();
    final sessionBox = Hive.box(HiveBoxes.session);
    currentDiwaniyaId =
        sessionBox.get('selectedDiwaniya', defaultValue: '') as String;
    dataVersion.value++;
  }

  static Future<void> saveJoinRequests() async {
    final box = Hive.box(HiveBoxes.session);
    await box.put(
      'pendingJoinRequests',
      jsonEncode(
        AuthService.pendingJoinRequests.map((r) => r.toJson()).toList(),
      ),
    );
  }

  static Future<void> loadJoinRequests() async {
    final box = Hive.box(HiveBoxes.session);
    final raw = box.get('pendingJoinRequests');
    AuthService.pendingJoinRequests.clear();
    if (raw == null) {
      return;
    }
    final decoded = jsonDecode(raw as String) as List;
    AuthService.pendingJoinRequests.addAll(
      decoded.map(
        (j) => JoinRequest.fromJson(Map<String, dynamic>.from(j)),
      ),
    );
  }

  static Future<void> saveSelectedDiwaniya(String id) async {
    if (currentDiwaniyaId == id) return;
    currentDiwaniyaId = id;
    await Hive.box(HiveBoxes.session).put('selectedDiwaniya', id);
    dataVersion.value++;
  }

  static Future<void> saveAll() async {
    await saveDiwaniyas();
    await saveExpenses();
    await saveShoppingItems();
    await saveCustomCategories();
    await savePolls();
    await saveActivities();
    await saveNotifications();
    await saveChat();
    await saveAlbum();
    await saveRoleChangeRequests();
  }

  static Future<void> restoreAll() async {
    _clearRuntimeState();

    await _restoreDiwaniyas();
    await _restoreExpenses();
    await _restoreShoppingItems();
    await _restoreCustomCategories();
    await _restorePolls();
    await _restoreActivities();
    await _restoreNotifications();
    await _restoreChat();
    await _restoreAlbum();
    await _restoreRoleChangeRequests();
  }

  static Future<void> _restoreDiwaniyas() async {
    final box = Hive.box(HiveBoxes.diwaniyas);
    final raw = box.get('list');
    if (raw != null) {
      for (final j in (jsonDecode(raw) as List)) {
        allDiwaniyas.add(
          DiwaniyaInfo(
            id: j['id'],
            name: j['name'],
            district: j['district'] ?? '',
            city: j['city'] ?? '',
            managerId: j['managerId'] ?? '',
            country: j['country'] ?? 'السعودية',
            expectedMembers: (j['expectedMembers'] as num?)?.toInt(),
            color: Color((j['color'] as num).toInt()),
            invitationCode: j['invitationCode'] as String?,
            creatorUserId: j['creatorUserId'] as String?,
            imagePath: j['imagePath'] as String?,
          ),
        );
      }
    }

    final sessionBox = Hive.box(HiveBoxes.session);
    currentDiwaniyaId =
        sessionBox.get('selectedDiwaniya', defaultValue: '') as String;

    if (currentDiwaniyaId.isEmpty && allDiwaniyas.isNotEmpty) {
      currentDiwaniyaId = allDiwaniyas.first.id;
    }

    final membersBox = Hive.box(HiveBoxes.members);
    for (final key in membersBox.keys.whereType<String>()) {
      final membersRaw = membersBox.get(key);
      if (membersRaw == null) {
        continue;
      }

      diwaniyaMembers[key] = (jsonDecode(membersRaw) as List)
          .map(
            (j) => DiwaniyaMember(
              name: j['name'],
              initials: j['initials'],
              role: j['role'],
              avatarColor: Color((j['color'] as num).toInt()),
              joinedAt: j['joinedAt'] != null ? DateTime.parse(j['joinedAt'] as String) : null,
            ),
          )
          .toList();
    }
  }

  static Future<void> _restoreExpenses() async {
    final expensesBox = Hive.box(HiveBoxes.expenses);
    for (final key in expensesBox.keys.whereType<String>()) {
      final raw = expensesBox.get(key);
      if (raw == null) {
        continue;
      }

      ExpenseService.expenses[key] = (jsonDecode(raw) as List)
          .map((j) => Expense.fromJson(Map<String, dynamic>.from(j)))
          .toList();
    }

    final settlementsBox = Hive.box(HiveBoxes.settlements);
    for (final key in settlementsBox.keys.whereType<String>()) {
      final raw = settlementsBox.get(key);
      if (raw == null) {
        continue;
      }

      ExpenseService.settlements[key] = (jsonDecode(raw) as List)
          .map((j) => Settlement.fromJson(Map<String, dynamic>.from(j)))
          .toList();
    }
  }

  static Future<void> _restoreShoppingItems() async {
    final box = Hive.box(HiveBoxes.shoppingItems);
    for (final key in box.keys.whereType<String>()) {
      final raw = box.get(key);
      if (raw == null) {
        continue;
      }

      diwaniyaShoppingItems[key] = (jsonDecode(raw) as List)
          .map(
            (j) => MockShoppingItem(
              id: j['id'],
              name: j['name'],
              category: j['category'],
              status: j['status'],
              updatedBy: j['updatedBy'],
              note: j['note'],
              updatedAt: j['updatedAt'] != null
                  ? DateTime.parse(j['updatedAt'])
                  : null,
              icon: IconData(
                j['icon'] as int,
                fontFamily: 'MaterialIcons',
              ),
            ),
          )
          .toList();
    }
  }

  static Future<void> _restoreCustomCategories() async {
    final box = Hive.box(HiveBoxes.customCategories);
    for (final key in box.keys.whereType<String>()) {
      final raw = box.get(key);
      if (raw == null) {
        continue;
      }
      diwaniyaCustomCategories[key] =
          List<String>.from(jsonDecode(raw) as List);
    }
  }

  static Future<void> _restorePolls() async {
    final box = Hive.box(HiveBoxes.polls);
    for (final key in box.keys.whereType<String>()) {
      final raw = box.get(key);
      if (raw == null) {
        continue;
      }

      diwaniyaPolls[key] = (jsonDecode(raw) as List)
          .map(
            (j) => DiwaniyaPoll(
              id: j['id'],
              question: j['question'],
              diwaniyaId: j['diwaniyaId'],
              createdBy: j['createdBy'],
              options: List<String>.from(j['options']),
              votesPerOption: Map<String, int>.from(
                (j['votesPerOption'] as Map).map(
                  (k, v) => MapEntry(k.toString(), (v as num).toInt()),
                ),
              ),
              votedMembers: Map<String, String>.from(j['votedMembers'] ?? {}),
              totalMembers: j['totalMembers'],
              isActive: j['isActive'],
              createdAt: DateTime.parse(j['createdAt']),
              closedAt: j['closedAt'] != null
                  ? DateTime.parse(j['closedAt'])
                  : null,
            ),
          )
          .toList();
    }
  }

  static Future<void> _restoreActivities() async {
    final box = Hive.box(HiveBoxes.activities);
    for (final key in box.keys.whereType<String>()) {
      final raw = box.get(key);
      if (raw == null) {
        continue;
      }

      diwaniyaActivities[key] = (jsonDecode(raw) as List)
          .map(
            (j) => DiwaniyaActivity(
              type: j['type'],
              diwaniyaId: j['diwaniyaId'],
              actor: j['actor'],
              message: j['message'],
              createdAt: DateTime.parse(j['createdAt']),
              icon: IconData(
                j['icon'] as int,
                fontFamily: 'MaterialIcons',
              ),
              iconColor: Color(j['iconColor'] as int),
            ),
          )
          .toList();
    }
  }

  static Future<void> _restoreNotifications() async {
    final box = Hive.box(HiveBoxes.notifications);
    for (final key in box.keys.whereType<String>()) {
      final raw = box.get(key);
      if (raw == null) {
        continue;
      }

      diwaniyaNotifications[key] = (jsonDecode(raw) as List)
          .map(
            (j) => DiwaniyaNotification(
              id: j['id'],
              diwaniyaId: j['diwaniyaId'],
              message: j['message'],
              type: j['type'],
              createdAt: DateTime.parse(j['createdAt']),
              isRead: j['isRead'] ?? false,
              icon: IconData(
                j['icon'] as int,
                fontFamily: 'MaterialIcons',
              ),
              iconColor: Color(j['iconColor'] as int),
              referenceId: j['referenceId'],
            ),
          )
          .toList();
    }
  }

  static Future<void> _restoreChat() async {
    final box = Hive.box(HiveBoxes.chat);
    for (final key in box.keys.whereType<String>()) {
      final raw = box.get(key);
      if (raw == null) {
        continue;
      }

      final list = (jsonDecode(raw) as List)
          .map((j) => ChatMessage.fromJson(Map<String, dynamic>.from(j)))
          .toList();

      ChatService.restore(key, list);
    }
  }

  static Future<void> _restoreAlbum() async {
    final box = Hive.box(HiveBoxes.album);
    for (final key in box.keys.whereType<String>()) {
      final raw = box.get(key);
      if (raw == null) {
        continue;
      }

      final list = (jsonDecode(raw) as List)
          .map((j) => AlbumPhoto.fromJson(Map<String, dynamic>.from(j)))
          .toList();

      AlbumService.restore(key, list);
    }
  }

  static Future<void> _restoreRoleChangeRequests() async {
    final box = Hive.box(HiveBoxes.roleChangeRequests);
    for (final key in box.keys.whereType<String>()) {
      final raw = box.get(key);
      if (raw == null) {
        continue;
      }

      final list = (jsonDecode(raw) as List)
          .map(
            (j) => RoleChangeRequest.fromJson(
              Map<String, dynamic>.from(j),
            ),
          )
          .toList();

      DiwaniyaManagementService.restore(key, list);
    }
  }

  /// Remove all local data for a single diwaniya.
  static Future<void> clearDiwaniyaData(String diwaniyaId) async {
    // Remove from runtime
    allDiwaniyas.removeWhere((d) => d.id == diwaniyaId);
    diwaniyaMembers.remove(diwaniyaId);
    diwaniyaPolls.remove(diwaniyaId);
    diwaniyaActivities.remove(diwaniyaId);
    diwaniyaNotifications.remove(diwaniyaId);
    diwaniyaShoppingItems.remove(diwaniyaId);
    diwaniyaCustomCategories.remove(diwaniyaId);
    ExpenseService.expenses.remove(diwaniyaId);
    ExpenseService.settlements.remove(diwaniyaId);
    ChatService.messages.remove(diwaniyaId);
    AlbumService.photos.remove(diwaniyaId);
    DiwaniyaManagementService.requests.remove(diwaniyaId);

    // Remove from Hive boxes (per-key)
    await Hive.box(HiveBoxes.members).delete(diwaniyaId);
    await Hive.box(HiveBoxes.expenses).delete(diwaniyaId);
    await Hive.box(HiveBoxes.settlements).delete(diwaniyaId);
    await Hive.box(HiveBoxes.shoppingItems).delete(diwaniyaId);
    await Hive.box(HiveBoxes.customCategories).delete(diwaniyaId);
    await Hive.box(HiveBoxes.polls).delete(diwaniyaId);
    await Hive.box(HiveBoxes.activities).delete(diwaniyaId);
    await Hive.box(HiveBoxes.notifications).delete(diwaniyaId);
    await Hive.box(HiveBoxes.chat).delete(diwaniyaId);
    await Hive.box(HiveBoxes.album).delete(diwaniyaId);
    await Hive.box(HiveBoxes.roleChangeRequests).delete(diwaniyaId);

    // Clear per-diwaniya subscription
    await SessionService.put('sub_$diwaniyaId', null);
    await SubscriptionService.removeForCurrentUser(diwaniyaId);

    // Re-save diwaniyas list
    await saveDiwaniyas();

    // Update selected diwaniya
    if (currentDiwaniyaId == diwaniyaId) {
      currentDiwaniyaId = allDiwaniyas.isNotEmpty ? allDiwaniyas.first.id : '';
      await saveSelectedDiwaniya(currentDiwaniyaId);
    }

    dataVersion.value++;
  }

  static Future<void> clearAllPersistedDomainData({bool clearSession = true}) async {
    if (clearSession) {
      await Hive.box(HiveBoxes.session).clear();
    } else {
      await Hive.box(HiveBoxes.session).delete('pendingJoinRequests');
      await Hive.box(HiveBoxes.session).delete('selectedDiwaniya');
    }
    await Hive.box(HiveBoxes.diwaniyas).clear();
    await Hive.box(HiveBoxes.members).clear();
    await Hive.box(HiveBoxes.expenses).clear();
    await Hive.box(HiveBoxes.settlements).clear();
    await Hive.box(HiveBoxes.shoppingItems).clear();
    await Hive.box(HiveBoxes.customCategories).clear();
    await Hive.box(HiveBoxes.polls).clear();
    await Hive.box(HiveBoxes.activities).clear();
    await Hive.box(HiveBoxes.notifications).clear();
    await Hive.box(HiveBoxes.chat).clear();
    await Hive.box(HiveBoxes.album).clear();
    await Hive.box(HiveBoxes.roleChangeRequests).clear();

    _clearRuntimeState();
    dataVersion.value++;
  }
}