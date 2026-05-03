import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';
import '../../core/models/mock_data.dart';
import '../../core/api/api_exception.dart';
import '../../core/services/maqadi_service.dart';
import '../../core/services/user_service.dart';
import '../../l10n/ar.dart';

const _defaultCategories = [
  'مستلزمات',
];

const _categoryIcons = <String, IconData>{
  'مستلزمات': Icons.inventory_2_rounded,
  'طلبات خارجية': Icons.delivery_dining_rounded,
  'ترفيه واشتراكات': Icons.sports_esports_rounded,
  'أخرى': Icons.more_horiz_rounded,
};


const _statusOrder = {
  'needed': 0,
  'low': 1,
  'available': 2,
};

List<String> _allCategories(String diwaniyaId) {
  final seen = <String>{};
  final result = <String>[];
  final custom = diwaniyaCustomCategories[diwaniyaId] ?? <String>[];
  final used = (diwaniyaShoppingItems[diwaniyaId] ?? <MockShoppingItem>[])
      .map((item) => item.category);

  for (final name in <String>[..._defaultCategories, ...custom, ...used]) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || seen.contains(trimmed)) continue;
    seen.add(trimmed);
    result.add(trimmed);
  }
  return result;
}

int _totalCategoryCount(String diwaniyaId) {
  return _defaultCategories.length +
      (diwaniyaCustomCategories[diwaniyaId]?.length ?? 0);
}

IconData _iconForCategory(String category) {
  return _categoryIcons[category] ?? Icons.label_rounded;
}

String _statusLabel(String status) {
  switch (status) {
    case 'available':
      return Ar.statusAvailable;
    case 'low':
      return Ar.statusLow;
    default:
      return Ar.statusNeeded;
  }
}

Color _statusColor(String status, CL c) {
  switch (status) {
    case 'available':
      return c.success;
    case 'low':
      return c.warning;
    default:
      return c.error;
  }
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'الآن';
  if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} د';
  if (diff.inHours < 24) return 'قبل ${diff.inHours} س';
  if (diff.inDays < 7) return 'قبل ${diff.inDays} يوم';
  return 'قبل ${diff.inDays ~/ 7} أسبوع';
}


class MaqadiScreen extends StatefulWidget {
  final String initialFilter;

  const MaqadiScreen({
    super.key,
    this.initialFilter = 'all',
  });

  @override
  State<MaqadiScreen> createState() => _MaqadiScreenState();
}

class _MaqadiScreenState extends State<MaqadiScreen> {
  late String _filter;
  String? _catFilter;
  String _search = '';
  String _activeDiwaniyaId = currentDiwaniyaId;
  final _searchCtrl = TextEditingController();
  final Set<String> _collapsed = {};

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    dataVersion.addListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncRemote());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    dataVersion.removeListener(_refresh);
    super.dispose();
  }

  void _syncDiwaniyaState() {
    if (_activeDiwaniyaId == currentDiwaniyaId) return;
    _activeDiwaniyaId = currentDiwaniyaId;
    _filter = widget.initialFilter;
    _catFilter = null;
    _search = '';
    _searchCtrl.clear();
    _collapsed.clear();
  }

  void _refresh() {
    if (!mounted) return;
    final previous = _activeDiwaniyaId;
    _syncDiwaniyaState();
    if (previous != _activeDiwaniyaId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncRemote());
    }
    setState(() {});
  }
  Future<void> _syncRemote() async {
    if (_did.isEmpty || !mounted) return;
    try {
      await MaqadiService.syncForDiwaniya(_did, bumpVersion: false);
      if (!mounted) return;
      if (_catFilter != null && !_allCategories(_did).contains(_catFilter)) {
        _catFilter = null;
      }
      setState(() {});
    } catch (_) {
      // Keep last known cache if backend sync fails.
    }
  }


  String get _did => _activeDiwaniyaId;

  List<MockShoppingItem> get _items =>
      diwaniyaShoppingItems[_did] ?? <MockShoppingItem>[];

  List<MockShoppingItem> get _filtered {
    var list = List<MockShoppingItem>.from(_items);

    if (_filter != 'all') {
      list = list.where((i) => i.status == _filter).toList();
    }

    if (_catFilter != null) {
      list = list.where((i) => i.category == _catFilter).toList();
    }

    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((i) => i.name.toLowerCase().contains(q)).toList();
    }

    return list;
  }

  Map<String, List<MockShoppingItem>> get _grouped {
    final map = <String, List<MockShoppingItem>>{};
    for (final item in _filtered) {
      map.putIfAbsent(item.category, () => <MockShoppingItem>[]).add(item);
    }

    for (final list in map.values) {
      list.sort(
        (a, b) =>
            (_statusOrder[a.status] ?? 9).compareTo(_statusOrder[b.status] ?? 9),
      );
    }

    return map;
  }

  int get _neededCount => _items.where((i) => i.status == 'needed').length;
  int get _lowCount => _items.where((i) => i.status == 'low').length;

  List<String> get _usedCategories =>
      _items.map((i) => i.category).toSet().toList();

  Future<void> _addBatch(List<MockShoppingItem> items) async {
    try {
      await MaqadiService.addBatch(_did, items);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${Ar.itemsAdded} ${items.length} ${Ar.itemUnit}')),
      );
      setState(() {});
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحديث المقاضي')),
      );
    }
  }

  Future<void> _updateItem(
    String id, {
    String? name,
    String? category,
    String? status,
    String? note,
  }) async {
    try {
      await MaqadiService.updateItem(
        _did,
        id,
        name: name,
        category: category,
        status: status,
        note: note,
      );
      if (mounted) setState(() {});
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحديث المقاضي')),
      );
    }
  }

  Future<void> _deleteItem(String id) async {
    try {
      await MaqadiService.deleteItem(_did, id);
      if (mounted) setState(() {});
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حذف العنصر')),
      );
    }
  }

  void _openAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BatchAddSheet(
        diwaniyaId: _did,
        onSave: (items) { _addBatch(items); },
      ),
    );
  }

  void _openQuickEdit(MockShoppingItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuickEditSheet(
        item: item,
        diwaniyaId: _did,
        onSave: (updated) {
          _updateItem(
            item.id,
            name: updated.name,
            category: updated.category,
            status: updated.status,
            note: updated.note,
          );
        },
        onDelete: () { _deleteItem(item.id); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _syncDiwaniyaState();
    final c = context.cl;
    final grouped = _grouped;
    final sortedCats = grouped.keys.toList()
      ..sort((a, b) {
        final all = _allCategories(_did);
        final ai = all.indexOf(a);
        final bi = all.indexOf(b);
        return (ai < 0 ? 999 : ai).compareTo(bi < 0 ? 999 : bi);
      });

    return Scaffold(
      backgroundColor: c.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: c.bg,
            surfaceTintColor: Colors.transparent,
            toolbarHeight: 56,
            centerTitle: false,
            title: Text(
              Ar.maqadi,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: c.t1,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _StatusBadge('$_neededCount', Ar.statusNeeded, c.error),
                        const SizedBox(width: 12),
                        _StatusBadge('$_lowCount', Ar.statusLow, c.warning),
                        const Spacer(),
                        Text(
                          '${_items.length} ${Ar.itemUnit}',
                          style: TextStyle(fontSize: 12, color: c.t3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _search = v.trim()),
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 14, color: c.t1),
                    decoration: InputDecoration(
                      hintText: Ar.searchItems,
                      hintStyle: TextStyle(color: c.t3),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: c.t3,
                        size: 20,
                      ),
                      suffixIcon: _search.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchCtrl.clear();
                                setState(() => _search = '');
                              },
                              child: Icon(
                                Icons.close_rounded,
                                color: c.t3,
                                size: 18,
                              ),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: c.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      children: [
                        _FilterChip(
                          'الكل',
                          _filter == 'all',
                          () => setState(() => _filter = 'all'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          Ar.statusAvailable,
                          _filter == 'available',
                          () => setState(() => _filter = 'available'),
                          color: c.success,
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          Ar.statusLow,
                          _filter == 'low',
                          () => setState(() => _filter = 'low'),
                          color: c.warning,
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          Ar.statusNeeded,
                          _filter == 'needed',
                          () => setState(() => _filter = 'needed'),
                          color: c.error,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_usedCategories.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: SizedBox(
                        height: 34,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          children: [
                            _FilterChip(
                              Ar.allCategories,
                              _catFilter == null,
                              () => setState(() => _catFilter = null),
                            ),
                            ..._usedCategories.map(
                              (cat) => Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: _FilterChip(
                                  cat,
                                  _catFilter == cat,
                                  () => setState(() => _catFilter = cat),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          if (_items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 48,
                      color: c.t3,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      Ar.noItems,
                      style: TextStyle(fontSize: 14, color: c.t3),
                    ),
                  ],
                ),
              ),
            )
          else if (_filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 48,
                      color: c.t3,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _search.isNotEmpty
                          ? Ar.noSearchResults
                          : Ar.noFilterResults,
                      style: TextStyle(fontSize: 14, color: c.t3),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  sortedCats.expand((cat) {
                    final items = grouped[cat]!;
                    final isCollapsed = _collapsed.contains(cat);
                    return [
                      _CategoryHeader(
                        category: cat,
                        count: items.length,
                        icon: _iconForCategory(cat),
                        isCollapsed: isCollapsed,
                        onToggle: () => setState(() {
                          if (isCollapsed) {
                            _collapsed.remove(cat);
                          } else {
                            _collapsed.add(cat);
                          }
                        }),
                      ),
                      if (!isCollapsed)
                        ...items.map(
                          (item) => _ItemTile(
                            item: item,
                            onTap: () => _openQuickEdit(item),
                            onStatusChange: (status) =>
                                _updateItem(item.id, status: status),
                          ),
                        ),
                      const SizedBox(height: 10),
                    ];
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddSheet,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _BatchAddSheet extends StatefulWidget {
  final String diwaniyaId;
  final ValueChanged<List<MockShoppingItem>> onSave;

  const _BatchAddSheet({
    required this.diwaniyaId,
    required this.onSave,
  });

  @override
  State<_BatchAddSheet> createState() => _BatchAddSheetState();
}

class _BatchAddSheetState extends State<_BatchAddSheet> {
  final _inputCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _catNameCtrl = TextEditingController();

  late String _category;
  String _status = 'needed';

  bool get _isManager => UserService.isManager(widget.diwaniyaId);
  List<String> get _cats => _allCategories(widget.diwaniyaId);

  bool _isDefaultCategory(String category) =>
      _defaultCategories.contains(category.trim());

  bool _categoryHasItems(String category) {
    final trimmed = category.trim();
    if (trimmed.isEmpty) return false;
    return (diwaniyaShoppingItems[widget.diwaniyaId] ?? <MockShoppingItem>[])
        .any((item) => item.category.trim() == trimmed);
  }

  bool _canDeleteCategory(String category) =>
      _isManager && !_isDefaultCategory(category) && !_categoryHasItems(category);

  @override
  void initState() {
    super.initState();
    _category = _defaultCategories.first;
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _noteCtrl.dispose();
    _catNameCtrl.dispose();
    super.dispose();
  }

  void _processInput(String raw) {
    final parts = raw
        .split(RegExp(r'[،,\n]'))
        .map((part) => part.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();

    if (parts.isEmpty) return;

    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    final now = DateTime.now();

    final items = parts
        .map(
          (name) => MockShoppingItem(
            id: 'mq_${now.microsecondsSinceEpoch}_${name.hashCode}',
            name: name,
            category: _category,
            status: _status,
            updatedBy: UserService.currentName,
            updatedAt: now,
            note: note,
            icon: _iconForCategory(_category),
          ),
        )
        .toList();

    _inputCtrl.clear();
    widget.onSave(items);
    setState(() {});
  }

  Future<void> _deleteCustomCategory(String category) async {
    final trimmed = category.trim();
    if (trimmed.isEmpty || _isDefaultCategory(trimmed)) return;

    final messenger = ScaffoldMessenger.of(context);

    if (_categoryHasItems(trimmed)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('لا يمكن حذف التصنيف لوجود مقاضي مرتبطة به'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dc = dialogContext.cl;
        return AlertDialog(
          backgroundColor: dc.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'حذف التصنيف',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: dc.t1,
            ),
          ),
          content: Text(
            'هل تريد حذف تصنيف "$trimmed"؟',
            style: TextStyle(color: dc.t2),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('إلغاء', style: TextStyle(color: dc.t3)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                'حذف',
                style: TextStyle(
                  color: dc.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final deleted = await MaqadiService.deleteCustomCategory(
        widget.diwaniyaId,
        trimmed,
      );
      if (!mounted) return;

      if (deleted) {
        if (_category == trimmed) _category = _defaultCategories.first;
        setState(() {});
        messenger.showSnackBar(
          const SnackBar(content: Text('تم حذف التصنيف')),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      final msg = e.code == ApiErrorCode.conflict
          ? 'لا يمكن حذف التصنيف لوجود مقاضي مرتبطة به'
          : 'تعذر حذف التصنيف';
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('تعذر حذف التصنيف')),
      );
    }
  }

  void _addCustomCategory() {
    if (_totalCategoryCount(widget.diwaniyaId) >= 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(Ar.categoryLimit)),
      );
      return;
    }

    _catNameCtrl.clear();

    showDialog(
      context: context,
      builder: (dialogContext) {
        final dc = dialogContext.cl;
        return AlertDialog(
          backgroundColor: dc.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            Ar.addCategory,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: dc.t1,
            ),
          ),
          content: TextField(
            controller: _catNameCtrl,
            autofocus: true,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: TextStyle(color: dc.t1),
            decoration: InputDecoration(
              hintText: Ar.addCategory,
              hintStyle: TextStyle(color: dc.t3),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                Ar.cancel,
                style: TextStyle(color: dc.t3),
              ),
            ),
            TextButton(
              onPressed: () async {
                final name = _catNameCtrl.text.trim();
                if (name.isEmpty) return;

                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(dialogContext);

                if (_cats.contains(name)) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text(Ar.categoryExists)),
                  );
                  return;
                }

                try {
                  final added = await MaqadiService.addCustomCategory(
                    widget.diwaniyaId,
                    name,
                  );

                  await MaqadiService.syncForDiwaniya(
                    widget.diwaniyaId,
                    bumpVersion: false,
                  );

                  if (!mounted) return;

                  final existsNow = _allCategories(widget.diwaniyaId).contains(name);
                  if (!added && !existsNow) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text(Ar.categoryExists)),
                    );
                    return;
                  }

                  navigator.pop();
                  setState(() => _category = name);
                } catch (_) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    const SnackBar(content: Text('تعذر إضافة التصنيف')),
                  );
                }
              },
              child: Text(
                Ar.confirm,
                style: TextStyle(
                  color: dc.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Handle(c),
            const SizedBox(height: 14),
            Center(
              child: Text(
                Ar.addItemsBatch,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: c.t1,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Text(
                  Ar.itemCategory,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.t2,
                  ),
                ),
                const Spacer(),
                if (_isManager)
                  GestureDetector(
                    onTap: _addCustomCategory,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 14, color: c.accent),
                        const SizedBox(width: 2),
                        Text(
                          Ar.addCategory,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: c.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _cats.map((cat) {
                final selected = _category == cat;
                final canDelete = _canDeleteCategory(cat);
                return Container(
                  decoration: BoxDecoration(
                    color: selected
                        ? c.accent.withValues(alpha: 0.15)
                        : c.inputBg,
                    borderRadius: BorderRadius.circular(10),
                    border: selected
                        ? Border.all(
                            color: c.accent.withValues(alpha: 0.4),
                          )
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _category = cat),
                        child: Padding(
                          padding: EdgeInsetsDirectional.only(
                            start: 12,
                            end: canDelete ? 6 : 12,
                            top: 8,
                            bottom: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _iconForCategory(cat),
                                size: 14,
                                color: selected ? c.accent : c.t3,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                cat,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: selected ? c.accent : c.t2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (canDelete)
                        GestureDetector(
                          onTap: () => _deleteCustomCategory(cat),
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(
                              start: 2,
                              end: 8,
                              top: 8,
                              bottom: 8,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: c.t3,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            Text(
              Ar.changeStatus,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.t2,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _StatusBtn(
                    Ar.statusNeeded,
                    'needed',
                    _status == 'needed',
                    c.error,
                    () => setState(() => _status = 'needed'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatusBtn(
                    Ar.statusLow,
                    'low',
                    _status == 'low',
                    c.warning,
                    () => setState(() => _status = 'low'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatusBtn(
                    Ar.statusAvailable,
                    'available',
                    _status == 'available',
                    c.success,
                    () => setState(() => _status = 'available'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              Ar.itemName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.t2,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _inputCtrl,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 14, color: c.t1),
              decoration: InputDecoration(
                hintText: 'اكتب الصنف ثم اضغط + للإضافة',
                hintStyle: TextStyle(
                  color: c.t3,
                  fontSize: 12,
                ),
                suffixIcon: GestureDetector(
                  onTap: () => _processInput(_inputCtrl.text),
                  child: Container(
                    margin: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: c.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              onSubmitted: _processInput,
            ),
            const SizedBox(height: 14),
            Text(
              Ar.itemNote,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.t2,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 14, color: c.t1),
              decoration: InputDecoration(
                hintText: Ar.sharedNote,
                hintStyle: TextStyle(color: c.t3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickEditSheet extends StatefulWidget {
  final MockShoppingItem item;
  final String diwaniyaId;
  final ValueChanged<MockShoppingItem> onSave;
  final VoidCallback onDelete;

  const _QuickEditSheet({
    required this.item,
    required this.diwaniyaId,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_QuickEditSheet> createState() => _QuickEditSheetState();
}

class _QuickEditSheetState extends State<_QuickEditSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _noteCtrl;
  late String _category;
  late String _status;

  bool get _isValid => _nameCtrl.text.trim().isNotEmpty;
  List<String> get _cats => _allCategories(widget.diwaniyaId);

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.name);
    _noteCtrl = TextEditingController(text: widget.item.note ?? '');
    _category = widget.item.category;
    _status = widget.item.status;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_isValid) return;

    widget.onSave(
      MockShoppingItem(
        id: widget.item.id,
        name: _nameCtrl.text.trim(),
        category: _category,
        status: _status,
        updatedBy: UserService.currentName,
        updatedAt: DateTime.now(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        icon: _iconForCategory(_category),
      ),
    );

    Navigator.pop(context);
  }

  void _delete() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final dc = dialogContext.cl;
        return AlertDialog(
          backgroundColor: dc.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            Ar.deleteMaqadiItem,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: dc.t1,
            ),
          ),
          content: Text(
            Ar.deleteMaqadiConfirm,
            style: TextStyle(color: dc.t2),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                Ar.cancel,
                style: TextStyle(color: dc.t2),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pop(context);
                widget.onDelete();
              },
              child: Text(
                Ar.delete,
                style: TextStyle(
                  color: dc.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final meta = <String>[];
    if (widget.item.updatedBy != null) {
      meta.add('حدّثه ${widget.item.updatedBy}');
    }
    if (widget.item.updatedAt != null) {
      meta.add(_timeAgo(widget.item.updatedAt!));
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Handle(c),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    Ar.quickEdit,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: c.t1,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _delete,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c.errorM,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: c.error,
                    ),
                  ),
                ),
              ],
            ),
            if (meta.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                meta.join(' · '),
                style: TextStyle(fontSize: 11, color: c.t3),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              Ar.changeStatus,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.t2,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _StatusBtn(
                    Ar.statusNeeded,
                    'needed',
                    _status == 'needed',
                    c.error,
                    () => setState(() => _status = 'needed'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatusBtn(
                    Ar.statusLow,
                    'low',
                    _status == 'low',
                    c.warning,
                    () => setState(() => _status = 'low'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatusBtn(
                    Ar.statusAvailable,
                    'available',
                    _status == 'available',
                    c.success,
                    () => setState(() => _status = 'available'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              Ar.itemName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.t2,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              onChanged: (_) => setState(() {}),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 14, color: c.t1),
              decoration: InputDecoration(
                hintText: Ar.itemName,
                hintStyle: TextStyle(color: c.t3),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              Ar.itemCategory,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.t2,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _cats.map((cat) {
                final selected = _category == cat;
                return GestureDetector(
                  onTap: () => setState(() => _category = cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? c.accent.withValues(alpha: 0.15)
                          : c.inputBg,
                      borderRadius: BorderRadius.circular(10),
                      border: selected
                          ? Border.all(
                              color: c.accent.withValues(alpha: 0.4),
                            )
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _iconForCategory(cat),
                          size: 14,
                          color: selected ? c.accent : c.t3,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          cat,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: selected ? c.accent : c.t2,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            Text(
              Ar.itemNote,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.t2,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 14, color: c.t1),
              decoration: InputDecoration(
                hintText: 'ملاحظة إضافية',
                hintStyle: TextStyle(color: c.t3),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isValid ? _save : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isValid ? c.accent : c.inputBg,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: Text(
                  Ar.saveItem,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _isValid ? c.tInverse : c.t3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  final String category;
  final int count;
  final IconData icon;
  final bool isCollapsed;
  final VoidCallback onToggle;

  const _CategoryHeader({
    required this.category,
    required this.count,
    required this.icon,
    required this.isCollapsed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: c.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                category,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: c.t1,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: c.accentMuted,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: c.accent,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isCollapsed
                  ? Icons.expand_more_rounded
                  : Icons.expand_less_rounded,
              size: 20,
              color: c.t3,
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final MockShoppingItem item;
  final VoidCallback onTap;
  final ValueChanged<String> onStatusChange;

  const _ItemTile({
    required this.item,
    required this.onTap,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final sc = _statusColor(item.status, c);

    final meta = <String>[];
    if (item.updatedBy != null) {
      meta.add(item.updatedBy!);
    }
    if (item.updatedAt != null) {
      meta.add(_timeAgo(item.updatedAt!));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: sc.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  item.icon,
                  size: 16,
                  color: sc,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.t1,
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        meta.join(' · '),
                        style: TextStyle(
                          fontSize: 10,
                          color: c.t3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  final next = item.status == 'needed'
                      ? 'low'
                      : item.status == 'low'
                          ? 'available'
                          : 'needed';
                  onStatusChange(next);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: sc.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    _statusLabel(item.status),
                    style: TextStyle(
                      fontSize: 10,
                      color: sc,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  final CL c;

  const _Handle(this.c);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: c.t3.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String count;
  final String label;
  final Color color;

  const _StatusBadge(this.count, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              count,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip(
    this.label,
    this.selected,
    this.onTap, {
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final clr = color ?? c.accent;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? clr.withValues(alpha: 0.12) : c.card,
          borderRadius: BorderRadius.circular(18),
          border: selected
              ? Border.all(color: clr.withValues(alpha: 0.3))
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? clr : c.t2,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBtn extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _StatusBtn(
    this.label,
    this.value,
    this.selected,
    this.color,
    this.onTap,
  );

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : c.inputBg,
          borderRadius: BorderRadius.circular(8),
          border: selected
              ? Border.all(color: color.withValues(alpha: 0.4))
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? color : c.t3,
            ),
          ),
        ),
      ),
    );
  }
}