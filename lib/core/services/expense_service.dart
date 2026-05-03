import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../api/endpoints.dart';
import '../models/expense_models.dart';
import '../models/mock_data.dart';
import '../repositories/app_repository.dart';

/// Backend-authoritative orchestration layer for expenses + settlements.
///
/// Source of truth:
/// - Backend for shared domain data.
/// - Local maps remain runtime/UI cache only.
///
/// Notes:
/// - Categories remain local until their own backend slice lands.
/// - Activity + notification entries are still generated client-side for now.
class ExpenseService {
  ExpenseService._();

  static final Map<String, List<Expense>> expenses = <String, List<Expense>>{};
  static final Map<String, List<Settlement>> settlements =
      <String, List<Settlement>>{};
  static final Map<String, List<ExpenseCategory>> categories =
      <String, List<ExpenseCategory>>{};

  static final Set<String> _syncInFlight = <String>{};

  static String get _currentDid => currentDiwaniyaId;

  static List<Expense> forDiwaniya(String diwaniyaId) =>
      expenses[diwaniyaId] ??= <Expense>[];

  static List<Settlement> settlementsForDiwaniya(String diwaniyaId) =>
      settlements[diwaniyaId] ??= <Settlement>[];

  static const Set<String> _hiddenLegacyCategories = <String>{
    'لوازم الكيف',
    'راتب العامل',
    'راتب عامل',
    'أخرى',
  };

  static final List<ExpenseCategory> _approvedDefaultCategories =
      defaultExpenseCategories
          .where((category) => !_hiddenLegacyCategories.contains(category.name.trim()))
          .toList();

  static List<ExpenseCategory> categoriesForDiwaniya(String diwaniyaId) {
    final list = categories[diwaniyaId] ??= List<ExpenseCategory>.from(
      _approvedDefaultCategories,
    );

    list.removeWhere(
      (category) => _hiddenLegacyCategories.contains(category.name.trim()),
    );

    final seen = <String>{};
    final cleaned = <ExpenseCategory>[];

    for (final category in list) {
      final name = category.name.trim();
      if (name.isEmpty || _hiddenLegacyCategories.contains(name)) continue;
      if (seen.add(name)) cleaned.add(category);
    }

    for (final expense in forDiwaniya(diwaniyaId)) {
      final name = expense.category.trim();
      if (name.isEmpty || _hiddenLegacyCategories.contains(name)) continue;
      if (seen.add(name)) {
        cleaned.add(
          ExpenseCategory(
            name: name,
            icon: Icons.label_rounded,
            color: const Color(0xFF9CA3AF),
          ),
        );
      }
    }

    categories[diwaniyaId] = cleaned;
    return cleaned;
  }

  static List<Expense> get current => forDiwaniya(_currentDid);
  static List<Settlement> get currentSettlements =>
      settlementsForDiwaniya(_currentDid);
  static List<ExpenseCategory> get currentCategories =>
      categoriesForDiwaniya(_currentDid);

  static List<Expense> activeExpenses([String? diwaniyaId]) {
    final did = diwaniyaId ?? _currentDid;
    return forDiwaniya(did).where((e) => e.cancelledBy == null).toList();
  }

  static double totalMonth([String? diwaniyaId]) =>
      activeExpenses(diwaniyaId).fold(0.0, (s, e) => s + e.amount);

  static double totalSettled([String? diwaniyaId]) {
    final did = diwaniyaId ?? _currentDid;
    return settlementsForDiwaniya(did).fold(0.0, (s, e) => s + e.amount);
  }

  static double totalUnpaid([String? diwaniyaId]) =>
      max(0, totalMonth(diwaniyaId) - totalSettled(diwaniyaId));

  static Future<void> syncForDiwaniya(
    String diwaniyaId, {
    bool force = false,
  }) async {
    if (diwaniyaId.trim().isEmpty) return;
    if (!force && _syncInFlight.contains(diwaniyaId)) return;

    _syncInFlight.add(diwaniyaId);
    try {
      final expensesResponse = await ApiClient.get(
        Endpoints.diwaniyaExpenses(diwaniyaId),
      );
      final settlementsResponse = await ApiClient.get(
        Endpoints.diwaniyaSettlements(diwaniyaId),
      );

      final decodedExpenses =
          (expensesResponse['expenses'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map>()
              .map(
                (raw) => Expense.fromJson(
                  _normalizeExpenseJson(Map<String, dynamic>.from(raw)),
                ),
              )
              .toList();

      final decodedSettlements =
          (settlementsResponse['settlements'] as List<dynamic>? ??
                  const <dynamic>[])
              .whereType<Map>()
              .map(
                (raw) => Settlement.fromJson(
                  _normalizeSettlementJson(Map<String, dynamic>.from(raw)),
                ),
              )
              .toList();

      expenses[diwaniyaId] = decodedExpenses;
      settlements[diwaniyaId] = decodedSettlements;
      dataVersion.value++;
      await AppRepository.saveExpenses();
    } finally {
      _syncInFlight.remove(diwaniyaId);
    }
  }

  static Future<Expense> createExpense(
    Expense expense, {
    String? diwaniyaId,
  }) async {
    final did = diwaniyaId ?? _currentDid;
    final response = await ApiClient.post(
      Endpoints.diwaniyaExpenses(did),
      body: {
        'title': expense.title,
        'payer': expense.payer,
        'category': expense.category,
        'split_type': expense.splitType,
        'amount': expense.amount,
        'shares': expense.shares,
        'note': expense.note,
        'receipt_path': expense.receiptPath,
      },
    );

    final created = Expense.fromJson(
      _normalizeExpenseJson(Map<String, dynamic>.from(response)),
    );
    final list = forDiwaniya(did);
    list.removeWhere((e) => e.id == created.id);
    list.insert(0, created);

    _addActivity(
      did,
      'expense_added',
      created.payer,
      '${created.payer} أضاف مصروف — ${created.title} ${created.amount.toInt()} ر.س',
      Icons.receipt_long_rounded,
      const Color(0xFF2DD4A8),
    );
    _addNotification(
      did,
      '${created.payer} أضاف مصروف — ${created.title} ${created.amount.toInt()} ر.س',
      'expense',
      Icons.receipt_long_rounded,
      const Color(0xFF2DD4A8),
    );

    dataVersion.value++;
    await AppRepository.saveExpenses();
    return created;
  }

  static Future<Expense> editExpense(
    String expenseId,
    Expense updated, {
    required String actor,
    String? diwaniyaId,
  }) async {
    final did = diwaniyaId ?? _currentDid;
    final response = await ApiClient.patch(
      Endpoints.diwaniyaExpense(did, expenseId),
      body: {
        'title': updated.title,
        'payer': updated.payer,
        'category': updated.category,
        'split_type': updated.splitType,
        'amount': updated.amount,
        'shares': updated.shares,
        'note': updated.note,
        'receipt_path': updated.receiptPath,
      },
    );

    final fresh = Expense.fromJson(
      _normalizeExpenseJson(Map<String, dynamic>.from(response)),
    );
    final list = forDiwaniya(did);
    final index = list.indexWhere((e) => e.id == expenseId);
    if (index >= 0) {
      list[index] = fresh;
    } else {
      list.insert(0, fresh);
    }

    _addActivity(
      did,
      'expense_edited',
      actor,
      '$actor عدّل مصروف — ${fresh.title}',
      Icons.edit_rounded,
      const Color(0xFFFB923C),
    );

    dataVersion.value++;
    await AppRepository.saveExpenses();
    return fresh;
  }

  static Future<Expense> deleteExpense(
    String expenseId, {
    required String actor,
    String? diwaniyaId,
  }) async {
    final did = diwaniyaId ?? _currentDid;
    final response = await ApiClient.delete(
      Endpoints.diwaniyaExpense(did, expenseId),
    );

    final fresh = Expense.fromJson(
      _normalizeExpenseJson(Map<String, dynamic>.from(response)),
    );
    final list = forDiwaniya(did);
    final index = list.indexWhere((e) => e.id == expenseId);
    if (index >= 0) {
      list[index] = fresh;
    } else {
      list.insert(0, fresh);
    }

    _addActivity(
      did,
      'expense_deleted',
      actor,
      '$actor ألغى مصروف — ${fresh.title}',
      Icons.delete_rounded,
      const Color(0xFFF87171),
    );

    dataVersion.value++;
    await AppRepository.saveExpenses();
    return fresh;
  }

  static Future<Settlement> addSettlement(
    String from,
    String to,
    double amount, {
    String? diwaniyaId,
  }) async {
    final did = diwaniyaId ?? _currentDid;
    final response = await ApiClient.post(
      Endpoints.diwaniyaSettlements(did),
      body: {
        'from_name': from,
        'to_name': to,
        'amount': amount,
      },
    );

    final settlement = Settlement.fromJson(
      _normalizeSettlementJson(Map<String, dynamic>.from(response)),
    );
    settlementsForDiwaniya(did).insert(0, settlement);

    _addActivity(
      did,
      'settlement',
      from,
      '$from سوّى تسوية — ${amount.toInt()} ر.س لـ $to',
      Icons.handshake_rounded,
      const Color(0xFF34D399),
    );
    _addNotification(
      did,
      '$from سدّد ${amount.toInt()} ر.س لـ $to',
      'settlement',
      Icons.handshake_rounded,
      const Color(0xFF34D399),
    );

    dataVersion.value++;
    await AppRepository.saveExpenses();
    return settlement;
  }

  static Future<Settlement> confirmSettlement(
    String settlementId, {
    String? diwaniyaId,
  }) async {
    final did = diwaniyaId ?? _currentDid;
    final response = await ApiClient.post(
      Endpoints.diwaniyaSettlementConfirm(did, settlementId),
    );

    final confirmed = Settlement.fromJson(
      _normalizeSettlementJson(Map<String, dynamic>.from(response)),
    );

    final list = settlementsForDiwaniya(did);
    final index = list.indexWhere((s) => s.id == settlementId);
    if (index >= 0) {
      list[index] = confirmed;
    } else {
      list.insert(0, confirmed);
    }

    dataVersion.value++;
    await AppRepository.saveExpenses();
    return confirmed;
  }

  static void addCategory(
    ExpenseCategory category, {
    String? diwaniyaId,
  }) {
    final did = diwaniyaId ?? _currentDid;
    final name = category.name.trim();
    if (name.isEmpty || _hiddenLegacyCategories.contains(name)) return;

    final list = categoriesForDiwaniya(did);
    final exists = list.any((c) => c.name.trim() == name);
    if (exists) return;

    list.add(
      ExpenseCategory(
        name: name,
        icon: category.icon,
        color: category.color,
      ),
    );
    dataVersion.value++;
    AppRepository.saveExpenses();
  }

  static List<Debt> rawDebts([String? diwaniyaId]) {
    final did = diwaniyaId ?? _currentDid;
    final exps = activeExpenses(did);
    final setts = settlementsForDiwaniya(did);
    final net = <String, Map<String, double>>{};

    for (final e in exps) {
      for (final entry in e.shares.entries) {
        net.putIfAbsent(entry.key, () => <String, double>{});
        net[entry.key]![e.payer] = (net[entry.key]![e.payer] ?? 0) + entry.value;
      }
    }

    for (final s in setts) {
      net.putIfAbsent(s.from, () => <String, double>{});
      net[s.from]![s.to] = (net[s.from]![s.to] ?? 0) - s.amount;
    }

    final debts = <Debt>[];
    final seen = <String>{};

    net.forEach((from, tos) {
      tos.forEach((to, amount) {
        final key = [from, to]..sort();
        final canonical = key.join('-');
        if (seen.contains(canonical)) return;

        seen.add(canonical);
        final reverse = net[to]?[from] ?? 0;
        final netAmount = amount - reverse;

        if (netAmount > 0.5) {
          debts.add(Debt(from, to, netAmount));
        } else if (netAmount < -0.5) {
          debts.add(Debt(to, from, netAmount.abs()));
        }
      });
    });

    return debts;
  }

  static List<Debt> optimized([String? diwaniyaId]) =>
      optimizeDebts(rawDebts(diwaniyaId));

  static double balanceFor(String memberName, [String? diwaniyaId]) {
    double balance = 0;
    for (final debt in optimized(diwaniyaId)) {
      if (debt.to == memberName) {
        balance += debt.amount;
      }
      if (debt.from == memberName) {
        balance -= debt.amount;
      }
    }
    return balance;
  }

  static String friendlyMessage(Object error) {
    if (error is ApiException) {
      switch (error.code) {
        case ApiErrorCode.forbidden:
          return error.message.isNotEmpty ? error.message : 'هذه العملية غير متاحة لك';
        case ApiErrorCode.validation:
          return error.message.isNotEmpty ? error.message : 'بيانات المصروف غير صالحة';
        case ApiErrorCode.network:
        case ApiErrorCode.timeout:
          return 'تعذر الاتصال بالخادم';
        default:
          return error.message.isNotEmpty ? error.message : 'تعذر إتمام العملية الآن';
      }
    }
    return 'تعذر إتمام العملية الآن';
  }

  static Map<String, dynamic> _normalizeExpenseJson(Map<String, dynamic> raw) {
    return <String, dynamic>{
      'id': raw['id'],
      'title': raw['title'],
      'payer': raw['payer'] ?? raw['payer_name'],
      'category': raw['category'],
      'splitType': raw['splitType'] ?? raw['split_type'],
      'amount': raw['amount'],
      'shares': raw['shares'] is String
          ? jsonDecode(raw['shares'] as String)
          : raw['shares'],
      'createdAt': raw['createdAt'] ?? raw['created_at'],
      'createdBy': raw['createdBy'] ?? raw['created_by'],
      'updatedBy': raw['updatedBy'] ?? raw['updated_by'],
      'updatedAt': raw['updatedAt'] ?? raw['updated_at'],
      'cancelledBy': raw['cancelledBy'] ?? raw['cancelled_by'],
      'cancelledAt': raw['cancelledAt'] ?? raw['cancelled_at'],
      'note': raw['note'],
      'receiptPath': raw['receiptPath'] ?? raw['receipt_path'],
    };
  }

  static Map<String, dynamic> _normalizeSettlementJson(Map<String, dynamic> raw) {
    return <String, dynamic>{
      'id': raw['id'],
      'from': raw['from'] ?? raw['from_name'],
      'to': raw['to'] ?? raw['to_name'],
      'amount': raw['amount'],
      'date': raw['date'] ?? raw['created_at'],
      'confirmed': raw['confirmed'] ?? false,
      'confirmedBy': raw['confirmed_by'],
      'confirmedAt': raw['confirmed_at'],
    };
  }

  static void _addActivity(
    String did,
    String type,
    String actor,
    String message,
    IconData icon,
    Color color,
  ) {
    addGlobalActivity(did, type, actor, message, icon, color);
    AppRepository.saveActivities();
  }

  static void _addNotification(
    String did,
    String message,
    String type,
    IconData icon,
    Color color,
  ) {
    addGlobalNotification(did, message, type, icon, color);
    AppRepository.saveNotifications();
  }
}
