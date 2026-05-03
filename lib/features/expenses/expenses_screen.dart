import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme/app_colors.dart';
import '../../core/models/mock_data.dart';
import '../../core/models/expense_models.dart';
import '../../core/services/expense_service.dart';
import '../../core/services/user_service.dart';
import '../../l10n/ar.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  String? _filterCat;
  String? _filterPayer;
  String _activeDiwaniyaId = currentDiwaniyaId;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    dataVersion.addListener(_onDataChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExpenses(force: true);
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    dataVersion.removeListener(_onDataChanged);
    super.dispose();
  }

  void _syncDiwaniyaState() {
    if (_activeDiwaniyaId == currentDiwaniyaId) return;
    _activeDiwaniyaId = currentDiwaniyaId;
    _filterCat = null;
    _filterPayer = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExpenses(force: true);
    });
  }


  Future<void> _loadExpenses({bool force = false}) async {
    final did = _activeDiwaniyaId;
    if (did.trim().isEmpty) return;
    try {
      await ExpenseService.syncForDiwaniya(did, force: force);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ExpenseService.friendlyMessage(e))),
      );
    }
  }

  void _onDataChanged() {
    if (!mounted) return;
    _syncDiwaniyaState();
    setState(() {});
  }

  List<DiwaniyaMember> get _members =>
      diwaniyaMembers[_activeDiwaniyaId] ?? const <DiwaniyaMember>[];

  // ── Per-diwaniya accessors ──
  
  List<Expense> get _expenses => ExpenseService.forDiwaniya(_activeDiwaniyaId);
  List<Settlement> get _settlements =>
      ExpenseService.settlementsForDiwaniya(_activeDiwaniyaId);
  List<ExpenseCategory> get _cats =>
      ExpenseService.categoriesForDiwaniya(_activeDiwaniyaId);

  double get _totalMonth => ExpenseService.totalMonth(_activeDiwaniyaId);
  double get _totalSettled => ExpenseService.totalSettled(_activeDiwaniyaId);
  double get _totalUnpaid => ExpenseService.totalUnpaid(_activeDiwaniyaId);

  List<Debt> get _optimized => ExpenseService.optimized(_activeDiwaniyaId);

  double get _totalOwed => _optimized.where((d) => d.to == UserService.currentName).fold(0.0, (s, d) => s + d.amount);
  double get _totalIOwe => _optimized.where((d) => d.from == UserService.currentName).fold(0.0, (s, d) => s + d.amount);
  double get _netPosition => _totalOwed - _totalIOwe;
  double get _openSettlementTotal => _optimized.fold(0.0, (s, d) => s + d.amount);

  List<Expense> get _activeExpenses =>
      _expenses.where((e) => e.cancelledBy == null).toList();

  List<Expense> get _currentMonthExpenses {
    final now = DateTime.now();
    return _activeExpenses
        .where((e) => e.createdAt.year == now.year && e.createdAt.month == now.month)
        .toList();
  }

  double get _monthTotal =>
      _currentMonthExpenses.fold(0.0, (s, e) => s + e.amount);

  double get _paidByMeThisMonth => _currentMonthExpenses
      .where((e) => e.payer.trim() == UserService.currentName.trim())
      .fold(0.0, (s, e) => s + e.amount);

  double get _myShareThisMonth => _currentMonthExpenses.fold(
        0.0,
        (s, e) => s + (e.shares[UserService.currentName] ?? 0.0),
      );

  double get _totalSinceStart => _activeExpenses.fold(0.0, (s, e) => s + e.amount);

  List<Expense> get _filteredExpenses {
    var list = _expenses.where((e) => e.cancelledBy == null).toList();
    if (_filterCat != null) list = list.where((e) => e.category == _filterCat).toList();
    if (_filterPayer != null) list = list.where((e) => e.payer == _filterPayer).toList();
    return list;
  }

  Future<void> _addExpense(Expense exp) async {
    try {
      await ExpenseService.createExpense(exp, diwaniyaId: _activeDiwaniyaId);
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ExpenseService.friendlyMessage(e))),
      );
    }
  }

  Future<void> _editExpense(String id, Expense updated) async {
    try {
      await ExpenseService.editExpense(
        id,
        updated,
        actor: UserService.currentName,
        diwaniyaId: _activeDiwaniyaId,
      );
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ExpenseService.friendlyMessage(e))),
      );
    }
  }

  void _openEditSheet(Expense expense) {
    if (!UserService.isManager()) return;
    showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddExpenseSheet(
        members: _members,
        categories: _cats,
        onSave: (updated) { _editExpense(expense.id, updated); },
        onCategoryAdded: (cat) {
          ExpenseService.addCategory(cat, diwaniyaId: _activeDiwaniyaId);
          if (mounted) setState(() {});
        },
        editing: expense,
      ));
  }

  Future<void> _deleteExpense(String id) async {
    if (!UserService.isManager()) {
      return;
    }
    try {
      await ExpenseService.deleteExpense(
        id,
        actor: UserService.currentName,
        diwaniyaId: _activeDiwaniyaId,
      );
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ExpenseService.friendlyMessage(e))),
      );
    }
  }

  Future<void> _addSettlement(String from, String to, double amount) async {
    try {
      await ExpenseService.addSettlement(
        from,
        to,
        double.parse(amount.toStringAsFixed(2)),
        diwaniyaId: _activeDiwaniyaId,
      );
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ExpenseService.friendlyMessage(e))),
      );
    }
  }


  Future<void> _confirmSettlement(String settlementId) async {
    try {
      await ExpenseService.confirmSettlement(settlementId, diwaniyaId: _activeDiwaniyaId);
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ExpenseService.friendlyMessage(e))),
      );
    }
  }

  void _openAddSheet() {
    showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddExpenseSheet(
        members: _members,
        categories: _cats,
        onSave: (exp) { _addExpense(exp); },
        onCategoryAdded: (cat) {
          ExpenseService.addCategory(cat, diwaniyaId: _activeDiwaniyaId);
          if (mounted) setState(() {});
        },
      ));
  }

  void _openFilter() {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        members: _members,
        categories: _cats, currentCat: _filterCat, currentPayer: _filterPayer,
        onApply: (cat, payer) => setState(() { _filterCat = cat; _filterPayer = payer; }),
        onClear: () => setState(() { _filterCat = null; _filterPayer = null; }),
      ));
  }

  void _openAnalytics() {
    showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AnalyticsSheet(expenses: _activeExpenses, settlements: _settlements));
  }

  @override
  Widget build(BuildContext context) {
    _syncDiwaniyaState();
    final c = context.cl;
    final hasFilter = _filterCat != null || _filterPayer != null;
    return Scaffold(
      backgroundColor: c.bg,
      body: Column(children: [
        SafeArea(bottom: false, child: Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(children: [
            Expanded(child: Text(Ar.expenses, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: c.t1))),
            _IBtn(icon: Icons.bar_chart_rounded, onTap: _openAnalytics),
            const SizedBox(width: 8),
            Stack(children: [
              _IBtn(icon: Icons.filter_list_rounded, onTap: _openFilter),
              if (hasFilter) Positioned(top: 6, left: 6,
                child: Container(width: 8, height: 8, decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle))),
            ]),
          ]))),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _NetPositionCard(
            netAmount: _netPosition,
            owedToMe: _totalOwed,
            iOwe: _totalIOwe,
            openSettlements: _openSettlementTotal,
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _MonthBar(
            total: _monthTotal,
            settled: _paidByMeThisMonth,
            unpaid: _openSettlementTotal,
            count: _currentMonthExpenses.length,
            share: _myShareThisMonth,
            sinceStart: _totalSinceStart,
          ),
        ),
        const SizedBox(height: 16),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _TabBarW(controller: _tab)),
        const SizedBox(height: 2),
        Expanded(child: TabBarView(controller: _tab, children: [
          _TxTab(
            expenses: _filteredExpenses,
            onDelete: (id) { _deleteExpense(id); },
            onEdit: _openEditSheet,
          ),
          _MemTab(
            debts: _optimized,
            members: _members,
            currentUser: UserService.currentName,
            onSettle: (from, to, amount) => _addSettlement(from, to, amount),
          ),
          _SetTab(
            settlements: _settlements,
            currentUser: UserService.currentName,
            onConfirm: _confirmSettlement,
          ),
        ])),
      ]),
      floatingActionButton: Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(width: double.infinity, height: 50, child: FloatingActionButton.extended(
          heroTag: 'expenses_add_fab',
          onPressed: _openAddSheet, backgroundColor: c.accent, elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          label: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add_rounded, color: c.tInverse, size: 20), const SizedBox(width: 8),
            Text(Ar.addExpense, style: TextStyle(color: c.tInverse, fontSize: 15, fontWeight: FontWeight.w600)),
          ])))),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ADD EXPENSE SHEET — strict validation + receipt + disabled save
// ═══════════════════════════════════════════════════════════

class _AddExpenseSheet extends StatefulWidget {
  final List<DiwaniyaMember> members;
  final List<ExpenseCategory> categories;
  final ValueChanged<Expense> onSave;
  final ValueChanged<ExpenseCategory> onCategoryAdded;
  final Expense? editing;
  const _AddExpenseSheet({required this.members, required this.categories, required this.onSave,
    required this.onCategoryAdded, this.editing});
  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  final _amtCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  String _payer = UserService.currentName;
  String? _selCat;
  String _splitType = 'equal';
  bool _useSelectedMembers = false;
  late Set<String> _selected = {...widget.members.map((m) => m.name)};
  late List<TextEditingController> _pctCtrls;
  late List<TextEditingController> _fixCtrls;
  String? _receiptPath;
  String? _validationError;
  late List<ExpenseCategory> _localCategories;

  bool get _isEditMode => widget.editing != null;

  @override
  void initState() {
    super.initState();
    _localCategories = List<ExpenseCategory>.from(widget.categories);
    _pctCtrls = List.generate(widget.members.length, (_) => TextEditingController());
    _fixCtrls = List.generate(widget.members.length, (_) => TextEditingController());
    // Prefill from editing expense
    if (widget.editing != null) {
      final e = widget.editing!;
      _titleCtrl.text = e.title;
      _amtCtrl.text = e.amount.toStringAsFixed(0);
      _payer = e.payer;
      _selCat = e.category;
      _splitType = e.splitType;
      _receiptPath = e.receiptPath;
      if (e.note != null) _noteCtrl.text = e.note!;
      _useSelectedMembers = e.shares.length < widget.members.length;
      _selected = {...e.shares.keys, e.payer};
    }
    _amtCtrl.addListener(_revalidate);
    for (final c in _pctCtrls) { c.addListener(_revalidate); }
    for (final c in _fixCtrls) { c.addListener(_revalidate); }
  }

  @override
  void dispose() {
    _amtCtrl.dispose(); _noteCtrl.dispose(); _titleCtrl.dispose();
    for (final c in _pctCtrls) { c.dispose(); }
    for (final c in _fixCtrls) { c.dispose(); }
    super.dispose();
  }

  void _revalidate() => setState(() => _validationError = _validate());

  double get _amount => double.tryParse(_amtCtrl.text) ?? 0;

  List<DiwaniyaMember> get _participants => _useSelectedMembers
      ? widget.members.where((m) => _selected.contains(m.name)).toList()
      : widget.members.toList();

  String? _validate() {
    if (_amount <= 0) return Ar.errAmountRequired;
    if (_selCat == null) return Ar.errCategoryRequired;
    if (_participants.isEmpty) return Ar.errSelectMembers;

    switch (_splitType) {
      case 'percentage':
        double totalPct = 0;
        for (int i = 0; i < widget.members.length; i++) {
          if (!_participants.any((m) => m.name == widget.members[i].name)) continue;
          totalPct += double.tryParse(_pctCtrls[i].text) ?? 0;
        }
        if ((totalPct - 100).abs() > 0.1) return Ar.errPctMustBe100;
        break;
      case 'fixed':
        double totalFix = 0;
        for (int i = 0; i < widget.members.length; i++) {
          if (!_participants.any((m) => m.name == widget.members[i].name)) continue;
          totalFix += double.tryParse(_fixCtrls[i].text) ?? 0;
        }
        if ((totalFix - _amount).abs() > 0.5) return Ar.errFixedMustMatch;
        break;
    }
    return null;
  }

  bool get _isValid => _validate() == null;

  Map<String, double> _computeShares(double amount) {
    final shares = <String, double>{};
    final participants = _participants;
    if (participants.isEmpty) return shares;

    switch (_splitType) {
      case 'percentage':
        for (int i = 0; i < widget.members.length; i++) {
          if (!participants.any((m) => m.name == widget.members[i].name)) continue;
          final pct = double.tryParse(_pctCtrls[i].text) ?? 0;
          if (pct > 0) { shares[widget.members[i].name] = amount * pct / 100; }
        }
        break;
      case 'fixed':
        for (int i = 0; i < widget.members.length; i++) {
          if (!participants.any((m) => m.name == widget.members[i].name)) continue;
          final fix = double.tryParse(_fixCtrls[i].text) ?? 0;
          if (fix > 0) { shares[widget.members[i].name] = fix; }
        }
        break;
      default:
        final perPerson = amount / participants.length;
        for (final m in participants) { shares[m.name] = perPerson; }
        break;
    }
    return shares;
  }

  Future<void> _pickReceipt() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 80);
    if (img != null) setState(() => _receiptPath = img.path);
  }

  void _save() {
    if (!_isValid) return;
    final title = _titleCtrl.text.trim().isEmpty ? _selCat! : _titleCtrl.text.trim();
    if (_isEditMode) {
      // Edit: preserve original id, createdAt, createdBy
      final orig = widget.editing!;
      widget.onSave(orig.copyWith(
        title: title, payer: _payer, category: _selCat!,
        splitType: _splitType, amount: _amount,
        shares: _computeShares(_amount),
        updatedBy: UserService.currentName, updatedAt: DateTime.now(),
        note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
        receiptPath: _receiptPath,
      ));
    } else {
      // Create
      widget.onSave(Expense(
        id: 'exp_${DateTime.now().millisecondsSinceEpoch}',
        title: title, payer: _payer, category: _selCat!,
        splitType: _splitType, amount: _amount,
        shares: _computeShares(_amount), createdAt: DateTime.now(),
        createdBy: UserService.currentName,
        note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
        receiptPath: _receiptPath,
      ));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).viewInsets.bottom + 18),
      decoration: BoxDecoration(color: c.card, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.t3.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Center(child: Text(_isEditMode ? Ar.editExpense : Ar.addExpense,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.t1))),
        const SizedBox(height: 16),

        // Amount
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: c.inputBg.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: c.accent.withValues(alpha: 0.08)),
          ),
          child: TextField(
            controller: _amtCtrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: c.t1),
            decoration: InputDecoration(
              hintText: '٠ ر.س',
              hintStyle: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: c.t3.withValues(alpha: 0.55)),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 12),

        _expenseSection(
          context: context,
          title: 'دفعها',
          icon: Icons.account_balance_wallet_rounded,
          children: [
            SizedBox(height: 36, child: ListView.separated(scrollDirection: Axis.horizontal,
              itemCount: min(6, widget.members.length), separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) { final m = widget.members[i]; final sel = _payer == m.name;
                return GestureDetector(onTap: () => setState(() => _payer = m.name),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: sel ? c.accentMuted : c.inputBg.withValues(alpha: 0.72), borderRadius: BorderRadius.circular(18),
                      border: sel ? Border.all(color: c.accent.withValues(alpha: 0.4)) : null),
                    child: Center(child: Text(m.name, style: TextStyle(fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, color: sel ? c.accent : c.t2))))); })),
          ],
        ),
        const SizedBox(height: 12),

        _expenseSection(
          context: context,
          title: 'التصنيف',
          icon: Icons.category_rounded,
          children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
          ..._localCategories.map((cat) { final sel = _selCat == cat.name;
            return GestureDetector(onTap: () => setState(() { _selCat = cat.name; _revalidate(); }),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: sel ? cat.color.withValues(alpha: 0.16) : c.inputBg.withValues(alpha: 0.74), borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: sel ? cat.color.withValues(alpha: 0.36) : c.divider.withValues(alpha: 0.08))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(cat.icon, size: 14, color: sel ? cat.color : c.t3), const SizedBox(width: 6),
                  Text(cat.name, style: TextStyle(fontSize: 12, fontWeight: sel ? FontWeight.w600 : FontWeight.w500, color: sel ? cat.color : c.t2))]))); }),
          if (UserService.isManager(widget.members.isNotEmpty ? currentDiwaniyaId : null)) GestureDetector(onTap: () { final nc = TextEditingController();
            showDialog(context: context, builder: (d) { final dc = d.cl;
              return AlertDialog(backgroundColor: dc.card, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text(Ar.addCategory, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: dc.t1)),
                content: TextField(controller: nc, autofocus: true, style: TextStyle(color: dc.t1),
                  decoration: InputDecoration(hintText: 'اسم التصنيف', hintStyle: TextStyle(color: dc.t3))),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(d), child: Text(Ar.cancel, style: TextStyle(color: dc.t2))),
                  TextButton(onPressed: () {
                    final name = nc.text.trim();
                    if (name.isEmpty) return;
                    final exists = _localCategories.any((cat) => cat.name.trim() == name);
                    final category = ExpenseCategory(
                      name: name,
                      icon: Icons.label_rounded,
                      color: const Color(0xFF9CA3AF),
                    );
                    widget.onCategoryAdded(category);
                    setState(() {
                      if (!exists) _localCategories.add(category);
                      _selCat = name;
                      _revalidate();
                    });
                    Navigator.pop(d);
                  },
                    child: Text(Ar.confirm, style: TextStyle(color: dc.accent, fontWeight: FontWeight.w600)))]); }); },
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.06), border: Border.all(color: c.accent.withValues(alpha: 0.16)), borderRadius: BorderRadius.circular(14)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_rounded, size: 14, color: c.accent), const SizedBox(width: 4),
                Text(Ar.addCategory, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.accent))]))),
            ]),
          ],
        ),
        const SizedBox(height: 12),

        _expenseSection(
          context: context,
          title: 'المشاركون والتقسيم',
          icon: Icons.call_split_rounded,
          children: [
        // Participants scope
        Text('النطاق', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.t3)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _splitChip('الكل', !_useSelectedMembers, () => setState(() { _useSelectedMembers = false; _revalidate(); }), c),
          _splitChip('أشخاص محددين', _useSelectedMembers, () => setState(() { _useSelectedMembers = true; _revalidate(); }), c),
        ]),
        if (_useSelectedMembers) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: widget.members.map((m) { final on = _selected.contains(m.name);
            return GestureDetector(onTap: () => setState(() { on ? _selected.remove(m.name) : _selected.add(m.name); _revalidate(); }),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: on ? c.accent.withValues(alpha: 0.15) : c.inputBg, borderRadius: BorderRadius.circular(8),
                  border: on ? Border.all(color: c.accent.withValues(alpha: 0.3)) : null),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(on ? Icons.check_circle_rounded : Icons.circle_outlined, size: 14, color: on ? c.accent : c.t3),
                  const SizedBox(width: 5),
                  Text(m.name, style: TextStyle(fontSize: 12, color: on ? c.accent : c.t2))]))); }).toList()),
        ],
        const SizedBox(height: 14),

        // Split type
        Text('طريقة التقسيم', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.t3)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _splitChip('بالتساوي', _splitType == 'equal', () => setState(() { _splitType = 'equal'; _revalidate(); }), c),
          _splitChip('نسبة مئوية', _splitType == 'percentage', () => setState(() { _splitType = 'percentage'; _revalidate(); }), c),
          _splitChip('مبلغ محدد', _splitType == 'fixed', () => setState(() { _splitType = 'fixed'; _revalidate(); }), c),
        ]),
        const SizedBox(height: 12),

        if (_splitType == 'percentage')
          ...List.generate(widget.members.length, (i) {
            if (!_participants.any((m) => m.name == widget.members[i].name)) return const SizedBox.shrink();
            return Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
              SizedBox(width: 60, child: Text(widget.members[i].name, style: TextStyle(fontSize: 13, color: c.t1))),
              Expanded(child: SizedBox(height: 38, child: TextField(controller: _pctCtrls[i],
                keyboardType: TextInputType.number, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: c.t1),
                decoration: InputDecoration(hintText: '%', hintStyle: TextStyle(color: c.t3), isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8))))),
            ])); }),

        if (_splitType == 'fixed')
          ...List.generate(widget.members.length, (i) {
            if (!_participants.any((m) => m.name == widget.members[i].name)) return const SizedBox.shrink();
            return Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
              SizedBox(width: 60, child: Text(widget.members[i].name, style: TextStyle(fontSize: 13, color: c.t1))),
              Expanded(child: SizedBox(height: 38, child: TextField(controller: _fixCtrls[i],
                keyboardType: TextInputType.number, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: c.t1),
                decoration: InputDecoration(hintText: 'ر.س', hintStyle: TextStyle(color: c.t3), isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8))))),
            ])); }),

        // Per-person display
        if (_splitType == 'equal' && _amount > 0) ...[
          const SizedBox(height: 8),
          Builder(builder: (_) {
            final participants = _participants;
            final n = participants.length;
            final pp = n > 0 ? _amount / n : 0.0;
            return Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.accentSurface, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Icon(Icons.calculate_rounded, size: 16, color: c.accent), const SizedBox(width: 8),
                Text('لكل شخص: ', style: TextStyle(fontSize: 13, color: c.t2)),
                Text('${pp.toStringAsFixed(1)} ر.س', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.accent)),
                Text(' ($n أشخاص)', style: TextStyle(fontSize: 11, color: c.t3)),
              ]));
          }),
        ],

        const SizedBox(height: 12),

          ],
        ),
        const SizedBox(height: 10),

        // Receipt attachment
        GestureDetector(
          onTap: _pickReceipt,
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: _receiptPath != null ? c.accent.withValues(alpha: 0.1) : c.inputBg.withValues(alpha: 0.74), borderRadius: BorderRadius.circular(16),
              border: _receiptPath != null ? Border.all(color: c.accent.withValues(alpha: 0.3)) : null),
            child: Row(children: [
              Icon(_receiptPath != null ? Icons.check_circle_rounded : Icons.camera_alt_rounded, size: 18,
                color: _receiptPath != null ? c.accent : c.t3),
              const SizedBox(width: 8),
              Expanded(child: Text(_receiptPath != null ? Ar.receiptAttached : Ar.attachReceipt,
                style: TextStyle(fontSize: 13, color: _receiptPath != null ? c.accent : c.t2,
                  fontWeight: _receiptPath != null ? FontWeight.w600 : FontWeight.w500))),
              if (_receiptPath != null)
                GestureDetector(
                  onTap: () => setState(() => _receiptPath = null),
                  child: Icon(Icons.close_rounded, size: 16, color: c.t3)),
            ]))),
        // Receipt thumbnail preview
        if (_receiptPath != null) ...[
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(10),
            child: Image.file(File(_receiptPath!), height: 120, width: double.infinity, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(height: 60, decoration: BoxDecoration(
                color: c.inputBg, borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text('تعذر عرض الصورة', style: TextStyle(fontSize: 12, color: c.t3)))))),
        ],
        const SizedBox(height: 10),

        TextField(controller: _noteCtrl, style: TextStyle(fontSize: 14, color: c.t1),
          decoration: InputDecoration(hintText: 'ملاحظة (اختياري)', hintStyle: TextStyle(color: c.t3))),
        const SizedBox(height: 8),

        // Validation error
        if (_validationError != null && _amount > 0)
          Padding(padding: const EdgeInsets.only(bottom: 8),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: c.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                Icon(Icons.error_outline_rounded, size: 16, color: c.error), const SizedBox(width: 8),
                Expanded(child: Text(_validationError!, style: TextStyle(fontSize: 12, color: c.error))),
              ]))),

        // Save — disabled when invalid
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
          onPressed: _isValid ? _save : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isValid ? c.accent : c.inputBg, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
          child: Text(Ar.saveExpense, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
            color: _isValid ? c.tInverse : c.t3)))),
      ])));
  }
}


Widget _expenseSection({
  required BuildContext context,
  required String title,
  required List<Widget> children,
  IconData? icon,
}) {
  final c = context.cl;
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
    decoration: BoxDecoration(
      color: c.card.withValues(alpha: 0.78),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: c.divider.withValues(alpha: 0.12)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 15, color: c.accent),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: c.t1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );
}

Widget _splitChip(String label, bool sel, VoidCallback onTap, CL c) => GestureDetector(onTap: onTap,
  child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: sel ? c.accent.withValues(alpha: 0.15) : c.inputBg, borderRadius: BorderRadius.circular(10),
      border: sel ? Border.all(color: c.accent.withValues(alpha: 0.5)) : null),
    child: Text(label, style: TextStyle(fontSize: 12, fontWeight: sel ? FontWeight.w600 : FontWeight.w500, color: sel ? c.accent : c.t2))));

// ═══════════════════════════════════════════════════════════
// FILTER + ANALYTICS (unchanged — keeping as-is)
// ═══════════════════════════════════════════════════════════

class _FilterSheet extends StatefulWidget {
  final List<DiwaniyaMember> members;
  final List<ExpenseCategory> categories; final String? currentCat, currentPayer;
  final void Function(String?, String?) onApply; final VoidCallback onClear;
  const _FilterSheet({required this.members, required this.categories, this.currentCat, this.currentPayer, required this.onApply, required this.onClear});
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _cat, _payer;
  @override
  void initState() {
    super.initState();
    const hidden = {'لوازم الكيف', 'راتب العامل', 'راتب عامل', 'أخرى'};
    _cat = hidden.contains(widget.currentCat?.trim()) ? null : widget.currentCat;
    _payer = widget.currentPayer;
  }
  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Container(padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: c.card, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.t3.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Center(child: Text(Ar.filter, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.t1))),
        const SizedBox(height: 20),
        Text('التصنيف', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.t2)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _filterChip(Ar.allCategories, _cat == null, () => setState(() => _cat = null), c),
          ...widget.categories
              .where((cat) => !{'لوازم الكيف', 'راتب العامل', 'راتب عامل', 'أخرى'}.contains(cat.name.trim()))
              .map((cat) => _filterChip(cat.name, _cat == cat.name, () => setState(() => _cat = cat.name), c)),
        ]),
        const SizedBox(height: 16),
        Text('الشخص', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.t2)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _filterChip(Ar.allMembers, _payer == null, () => setState(() => _payer = null), c),
          ...widget.members.take(6).map((m) => _filterChip(m.name, _payer == m.name, () => setState(() => _payer = m.name), c)),
        ]),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: () { widget.onClear(); Navigator.pop(context); },
            style: OutlinedButton.styleFrom(foregroundColor: c.t2, side: BorderSide(color: c.divider),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
            child: const Text(Ar.clearFilter))),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton(
            onPressed: () { widget.onApply(_cat, _payer); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(backgroundColor: c.accent, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
            child: Text(Ar.applyFilter, style: TextStyle(color: c.tInverse)))),
        ]),
      ]));
  }
}

Widget _filterChip(String label, bool sel, VoidCallback onTap, CL c) => GestureDetector(onTap: onTap,
  child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(color: sel ? c.accentMuted : c.inputBg, borderRadius: BorderRadius.circular(8),
      border: sel ? Border.all(color: c.accent.withValues(alpha: 0.4)) : null),
    child: Text(label, style: TextStyle(fontSize: 12, fontWeight: sel ? FontWeight.w600 : FontWeight.w500, color: sel ? c.accent : c.t2))));


class _AnalyticsSheet extends StatelessWidget {
  final List<Expense> expenses;
  final List<Settlement> settlements;
  const _AnalyticsSheet({required this.expenses, required this.settlements});

  List<_MonthPoint> _monthlyPoints() {
    final now = DateTime.now();
    final buckets = <DateTime, double>{};

    for (var i = 11; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i);
      buckets[DateTime(month.year, month.month)] = 0;
    }

    for (final expense in expenses) {
      final key = DateTime(expense.createdAt.year, expense.createdAt.month);
      if (!buckets.containsKey(key)) continue;
      buckets[key] = (buckets[key] ?? 0) + expense.amount;
    }

    return buckets.entries
        .map((entry) => _MonthPoint(entry.key, entry.value))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final total = expenses.fold(0.0, (s, e) => s + e.amount);
    final confirmedSettled = settlements
        .where((s) => s.confirmed)
        .fold(0.0, (s, e) => s + e.amount);

    final byCat = <String, double>{};
    for (final e in expenses) {
      byCat[e.category] = (byCat[e.category] ?? 0) + e.amount;
    }
    final catE = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final byPayer = <String, double>{};
    for (final e in expenses) {
      byPayer[e.payer] = (byPayer[e.payer] ?? 0) + e.amount;
    }
    final payE = byPayer.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final points = _monthlyPoints();
    final currentMonthTotal = points.isNotEmpty ? points.last.value : 0.0;
    final previousMonthTotal = points.length > 1 ? points[points.length - 2].value : 0.0;
    final delta = previousMonthTotal == 0
        ? (currentMonthTotal > 0 ? 100.0 : 0.0)
        : ((currentMonthTotal - previousMonthTotal) / previousMonthTotal * 100);

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: c.card, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.t3.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Center(child: Text('تحليلات المصاريف', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.t1))),
            const SizedBox(height: 6),
            Center(child: Text('قراءة شهرية وسنوية لمصاريف الديوانية', style: TextStyle(fontSize: 12, color: c.t3))),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: _AnalyticsKpi(label: 'منذ التأسيس', value: total, icon: Icons.savings_rounded, c: c, color: c.accent)),
              const SizedBox(width: 10),
              Expanded(child: _AnalyticsKpi(label: 'هذا الشهر', value: currentMonthTotal, icon: Icons.calendar_month_rounded, c: c, color: c.info)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _AnalyticsKpi(label: 'تسويات مؤكدة', value: confirmedSettled, icon: Icons.verified_rounded, c: c, color: c.success)),
              const SizedBox(width: 10),
              Expanded(child: _TrendKpi(delta: delta, c: c)),
            ]),
            const SizedBox(height: 22),
            _AnalyticsCard(
              c: c,
              title: 'المصاريف الشهرية',
              subtitle: 'آخر 12 شهر محفوظة من سجل مصاريف الديوانية',
              child: _MonthlyExpenseChart(points: points, c: c),
            ),
            const SizedBox(height: 18),
            _AnalyticsCard(
              c: c,
              title: Ar.byPayer,
              subtitle: 'من دفع أكثر للديوانية',
              child: Column(children: payE.take(6).map((e) => _Bar(label: e.key, value: e.value, maxVal: payE.isEmpty ? total : payE.first.value, c: c, color: c.info)).toList()),
            ),
            const SizedBox(height: 18),
            _AnalyticsCard(
              c: c,
              title: Ar.byCategory,
              subtitle: 'أين تذهب مصاريف الديوانية',
              child: Column(children: catE.take(6).map((e) => _Bar(label: e.key, value: e.value, maxVal: catE.isEmpty ? total : catE.first.value, c: c, color: c.accent)).toList()),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _MonthPoint {
  final DateTime month;
  final double value;
  const _MonthPoint(this.month, this.value);
}

class _AnalyticsCard extends StatelessWidget {
  final CL c;
  final String title;
  final String subtitle;
  final Widget child;
  const _AnalyticsCard({required this.c, required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.inputBg.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.t1)),
          const SizedBox(height: 3),
          Text(subtitle, style: TextStyle(fontSize: 11, color: c.t3)),
          const SizedBox(height: 14),
          child,
        ]),
      );
}

class _AnalyticsKpi extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final CL c;
  final Color color;
  const _AnalyticsKpi({required this.label, required this.value, required this.icon, required this.c, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: c.inputBg.withValues(alpha: 0.62), borderRadius: BorderRadius.circular(15)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 30, height: 30, decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(9)), child: Icon(icon, size: 16, color: color)),
          const SizedBox(height: 10),
          Text('${value.toInt()} ر.س', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: c.t1)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: c.t3)),
        ]),
      );
}

class _TrendKpi extends StatelessWidget {
  final double delta;
  final CL c;
  const _TrendKpi({required this.delta, required this.c});

  @override
  Widget build(BuildContext context) {
    final up = delta > 0.5;
    final down = delta < -0.5;
    final color = up ? c.warning : (down ? c.success : c.t3);
    final icon = up ? Icons.trending_up_rounded : (down ? Icons.trending_down_rounded : Icons.trending_flat_rounded);
    final text = up ? '+${delta.abs().toStringAsFixed(0)}%' : (down ? '-${delta.abs().toStringAsFixed(0)}%' : 'مستقر');
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: c.inputBg.withValues(alpha: 0.62), borderRadius: BorderRadius.circular(15)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 30, height: 30, decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(9)), child: Icon(icon, size: 17, color: color)),
        const SizedBox(height: 10),
        Text(text, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text('مقارنة بالشهر السابق', style: TextStyle(fontSize: 11, color: c.t3)),
      ]),
    );
  }
}

class _MonthlyExpenseChart extends StatelessWidget {
  final List<_MonthPoint> points;
  final CL c;
  const _MonthlyExpenseChart({required this.points, required this.c});

  String _monthLabel(DateTime date) {
    const months = ['ينا', 'فبر', 'مار', 'أبر', 'ماي', 'يون', 'يول', 'أغس', 'سبت', 'أكت', 'نوف', 'ديس'];
    return months[date.month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final maxVal = points.fold(0.0, (m, p) => max(m, p.value));
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: points.map((point) {
          final ratio = maxVal <= 0 ? 0.0 : point.value / maxVal;
          final height = 18.0 + (ratio * 82.0);
          final active = point.month.year == DateTime.now().year && point.month.month == DateTime.now().month;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(point.value > 0 ? point.value.toInt().toString() : '', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: active ? c.accent : c.t3), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: height,
                    decoration: BoxDecoration(
                      color: (active ? c.accent : c.info).withValues(alpha: active ? 0.86 : 0.46),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8), bottom: Radius.circular(3)),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(_monthLabel(point.month), style: TextStyle(fontSize: 9, color: active ? c.t1 : c.t3, fontWeight: active ? FontWeight.w800 : FontWeight.w500)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final String label; final double value, maxVal; final CL c; final Color color;
  const _Bar({required this.label, required this.value, required this.maxVal, required this.c, required this.color});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Flexible(child: Text(label, style: TextStyle(fontSize: 12, color: c.t2, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
      const SizedBox(width: 8),
      Text('${value.toInt()} ر.س', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c.t1)),
    ]),
    const SizedBox(height: 6),
    ClipRRect(borderRadius: BorderRadius.circular(6), child: SizedBox(height: 9,
      child: LinearProgressIndicator(value: maxVal > 0 ? min(1, value / maxVal) : 0, backgroundColor: c.card, color: color))),
  ]));
}

// ═══════════════════════════════════════════════════════════
// SMALL WIDGETS
// ═══════════════════════════════════════════════════════════

class _IBtn extends StatelessWidget {
  final IconData icon; final VoidCallback? onTap;
  const _IBtn({required this.icon, this.onTap});
  @override
  Widget build(BuildContext context) { final c = context.cl;
    return GestureDetector(onTap: onTap, child: Container(width: 38, height: 38,
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(11)),
      child: Icon(icon, size: 19, color: c.t2))); }
}


class _NetPositionCard extends StatelessWidget {
  final double netAmount;
  final double owedToMe;
  final double iOwe;
  final double openSettlements;
  const _NetPositionCard({
    required this.netAmount,
    required this.owedToMe,
    required this.iOwe,
    required this.openSettlements,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final isPositive = netAmount > 0.5;
    final isNegative = netAmount < -0.5;
    final color = isPositive ? c.success : (isNegative ? c.error : c.accent);
    final icon = isPositive
        ? Icons.south_west_rounded
        : (isNegative ? Icons.north_east_rounded : Icons.check_circle_rounded);
    final title = isPositive ? 'لك' : (isNegative ? 'عليك' : 'أمورك طيبة');
    final amountText = isPositive || isNegative
        ? '${netAmount.abs().toInt()} ر.س'
        : 'لا توجد مبالغ عليك الآن';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border(right: BorderSide(color: color.withValues(alpha: 0.55), width: 4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('موقفك المالي', style: TextStyle(fontSize: 12, color: c.t3, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
            ]),
          ),
          Text(amountText, style: TextStyle(fontSize: isPositive || isNegative ? 22 : 13, fontWeight: FontWeight.w900, color: isPositive || isNegative ? color : c.t2)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _MiniMoney(label: 'لك', amount: owedToMe, color: c.success, c: c)),
          const SizedBox(width: 8),
          Expanded(child: _MiniMoney(label: 'عليك', amount: iOwe, color: c.error, c: c)),
          const SizedBox(width: 8),
          Expanded(child: _MiniMoney(label: 'تسويات مفتوحة', amount: openSettlements, color: c.warning, c: c)),
        ]),
      ]),
    );
  }
}

class _MiniMoney extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final CL c;
  const _MiniMoney({required this.label, required this.amount, required this.color, required this.c});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(color: c.inputBg.withValues(alpha: 0.62), borderRadius: BorderRadius.circular(11)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 10, color: c.t3, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text('${amount.toInt()} ر.س', style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      );
}

class _BalCard extends StatelessWidget {
  final String label; final double amount; final bool positive;
  const _BalCard({required this.label, required this.amount, required this.positive});
  @override
  Widget build(BuildContext context) { final c = context.cl;
    final col = positive ? c.success : c.error;
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(14),
        border: Border(right: BorderSide(color: col.withValues(alpha: 0.45), width: 3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 26, height: 26,
            decoration: BoxDecoration(color: (positive ? c.successM : c.errorM), borderRadius: BorderRadius.circular(7)),
            child: Icon(positive ? Icons.south_west_rounded : Icons.north_east_rounded, size: 13, color: col)),
          const SizedBox(width: 8), Text(label, style: TextStyle(fontSize: 13, color: c.t2)),
        ]),
        const SizedBox(height: 10),
        Text('${amount.toInt()} ر.س', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: col)),
      ])); }
}

class _MonthBar extends StatelessWidget {
  final double total, settled, unpaid, share, sinceStart;
  final int count;
  const _MonthBar({
    required this.total,
    required this.settled,
    required this.unpaid,
    required this.count,
    required this.share,
    required this.sinceStart,
  });
  @override
  Widget build(BuildContext context) { final c = context.cl;
    final paidPct = total > 0 ? (settled / total * 100).clamp(0, 100).round() : 0;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Row(children: [
          Icon(Icons.insights_rounded, size: 15, color: c.t3), const SizedBox(width: 6),
          Text('ملخص الشهر', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.t2)),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: c.cardElevated, borderRadius: BorderRadius.circular(5)),
            child: Text('$count مصاريف', style: TextStyle(fontSize: 10, color: c.t3)))]),
        const SizedBox(height: 10),
        Row(children: [
          _MStat('إجمالي الشهر', '${total.toInt()}', c.t1, c), _MDv(c),
          _MStat('دفعت أنت', '${settled.toInt()}', c.success, c), _MDv(c),
          _MStat('حصتك', '${share.toInt()}', c.info, c),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _MStat('منذ التأسيس', '${sinceStart.toInt()}', c.accent, c), _MDv(c),
          _MStat('تسويات مفتوحة', '${unpaid.toInt()}', c.warning, c), _MDv(c),
          _MStat('نسبة دفعك', '$paidPct%', c.t2, c),
        ]),
      ])); }
}

class _MStat extends StatelessWidget {
  final String l, v; final Color col; final CL c;
  const _MStat(this.l, this.v, this.col, this.c);
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(v, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: col, fontFamily: 'IBM Plex Sans Arabic'), textAlign: TextAlign.center),
    const SizedBox(height: 2), Text(l, style: TextStyle(fontSize: 10, color: c.t3), textAlign: TextAlign.center),
  ]));
}

class _MDv extends StatelessWidget {
  final CL c; const _MDv(this.c);
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 28, color: c.divider, margin: const EdgeInsets.symmetric(horizontal: 2));
}

class _TabBarW extends StatelessWidget {
  final TabController controller;
  const _TabBarW({required this.controller});
  @override
  Widget build(BuildContext context) { final c = context.cl;
    return Container(height: 40, padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(11)),
      child: TabBar(controller: controller,
        indicator: BoxDecoration(color: c.cardElevated, borderRadius: BorderRadius.circular(8)),
        indicatorSize: TabBarIndicatorSize.tab, dividerColor: Colors.transparent,
        labelColor: c.t1, unselectedLabelColor: c.t3,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        labelPadding: EdgeInsets.zero,
        tabs: const [Tab(text: 'المصاريف'), Tab(text: 'الأعضاء'), Tab(text: 'التسويات')])); }
}

// ═══════════════════════════════════════════════════════════
// TAB 1: Transactions — receipt indicator + manager delete
// ═══════════════════════════════════════════════════════════

class _TxTab extends StatefulWidget {
  final List<Expense> expenses;
  final void Function(String id) onDelete;
  final void Function(Expense expense) onEdit;
  const _TxTab({required this.expenses, required this.onDelete, required this.onEdit});
  @override
  State<_TxTab> createState() => _TxTabState();
}

class _TxTabState extends State<_TxTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  void _showActions(BuildContext ctx, Expense e) {
    final c = ctx.cl;
    showModalBottomSheet(context: ctx, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: c.card, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(e.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.t1)),
          const SizedBox(height: 4),
          Text('${e.amount.toInt()} ر.س · ${e.payer} · ${_timeAgo(e.createdAt)}', style: TextStyle(fontSize: 12, color: c.t3)),
          const SizedBox(height: 4),
          Text('أضافه ${e.createdBy} · ${_timeAgo(e.createdAt)}', style: TextStyle(fontSize: 11, color: c.t3)),
          if (e.updatedBy != null)
            Text('عدّله ${e.updatedBy} · ${_timeAgo(e.updatedAt!)}', style: TextStyle(fontSize: 11, color: c.t3)),
          if (e.hasReceipt) ...[
            const SizedBox(height: 10),
            ClipRRect(borderRadius: BorderRadius.circular(8),
              child: Image.file(File(e.receiptPath!), height: 100, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(height: 50,
                  decoration: BoxDecoration(color: c.inputBg, borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.attach_file_rounded, size: 14, color: c.accent), const SizedBox(width: 6),
                    Text(Ar.receiptAttached, style: TextStyle(fontSize: 12, color: c.accent)),
                  ])))),
          ],
          const SizedBox(height: 16),
          if (UserService.isManager()) ...[
            SizedBox(width: double.infinity, height: 44, child: ElevatedButton.icon(
              onPressed: () { Navigator.pop(ctx); widget.onEdit(e); },
              icon: Icon(Icons.edit_rounded, size: 18, color: c.tInverse),
              label: Text(Ar.editExpense, style: TextStyle(color: c.tInverse, fontSize: 14)),
              style: ElevatedButton.styleFrom(backgroundColor: c.accent, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, height: 44, child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                showDialog(context: ctx, builder: (d) {
                  final dc = d.cl;
                  return AlertDialog(backgroundColor: dc.card,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text(Ar.deleteExpense, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: dc.t1)),
                    content: Text(Ar.deleteConfirm, style: TextStyle(color: dc.t2)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(d), child: Text(Ar.cancel, style: TextStyle(color: dc.t2))),
                      TextButton(onPressed: () { widget.onDelete(e.id); Navigator.pop(d); },
                        child: Text(Ar.delete, style: TextStyle(color: dc.error, fontWeight: FontWeight.w600))),
                    ]);
                });
              },
              icon: Icon(Icons.delete_outline_rounded, size: 18, color: c.error),
              label: Text(Ar.deleteExpense, style: TextStyle(color: c.error, fontSize: 14)),
              style: OutlinedButton.styleFrom(side: BorderSide(color: c.error.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
          ] else
            Text(Ar.managerOnly, style: TextStyle(fontSize: 12, color: c.t3)),
        ])));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = context.cl;
    if (widget.expenses.isEmpty) return Center(child: Text('لا توجد مصاريف', style: TextStyle(color: c.t3)));
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
      itemCount: widget.expenses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 5),
      itemBuilder: (_, i) {
        final e = widget.expenses[i];
        final catIcon = defaultExpenseCategories.where((c) => c.name == e.category).firstOrNull?.icon ?? Icons.receipt_rounded;
        return GestureDetector(
          onLongPress: () => _showActions(context, e),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(13)),
            child: Row(children: [
              Container(width: 40, height: 40,
                decoration: BoxDecoration(color: c.cardElevated, borderRadius: BorderRadius.circular(10)),
                child: Icon(catIcon, size: 19, color: c.t2)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(e.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.t1),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (e.hasReceipt) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.attach_file_rounded, size: 13, color: c.accent),
                  ],
                ]),
                const SizedBox(height: 3),
                Text('${e.payer} دفع · ${_timeAgo(e.createdAt)} · ${e.category}',
                  style: TextStyle(fontSize: 11, color: c.t3)),
              ])),
              Text('${e.amount.toInt()} ر.س',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.t1)),
            ])));
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
// TAB 2: Members — optimized settlements
// ═══════════════════════════════════════════════════════════

class _MemTab extends StatefulWidget {
  final List<Debt> debts;
  final List<DiwaniyaMember> members;
  final String currentUser;
  final Future<void> Function(String from, String to, double amount) onSettle;
  const _MemTab({required this.debts, required this.members, required this.currentUser, required this.onSettle});
  @override
  State<_MemTab> createState() => _MemTabState();
}

class _MemTabState extends State<_MemTab> with AutomaticKeepAliveClientMixin {
  final Set<String> _settling = <String>{};

  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = context.cl;
    if (widget.debts.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle_rounded, size: 48, color: c.success),
        const SizedBox(height: 12),
        Text('الكل متساوي — ما في ديون', style: TextStyle(color: c.t2, fontSize: 14)),
      ]));
    }
    return ListView(padding: const EdgeInsets.fromLTRB(20, 10, 20, 100), children: [
      // Section header
      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: c.accentSurface, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.accent.withValues(alpha: 0.12))),
        child: Row(children: [
          Icon(Icons.auto_fix_high_rounded, size: 16, color: c.accent), const SizedBox(width: 8),
          Expanded(child: Text(Ar.optimizedSettlements, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.accent))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
            child: Text('${widget.debts.length} تحويلات', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.accent))),
        ])),
      const SizedBox(height: 10),

      ...widget.debts.map((d) {
        final fromM = widget.members.where((m) => m.name == d.from).firstOrNull;
        return Padding(padding: const EdgeInsets.only(bottom: 6), child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(13)),
          child: Row(children: [
            CircleAvatar(radius: 16, backgroundColor: (fromM?.avatarColor ?? c.accent).withValues(alpha: 0.15),
              child: Text(fromM?.initials ?? '?', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fromM?.avatarColor ?? c.accent))),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              RichText(text: TextSpan(style: TextStyle(fontSize: 13, fontFamily: 'IBM Plex Sans Arabic', color: c.t1), children: [
                TextSpan(text: d.from, style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: ' يدفع لـ ', style: TextStyle(color: c.t3)),
                TextSpan(text: d.to, style: const TextStyle(fontWeight: FontWeight.w600)),
              ])),
              const SizedBox(height: 2),
              Text('${d.amount.toInt()} ر.س', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.error)),
            ])),
            Builder(builder: (_) {
              final key = '${d.from}->${d.to}:${d.amount.toStringAsFixed(2)}';
              final isBusy = _settling.contains(key);
              final canSettle =
                  !isBusy && (widget.currentUser == d.from || widget.currentUser == d.to);
              return GestureDetector(
                onTap: canSettle
                    ? () async {
                        setState(() => _settling.add(key));
                        try {
                          await widget.onSettle(d.from, d.to, d.amount);
                        } finally {
                          if (mounted) setState(() => _settling.remove(key));
                        }
                      }
                    : null,
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: canSettle ? c.accent : c.inputBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isBusy ? 'جاري...' : Ar.settlement,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: canSettle ? c.tInverse : c.t3,
                    ),
                  )),
              );
            }),
          ])));
      }),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════
// TAB 3: Settlements
// ═══════════════════════════════════════════════════════════

class _SetTab extends StatefulWidget {
  final List<Settlement> settlements;
  final String currentUser;
  final Future<void> Function(String settlementId) onConfirm;
  const _SetTab({required this.settlements, required this.currentUser, required this.onConfirm});
  @override
  State<_SetTab> createState() => _SetTabState();
}

class _SetTabState extends State<_SetTab> with AutomaticKeepAliveClientMixin {
  final Set<String> _confirming = <String>{};

  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = context.cl;
    if (widget.settlements.isEmpty) return Center(child: Text('لا توجد تسويات', style: TextStyle(color: c.t3)));
    final sorted = List<Settlement>.from(widget.settlements)..sort((a, b) => b.date.compareTo(a.date));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
      itemCount: sorted.length,
      itemBuilder: (_, i) {
        final s = sorted[i];
        return Padding(padding: const EdgeInsets.only(bottom: 5), child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Container(width: 38, height: 38,
              decoration: BoxDecoration(color: c.successM, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.handshake_rounded, size: 18, color: c.success)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${s.from} دفع لـ ${s.to}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.t1)),
              const SizedBox(height: 2),
              Text(_timeAgo(s.date), style: TextStyle(fontSize: 11, color: c.t3)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${s.amount.toInt()} ر.س', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.success)),
              const SizedBox(height: 6),
              Builder(builder: (_) {
                final isBusy = _confirming.contains(s.id);
                final canConfirm = !isBusy && widget.currentUser == s.to && !s.confirmed;
                return GestureDetector(
                  onTap: canConfirm
                      ? () async {
                          setState(() => _confirming.add(s.id));
                          try {
                            await widget.onConfirm(s.id);
                          } finally {
                            if (mounted) setState(() => _confirming.remove(s.id));
                          }
                        }
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: s.confirmed ? c.successM : (canConfirm ? c.accentSurface : c.inputBg),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: s.confirmed ? c.success.withValues(alpha: 0.25) : Colors.transparent,
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        s.confirmed ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
                        size: 14,
                        color: s.confirmed ? c.success : (canConfirm ? c.accent : c.t3),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        s.confirmed ? 'مؤكد' : (isBusy ? 'جاري...' : 'تأكيد'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: s.confirmed ? c.success : (canConfirm ? c.accent : c.t3),
                        ),
                      ),
                    ]),
                  ),
                );
              }),
            ]),
          ])));
      },
    );
  }
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'الآن';
  if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} دقيقة';
  if (diff.inHours < 24) return 'قبل ${diff.inHours} ساعة';
  if (diff.inDays < 7) return 'قبل ${diff.inDays} يوم';
  return 'قبل ${diff.inDays ~/ 7} أسبوع';
}
