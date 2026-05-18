import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';
import '../../core/api/api_exception.dart';
import '../../core/models/mock_data.dart';
import '../../core/services/scorekeeping_service.dart';
import '../../l10n/ar.dart';

class ScorekeepingScreen extends StatefulWidget {
  const ScorekeepingScreen({super.key});

  @override
  State<ScorekeepingScreen> createState() => _ScorekeepingScreenState();
}

class _ScorekeepingScreenState extends State<ScorekeepingScreen> {
  final _lanaCtrl = TextEditingController();
  final _lahomCtrl = TextEditingController();

  ScorekeepingGame? _game;
  bool _loading = true;
  bool _saving = false;

  String get _did => currentDiwaniyaId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _lanaCtrl.dispose();
    _lahomCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_did.trim().isEmpty) {
      setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);
    try {
      final game = await ScorekeepingService.current(_did);
      if (!mounted) return;
      setState(() {
        _game = game;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('تعذر تحميل القيد');
    }
  }

  Future<void> _newGame() async {
    if (_saving || _did.trim().isEmpty) return;

    setState(() => _saving = true);
    try {
      final game = await ScorekeepingService.createGame(_did);
      if (!mounted) return;
      setState(() {
        _game = game;
        _lanaCtrl.clear();
        _lahomCtrl.clear();
      });
    } catch (_) {
      _showError('تعذر بدء لعبة جديدة');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    final game = _game;
    if (game == null || game.isFinished || _saving) return;

    final lv = int.tryParse(_lanaCtrl.text.trim()) ?? 0;
    final hv = int.tryParse(_lahomCtrl.text.trim()) ?? 0;
    if (lv <= 0 && hv <= 0) return;

    final wasFinished = game.isFinished;

    FocusScope.of(context).unfocus();
    _lanaCtrl.clear();
    _lahomCtrl.clear();

    setState(() => _saving = true);
    try {
      final updated = await ScorekeepingService.addRound(
        diwaniyaId: _did,
        gameId: game.id,
        usPoints: lv,
        themPoints: hv,
      );

      if (!mounted) return;
      setState(() {
        _game = updated;
      });

      if (!wasFinished && updated.isFinished) {
        _showWinDialog(updated);
      }
    } on ApiException catch (e) {
      if (e.code == ApiErrorCode.validation || e.code == ApiErrorCode.conflict) {
        _showError('لا يمكن إضافة النتيجة لهذه اللعبة');
      } else {
        _showError(e.message);
      }
    } catch (_) {
      _showError('تعذر حفظ النتيجة');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _advanceDealer() async {
    final game = _game;
    if (game == null || game.isFinished || _saving) return;

    final next = (game.dealerTurn + 1) % 4;
    setState(() => _saving = true);
    try {
      final updated = await ScorekeepingService.updateDealer(
        diwaniyaId: _did,
        gameId: game.id,
        dealerTurn: next,
      );
      if (!mounted) return;
      setState(() => _game = updated);
    } catch (_) {
      _showError('تعذر تحديث السهم');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openLeaderboard() async {
    final c = context.cl;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => FutureBuilder<List<ScorekeepingLeaderboardItem>>(
        future: ScorekeepingService.leaderboard(_did),
        builder: (context, snapshot) {
          final items = snapshot.data ?? const <ScorekeepingLeaderboardItem>[];

          return Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: c.border.withValues(alpha: 0.10)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: c.border.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(Icons.emoji_events_rounded,
                          color: c.warning, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'قائمة الأبطال',
                          style: TextStyle(
                            color: c.t1,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: CircularProgressIndicator(color: c.accent),
                    )
                  else if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'لا توجد صكات مسجلة بعد',
                        style: TextStyle(
                          color: c.t3,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: items.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: c.divider.withValues(alpha: 0.65),
                        ),
                        itemBuilder: (_, i) {
                          final item = items[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: i == 0
                                        ? c.warning.withValues(alpha: 0.16)
                                        : c.inputBg,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${item.rank}',
                                      style: TextStyle(
                                        color: i == 0 ? c.warning : c.t2,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item.names,
                                    style: TextStyle(
                                      color: c.t1,
                                      fontSize: 13.4,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${item.wins} صكة',
                                  style: TextStyle(
                                    color: c.accent,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openPlayersSheet() async {
    final game = _game;
    if (game == null || game.isFinished || _saving) return;

    final c = context.cl;
    final members = currentMembers
        .where((m) => (m.userId ?? '').trim().isNotEmpty)
        .toList(growable: false);

    String? us1 = game.usPlayer1Id;
    String? us2 = game.usPlayer2Id;
    String? them1 = game.themPlayer1Id;
    String? them2 = game.themPlayer2Id;

    List<DropdownMenuItem<String?>> itemsFor(Set<String?> blocked) {
      final items = <DropdownMenuItem<String?>>[
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('بدون اسم'),
        ),
      ];

      for (final member in members) {
        final id = member.userId!.trim();
        if (blocked.contains(id)) continue;
        items.add(
          DropdownMenuItem<String?>(
            value: id,
            child: Text(member.name),
          ),
        );
      }
      return items;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          Widget field({
            required String title,
            required String? value,
            required ValueChanged<String?> onChanged,
            required Set<String?> blocked,
          }) {
            return DropdownButtonFormField<String?>(
              value: value,
              items: itemsFor(blocked),
              onChanged: (v) => setSheetState(() => onChanged(v)),
              decoration: InputDecoration(
                labelText: title,
                filled: true,
                fillColor: c.inputBg.withValues(alpha: 0.65),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            );
          }

          return Container(
            margin: const EdgeInsets.all(12),
            padding: EdgeInsets.fromLTRB(
              16,
              14,
              16,
              18 + MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: c.border.withValues(alpha: 0.10)),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: c.border.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(Icons.groups_rounded, color: c.accent, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'أسماء اللاعبين',
                            style: TextStyle(
                              color: c.t1,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'اختياري. اختر اسمين لكل فريق قبل انتهاء اللعبة حتى تُحسب في قائمة الأبطال.',
                      style: TextStyle(
                        color: c.t3,
                        fontSize: 12,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: field(
                            title: 'لنا - اللاعب الأول',
                            value: us1,
                            blocked: {us2, them1, them2},
                            onChanged: (v) => us1 = v,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: field(
                            title: 'لنا - اللاعب الثاني',
                            value: us2,
                            blocked: {us1, them1, them2},
                            onChanged: (v) => us2 = v,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: field(
                            title: 'لهم - اللاعب الأول',
                            value: them1,
                            blocked: {us1, us2, them2},
                            onChanged: (v) => them1 = v,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: field(
                            title: 'لهم - اللاعب الثاني',
                            value: them2,
                            blocked: {us1, us2, them1},
                            onChanged: (v) => them2 = v,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _savePlayers(
                            usPlayerIds: [
                              if (us1 != null) us1!,
                              if (us2 != null) us2!,
                            ],
                            themPlayerIds: [
                              if (them1 != null) them1!,
                              if (them2 != null) them2!,
                            ],
                          );
                        },
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('حفظ اللاعبين'),
                        style: FilledButton.styleFrom(
                          backgroundColor: c.accent,
                          foregroundColor: c.tInverse,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _savePlayers({
    required List<String> usPlayerIds,
    required List<String> themPlayerIds,
  }) async {
    final game = _game;
    if (game == null || game.isFinished || _saving) return;

    setState(() => _saving = true);
    try {
      final updated = await ScorekeepingService.updatePlayers(
        diwaniyaId: _did,
        gameId: game.id,
        usPlayerIds: usPlayerIds,
        themPlayerIds: themPlayerIds,
      );
      if (!mounted) return;
      setState(() => _game = updated);
    } catch (_) {
      _showError('تعذر حفظ اللاعبين');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showWinDialog(ScorekeepingGame game) {
    final c = context.cl;
    final winner = game.winnerSide == 'us' ? 'لنا' : 'لهم';
    final names = game.winnerSide == 'us'
        ? _teamNames(game.usPlayer1Name, game.usPlayer2Name)
        : _teamNames(game.themPlayer1Name, game.themPlayer2Name);
    final winnerText = names == null ? 'فاز فريق $winner' : 'فاز $names';

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          'مبروك عليكم الصكة',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: c.t1,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.celebration_rounded, color: c.warning, size: 44),
            const SizedBox(height: 12),
            Text(
              winnerText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.t1,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              game.leaderboardRecorded
                  ? '+1 في قائمة الأبطال'
                  : 'لم تُسجل في قائمة الأبطال لعدم تحديد أسماء الفريق',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: game.leaderboardRecorded ? c.success : c.t3,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext, rootNavigator: true).pop();
              Future<void>.delayed(
                const Duration(milliseconds: 80),
                () {
                  if (mounted) {
                    _newGame();
                  }
                },
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: c.accent,
              foregroundColor: c.tInverse,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('لعبة جديدة'),
          ),
        ],
      ),
    );
  }

  String? _teamNames(String? a, String? b) {
    final p1 = (a ?? '').trim();
    final p2 = (b ?? '').trim();
    if (p1.isEmpty || p2.isEmpty) return null;
    return '$p1 و$p2';
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _labelForSide({
    required String side,
    required String fallback,
  }) {
    final game = _game;
    if (game == null) return fallback;
    final names = side == 'us'
        ? _teamNames(game.usPlayer1Name, game.usPlayer2Name)
        : _teamNames(game.themPlayer1Name, game.themPlayer2Name);
    return names ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final game = _game;
    final lW = (game?.usScore ?? 0) >= (game?.themScore ?? 0);
    final disabled = game == null || game.isFinished;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        toolbarHeight: 86,
        titleSpacing: 20,
        centerTitle: false,
        title: Text(
          Ar.scorekeeping,
          style: TextStyle(
            color: c.t1,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.12,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 4),
            child: TextButton.icon(
              onPressed: _openLeaderboard,
              icon: Icon(Icons.emoji_events_rounded, size: 21, color: c.warning),
              label: Text(
                'قائمة الأبطال',
                style: TextStyle(
                  fontSize: 15.5,
                  color: c.t1,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 42),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 10),
            child: TextButton.icon(
              onPressed: _saving ? null : _newGame,
              icon: Icon(Icons.refresh_rounded, size: 19, color: c.accent),
              label: Text(
                Ar.newGame,
                style: TextStyle(
                  fontSize: 13.5,
                  color: c.accent,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 42),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.accent))
          : game == null
              ? Center(
                  child: Text(
                    'لا توجد لعبة حالياً',
                    style: TextStyle(color: c.t3, fontWeight: FontWeight.w700),
                  ),
                )
              : Column(
                  children: [
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: _Total(
                              Ar.lana,
                              _labelForSide(side: 'us', fallback: Ar.lana),
                              game.usScore,
                              lW,
                              c.accent,
                              c,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Total(
                              Ar.lahom,
                              _labelForSide(side: 'them', fallback: Ar.lahom),
                              game.themScore,
                              !lW,
                              c.error,
                              c,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: disabled ? null : _openPlayersSheet,
                              icon: const Icon(Icons.groups_rounded, size: 17),
                              label: const Text('أسماء اللاعبين'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: c.accent,
                                side: BorderSide(
                                  color: c.accent.withValues(alpha: 0.22),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _DealerButton(
                            turn: game.dealerTurn,
                            enabled: !disabled,
                            onTap: _advanceDealer,
                            c: c,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          decoration: BoxDecoration(
                            color: c.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: c.border.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        Ar.lana,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: c.accent,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 44,
                                      child: Center(
                                        child: Text(
                                          '#',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: c.t3,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        Ar.lahom,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: c.error,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Divider(height: 1, color: c.divider),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _lanaCtrl,
                                        enabled: !disabled,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: c.accent,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: Ar.lana,
                                          hintStyle: TextStyle(
                                            fontSize: 12,
                                            color: c.t3,
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                          isDense: true,
                                          filled: true,
                                          fillColor:
                                              c.accent.withValues(alpha: 0.06),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(9),
                                            borderSide: BorderSide.none,
                                          ),
                                        ),
                                        onSubmitted: (_) => _save(),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5),
                                      child: GestureDetector(
                                        onTap: disabled ? null : _save,
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: disabled
                                                ? c.inputBg
                                                : c.accent,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: _saving
                                              ? Padding(
                                                  padding:
                                                      const EdgeInsets.all(9),
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: c.tInverse,
                                                  ),
                                                )
                                              : Icon(
                                                  Icons.add_rounded,
                                                  size: 19,
                                                  color: disabled
                                                      ? c.t3
                                                      : Colors.white,
                                                ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: TextField(
                                        controller: _lahomCtrl,
                                        enabled: !disabled,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: c.error,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: Ar.lahom,
                                          hintStyle: TextStyle(
                                            fontSize: 12,
                                            color: c.t3,
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                          isDense: true,
                                          filled: true,
                                          fillColor:
                                              c.error.withValues(alpha: 0.06),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(9),
                                            borderSide: BorderSide.none,
                                          ),
                                        ),
                                        onSubmitted: (_) => _save(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Divider(height: 1, color: c.divider),
                              Expanded(
                                child: game.rounds.isEmpty
                                    ? Center(
                                        child: Text(
                                          'أضف أول نتيجة للقيد',
                                          style: TextStyle(
                                            color: c.t3,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      )
                                    : ListView.builder(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4),
                                        itemCount: game.rounds.length,
                                        itemBuilder: (_, i) {
                                          final idx = game.rounds.length - 1 - i;
                                          final r = game.rounds[idx];

                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 10,
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    r.usPoints > 0
                                                        ? '${r.usPoints}'
                                                        : '—',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: r.usPoints > 0
                                                          ? c.accent
                                                          : c.t3,
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 44,
                                                  child: Center(
                                                    child: Container(
                                                      width: 22,
                                                      height: 22,
                                                      decoration: BoxDecoration(
                                                        color: c.accent
                                                            .withValues(
                                                                alpha: 0.12),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          '${idx + 1}',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            color: c.t3,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    r.themPoints > 0
                                                        ? '${r.themPoints}'
                                                        : '—',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: r.themPoints > 0
                                                          ? c.error
                                                          : c.t3,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
    );
  }
}

class _Total extends StatelessWidget {
  final String label;
  final String playersLabel;
  final int total;
  final bool win;
  final Color color;
  final CL c;

  const _Total(
    this.label,
    this.playersLabel,
    this.total,
    this.win,
    this.color,
    this.c,
  );

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          border: win
              ? Border.all(color: color.withValues(alpha: 0.28), width: 1.5)
              : Border.all(color: c.border.withValues(alpha: 0.07)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: c.t2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              playersLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '$total',
              style: TextStyle(
                fontSize: 35,
                fontWeight: FontWeight.w900,
                color: win ? color : c.t1,
                height: 1,
              ),
            ),
          ],
        ),
      );
}

class _DealerButton extends StatelessWidget {
  final int turn;
  final bool enabled;
  final VoidCallback onTap;
  final CL c;

  const _DealerButton({
    required this.turn,
    required this.enabled,
    required this.onTap,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final angle = -(math.pi / 2) * turn;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        width: 52,
        height: 42,
        decoration: BoxDecoration(
          color: enabled
              ? c.accent.withValues(alpha: 0.10)
              : c.inputBg.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: c.accent.withValues(alpha: enabled ? 0.18 : 0.05),
          ),
        ),
        child: Center(
          child: Transform.rotate(
            angle: angle,
            child: Icon(
              Icons.navigation_rounded,
              color: enabled ? c.accent : c.t3,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
