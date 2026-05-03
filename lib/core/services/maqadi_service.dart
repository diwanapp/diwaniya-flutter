import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../api/endpoints.dart';
import '../models/mock_data.dart';
import '../repositories/app_repository.dart';
import 'user_service.dart';

const maqadiDefaultCategories = <String>[
  'مستلزمات',
];

const maqadiCategoryIcons = <String, IconData>{
  'مستلزمات': Icons.inventory_2_rounded,
  'طلبات خارجية': Icons.delivery_dining_rounded,
  'ترفيه واشتراكات': Icons.sports_esports_rounded,
  'أخرى': Icons.more_horiz_rounded,
};


const maqadiStatusOrder = <String, int>{
  'needed': 0,
  'low': 1,
  'available': 2,
};

enum MaqadiStatus { needed, low, available }

class MaqadiService {
  MaqadiService._();

  static String get currentDiwaniya => currentDiwaniyaId;

  static List<MockShoppingItem> itemsForDiwaniya(String diwaniyaId) =>
      diwaniyaShoppingItems[diwaniyaId] ??= <MockShoppingItem>[];

  static List<String> customCategoriesForDiwaniya(String diwaniyaId) =>
      diwaniyaCustomCategories[diwaniyaId] ??= <String>[];

  static List<String> categoriesForDiwaniya(String diwaniyaId) {
    final seen = <String>{};
    final result = <String>[];
    for (final name in <String>[
      ...maqadiDefaultCategories,
      ...customCategoriesForDiwaniya(diwaniyaId),
    ]) {
      final trimmed = name.trim();
      if (trimmed.isEmpty || seen.contains(trimmed)) continue;
      seen.add(trimmed);
      result.add(trimmed);
    }
    return result;
  }

  static int totalCategoryCount(String diwaniyaId) =>
      maqadiDefaultCategories.length +
      (diwaniyaCustomCategories[diwaniyaId]?.length ?? 0);

  static IconData iconForCategory(String category) =>
      maqadiCategoryIcons[category] ?? Icons.label_rounded;

  static String statusLabel(String status) {
    switch (status) {
      case 'available':
        return 'متوفر';
      case 'low':
        return 'قليل';
      default:
        return 'مطلوب';
    }
  }

  static MockShoppingItem? findItemById(String diwaniyaId, String id) {
    for (final item in itemsForDiwaniya(diwaniyaId)) {
      if (item.id == id) return item;
    }
    return null;
  }

  static Future<void> syncForDiwaniya(
    String diwaniyaId, {
    bool bumpVersion = true,
  }) async {
    if (diwaniyaId.trim().isEmpty) return;

    final itemsRaw = await ApiClient.get(Endpoints.maqadiItems(diwaniyaId));
    final catsRaw = await ApiClient.get(Endpoints.maqadiCategories(diwaniyaId));

    final itemsList = (itemsRaw['items'] as List? ?? const <dynamic>[]);
    final categoriesList =
        (catsRaw['categories'] as List? ?? const <dynamic>[]);

    diwaniyaShoppingItems[diwaniyaId] = itemsList
        .whereType<Map>()
        .map((raw) => _itemFromBackend(Map<String, dynamic>.from(raw)))
        .toList();

    final seenCategories = <String>{};
    diwaniyaCustomCategories[diwaniyaId] = categoriesList
        .whereType<Map>()
        .map((raw) => (raw['name'] as String? ?? '').trim())
        .where((name) {
          if (name.isEmpty || maqadiDefaultCategories.contains(name)) {
            return false;
          }
          if (seenCategories.contains(name)) return false;
          seenCategories.add(name);
          return true;
        })
        .toList();

    await AppRepository.saveShoppingItems();
    await AppRepository.saveCustomCategories();
    if (bumpVersion) dataVersion.value++;
  }

  static Future<void> addBatch(
    String diwaniyaId,
    List<MockShoppingItem> items,
  ) async {
    if (items.isEmpty) return;
    final body = {
      'items': items
          .map((item) => {
                'name': item.name.trim(),
                'category': item.category.trim(),
                'status': item.status.trim(),
                'note': item.note?.trim(),
              })
          .toList(),
    };

    await ApiClient.post(
      Endpoints.maqadiItemsBatch(diwaniyaId),
      body: body,
    );

    await syncForDiwaniya(diwaniyaId);

    for (final item in items) {
      addGlobalActivity(
        diwaniyaId,
        'maqadi_added',
        UserService.currentName,
        '${UserService.currentName} أضاف صنف — ${item.name}',
        Icons.add_shopping_cart_rounded,
        const Color(0xFFFBBF24),
      );

      addGlobalNotification(
        diwaniyaId,
        '${UserService.currentName} أضاف صنف — ${item.name}',
        'maqadi',
        Icons.add_shopping_cart_rounded,
        const Color(0xFFFBBF24),
      );
    }

    await AppRepository.saveActivities();
    await AppRepository.saveNotifications();
  }

  static Future<bool> updateItem(
    String diwaniyaId,
    String id, {
    String? name,
    String? category,
    String? status,
    String? note,
  }) async {
    final current = findItemById(diwaniyaId, id);
    if (current == null) return false;

    await ApiClient.patch(
      Endpoints.maqadiItem(diwaniyaId, id),
      body: {
        'name': (name ?? current.name).trim(),
        'category': (category ?? current.category).trim(),
        'status': (status ?? current.status).trim(),
        'note': note ?? current.note,
      },
    );

    await syncForDiwaniya(diwaniyaId);

    final updated = findItemById(diwaniyaId, id) ?? current;
    if (status != null) {
      final label = statusLabel(updated.status);
      addGlobalActivity(
        diwaniyaId,
        'maqadi_updated',
        UserService.currentName,
        '${UserService.currentName} حدّث ${updated.name} إلى $label',
        Icons.inventory_2_rounded,
        const Color(0xFFFBBF24),
      );
      addGlobalNotification(
        diwaniyaId,
        '${UserService.currentName} حدّث ${updated.name} إلى $label',
        'maqadi',
        Icons.inventory_2_rounded,
        const Color(0xFFFBBF24),
      );
    } else {
      addGlobalActivity(
        diwaniyaId,
        'maqadi_edited',
        UserService.currentName,
        '${UserService.currentName} عدّل صنف — ${updated.name}',
        Icons.edit_rounded,
        const Color(0xFFFB923C),
      );
      addGlobalNotification(
        diwaniyaId,
        '${UserService.currentName} عدّل صنف — ${updated.name}',
        'maqadi',
        Icons.edit_rounded,
        const Color(0xFFFB923C),
      );
    }

    await AppRepository.saveActivities();
    await AppRepository.saveNotifications();
    dataVersion.value++;
    return true;
  }

  static Future<bool> deleteItem(String diwaniyaId, String id) async {
    final item = findItemById(diwaniyaId, id);
    if (item == null) return false;

    await ApiClient.delete(Endpoints.maqadiItem(diwaniyaId, id));
    await syncForDiwaniya(diwaniyaId);

    addGlobalActivity(
      diwaniyaId,
      'maqadi_deleted',
      UserService.currentName,
      '${UserService.currentName} حذف صنف — ${item.name}',
      Icons.delete_rounded,
      const Color(0xFFF87171),
    );
    addGlobalNotification(
      diwaniyaId,
      '${UserService.currentName} حذف صنف — ${item.name}',
      'maqadi',
      Icons.delete_rounded,
      const Color(0xFFF87171),
    );

    await AppRepository.saveActivities();
    await AppRepository.saveNotifications();
    dataVersion.value++;
    return true;
  }

  static Future<bool> addCustomCategory(
    String diwaniyaId,
    String name,
  ) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    if (categoriesForDiwaniya(diwaniyaId).contains(trimmed)) return false;
    if (totalCategoryCount(diwaniyaId) >= 8) return false;

    try {
      await ApiClient.post(
        Endpoints.maqadiCategories(diwaniyaId),
        body: {'name': trimmed},
      );
    } on ApiException catch (e) {
      if (e.code == ApiErrorCode.conflict) {
        await syncForDiwaniya(diwaniyaId);
        return categoriesForDiwaniya(diwaniyaId).contains(trimmed);
      }
      rethrow;
    }

    await syncForDiwaniya(diwaniyaId);
    return categoriesForDiwaniya(diwaniyaId).contains(trimmed);
  }

  static bool categoryHasItems(String diwaniyaId, String category) {
    final trimmed = category.trim();
    if (trimmed.isEmpty) return false;
    return itemsForDiwaniya(diwaniyaId).any((item) => item.category.trim() == trimmed);
  }

  static Future<bool> deleteCustomCategory(
    String diwaniyaId,
    String name,
  ) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    if (maqadiDefaultCategories.contains(trimmed)) return false;
    if (categoryHasItems(diwaniyaId, trimmed)) return false;

    await ApiClient.delete(Endpoints.maqadiCategory(diwaniyaId, trimmed));
    await syncForDiwaniya(diwaniyaId);
    dataVersion.value++;
    return !categoriesForDiwaniya(diwaniyaId).contains(trimmed);
  }

  static MockShoppingItem _itemFromBackend(Map<String, dynamic> raw) {
    final category = (raw['category'] as String? ?? '').trim();
    return MockShoppingItem(
      id: (raw['id'] as String? ?? '').trim(),
      name: (raw['name'] as String? ?? '').trim(),
      category: category,
      status: (raw['status'] as String? ?? 'needed').trim(),
      updatedBy: ((raw['updated_by'] ?? raw['created_by']) as String?)?.trim(),
      updatedAt: DateTime.tryParse(
        ((raw['updated_at'] ?? raw['created_at']) as String?) ?? '',
      ),
      note: (raw['note'] as String?)?.trim(),
      icon: iconForCategory(category),
    );
  }
}
