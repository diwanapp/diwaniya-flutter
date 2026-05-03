import 'dart:math';

class Expense {
  final String id, title, payer, category, splitType;
  final double amount;
  final Map<String, double> shares;
  final DateTime createdAt;
  final String createdBy;
  final String? updatedBy, cancelledBy, note, receiptPath;
  final DateTime? updatedAt, cancelledAt;

  Expense({required this.id, required this.title, required this.payer,
    required this.category, required this.splitType, required this.amount,
    required this.shares, required this.createdAt, required this.createdBy,
    this.updatedBy, this.updatedAt, this.cancelledBy, this.cancelledAt,
    this.note, this.receiptPath});

  bool get hasReceipt => receiptPath != null;

  Expense copyWith({String? title, String? payer, String? category,
      String? splitType, double? amount, Map<String, double>? shares,
      String? updatedBy, DateTime? updatedAt,
      String? cancelledBy, DateTime? cancelledAt,
      String? note, String? receiptPath}) =>
    Expense(id: id, title: title ?? this.title, payer: payer ?? this.payer,
      category: category ?? this.category, splitType: splitType ?? this.splitType,
      amount: amount ?? this.amount, shares: shares ?? this.shares,
      createdAt: createdAt, createdBy: createdBy,
      updatedBy: updatedBy ?? this.updatedBy, updatedAt: updatedAt ?? this.updatedAt,
      cancelledBy: cancelledBy ?? this.cancelledBy, cancelledAt: cancelledAt ?? this.cancelledAt,
      note: note ?? this.note, receiptPath: receiptPath ?? this.receiptPath);

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'payer': payer, 'category': category,
    'splitType': splitType, 'amount': amount,
    'shares': shares, 'createdAt': createdAt.toIso8601String(),
    'createdBy': createdBy,
    if (updatedBy != null) 'updatedBy': updatedBy,
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    if (cancelledBy != null) 'cancelledBy': cancelledBy,
    if (cancelledAt != null) 'cancelledAt': cancelledAt!.toIso8601String(),
    if (note != null) 'note': note,
    if (receiptPath != null) 'receiptPath': receiptPath,
  };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
    id: j['id'], title: j['title'], payer: j['payer'], category: j['category'],
    splitType: j['splitType'], amount: (j['amount'] as num).toDouble(),
    shares: (j['shares'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
    createdAt: DateTime.parse(j['createdAt']), createdBy: j['createdBy'],
    updatedBy: j['updatedBy'], note: j['note'], receiptPath: j['receiptPath'],
    updatedAt: j['updatedAt'] != null ? DateTime.parse(j['updatedAt']) : null,
    cancelledBy: j['cancelledBy'],
    cancelledAt: j['cancelledAt'] != null ? DateTime.parse(j['cancelledAt']) : null,
  );
}

class Settlement {
  final String id, from, to;
  final double amount;
  final DateTime date;
  final bool confirmed;
  final String? confirmedBy;
  final DateTime? confirmedAt;

  Settlement({
    required this.id,
    required this.from,
    required this.to,
    required this.amount,
    required this.date,
    this.confirmed = false,
    this.confirmedBy,
    this.confirmedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'from': from,
    'to': to,
    'amount': amount,
    'date': date.toIso8601String(),
    'confirmed': confirmed,
    if (confirmedBy != null) 'confirmedBy': confirmedBy,
    if (confirmedAt != null) 'confirmedAt': confirmedAt!.toIso8601String(),
  };

  factory Settlement.fromJson(Map<String, dynamic> j) => Settlement(
    id: j['id'],
    from: j['from'],
    to: j['to'],
    amount: (j['amount'] as num).toDouble(),
    date: DateTime.parse(j['date']),
    confirmed: j['confirmed'] == true,
    confirmedBy: j['confirmedBy'],
    confirmedAt: j['confirmedAt'] != null ? DateTime.parse(j['confirmedAt']) : null,
  );
}

class Debt {
  final String from, to;
  final double amount;
  const Debt(this.from, this.to, this.amount);
}

/// Greedy debt simplification — minimizes number of transfers.
List<Debt> optimizeDebts(List<Debt> raw) {
  final bal = <String, double>{};
  for (final d in raw) {
    bal[d.from] = (bal[d.from] ?? 0) - d.amount;
    bal[d.to] = (bal[d.to] ?? 0) + d.amount;
  }
  final creditors = <MapEntry<String, double>>[];
  final debtors = <MapEntry<String, double>>[];
  for (final e in bal.entries) {
    if (e.value > 0.5) { creditors.add(e); }
    else if (e.value < -0.5) { debtors.add(MapEntry(e.key, e.value.abs())); }
  }
  creditors.sort((a, b) => b.value.compareTo(a.value));
  debtors.sort((a, b) => b.value.compareTo(a.value));
  final result = <Debt>[];
  int ci = 0, di = 0;
  final cBal = creditors.map((e) => e.value).toList();
  final dBal = debtors.map((e) => e.value).toList();
  while (ci < creditors.length && di < debtors.length) {
    final transfer = min(cBal[ci], dBal[di]);
    if (transfer > 0.5) { result.add(Debt(debtors[di].key, creditors[ci].key, transfer)); }
    cBal[ci] -= transfer;
    dBal[di] -= transfer;
    if (cBal[ci] < 0.5) { ci++; }
    if (dBal[di] < 0.5) { di++; }
  }
  return result;
}
