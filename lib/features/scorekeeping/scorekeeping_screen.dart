import 'package:flutter/material.dart';
import '../../config/theme/app_colors.dart';
import '../../l10n/ar.dart';

class _Row {
  int lana;
  int lahom;
  _Row({required this.lana, required this.lahom});
}

class ScorekeepingScreen extends StatefulWidget {
  const ScorekeepingScreen({super.key});
  @override
  State<ScorekeepingScreen> createState() => _ScorekeepingScreenState();
}

class _ScorekeepingScreenState extends State<ScorekeepingScreen> {
  final List<_Row> _rows = [];
  final _lanaCtrl = TextEditingController();
  final _lahomCtrl = TextEditingController();
  int? _editIdx;

  int get _lanaTotal => _rows.fold(0, (s, r) => s + r.lana);
  int get _lahomTotal => _rows.fold(0, (s, r) => s + r.lahom);

  void _save() {
    final lv = int.tryParse(_lanaCtrl.text) ?? 0;
    final hv = int.tryParse(_lahomCtrl.text) ?? 0;
    if (lv <= 0 && hv <= 0) return;
    setState(() {
      if (_editIdx != null) {
        _rows[_editIdx!].lana = lv;
        _rows[_editIdx!].lahom = hv;
        _editIdx = null;
      } else {
        _rows.add(_Row(lana: lv, lahom: hv));
      }
      _lanaCtrl.clear();
      _lahomCtrl.clear();
    });
  }

  void _editRow(int i) {
    final r = _rows[i];
    setState(() {
      _editIdx = i;
      _lanaCtrl.text = r.lana > 0 ? r.lana.toString() : '';
      _lahomCtrl.text = r.lahom > 0 ? r.lahom.toString() : '';
    });
  }

  void _reset() => setState(() {
    _rows.clear();
    _lanaCtrl.clear();
    _lahomCtrl.clear();
    _editIdx = null;
  });

  @override
  void dispose() { _lanaCtrl.dispose(); _lahomCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final lW = _lanaTotal >= _lahomTotal;
    final isEdit = _editIdx != null;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(backgroundColor: c.bg,
        title: Text(Ar.scorekeeping, style: TextStyle(color: c.t1, fontSize: 20, fontWeight: FontWeight.w600)),
        actions: [
          TextButton.icon(onPressed: _reset,
            icon: Icon(Icons.refresh_rounded, size: 18, color: c.accent),
            label: Text(Ar.newGame, style: TextStyle(fontSize: 13, color: c.accent, fontWeight: FontWeight.w600))),
        ]),
      body: Column(children: [
        const SizedBox(height: 16),

        // Score totals
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [
          Expanded(child: _Total(Ar.lana, _lanaTotal, lW, c.accent, c)),
          const SizedBox(width: 12),
          Expanded(child: _Total(Ar.lahom, _lahomTotal, !lW, c.error, c)),
        ])),
        const SizedBox(height: 16),

        // Score table
        Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              // Header
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  Expanded(child: Text(Ar.lana, textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.accent))),
                  SizedBox(width: 44, child: Center(child: Text('#', style: TextStyle(fontSize: 11, color: c.t3)))),
                  Expanded(child: Text(Ar.lahom, textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.error))),
                ])),
              Divider(height: 1, color: c.divider),

              // Input row — single save button in center
              Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(children: [
                  Expanded(child: TextField(controller: _lanaCtrl,
                    keyboardType: TextInputType.number, textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.accent),
                    decoration: InputDecoration(
                      hintText: Ar.lana, hintStyle: TextStyle(fontSize: 12, color: c.t3),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10), isDense: true,
                      filled: true, fillColor: c.accent.withValues(alpha: 0.06),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: c.accent.withValues(alpha: 0.3)))),
                    onSubmitted: (_) => _save())),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: GestureDetector(onTap: _save,
                      child: Container(width: 36, height: 36,
                        decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(9)),
                        child: Icon(isEdit ? Icons.check_rounded : Icons.add_rounded, size: 18, color: Colors.white)))),
                  Expanded(child: TextField(controller: _lahomCtrl,
                    keyboardType: TextInputType.number, textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.error),
                    decoration: InputDecoration(
                      hintText: Ar.lahom, hintStyle: TextStyle(fontSize: 12, color: c.t3),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10), isDense: true,
                      filled: true, fillColor: c.error.withValues(alpha: 0.06),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: c.error.withValues(alpha: 0.3)))),
                    onSubmitted: (_) => _save())),
                ])),
              Divider(height: 1, color: c.divider),

              // Rows list
              Expanded(child: _rows.isEmpty
                ? Center(child: Text('ابدأ بإضافة النتائج', style: TextStyle(color: c.t3, fontSize: 14)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _rows.length,
                    itemBuilder: (_, i) {
                      final idx = _rows.length - 1 - i;
                      final r = _rows[idx];
                      final isEd = _editIdx == idx;
                      return GestureDetector(onTap: () => _editRow(idx),
                        child: Container(
                          color: isEd ? c.accentMuted : Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(children: [
                            Expanded(child: Text(r.lana > 0 ? '${r.lana}' : '—', textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                                color: r.lana > 0 ? c.accent : c.t3))),
                            SizedBox(width: 44, child: Center(child: Container(
                              width: 22, height: 22,
                              decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.12), shape: BoxShape.circle),
                              child: Center(child: Text('${idx + 1}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.t3)))))),
                            Expanded(child: Text(r.lahom > 0 ? '${r.lahom}' : '—', textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                                color: r.lahom > 0 ? c.error : c.t3))),
                          ])));
                    })),
            ]),
          ),
        )),
        const SizedBox(height: 16),
      ]),
    );
  }
}

class _Total extends StatelessWidget {
  final String label; final int total; final bool win; final Color color; final CL c;
  const _Total(this.label, this.total, this.win, this.color, this.c);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 18),
    decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16),
      border: win ? Border.all(color: color.withValues(alpha: 0.3), width: 1.5) : null),
    child: Column(children: [
      Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.t2)),
      const SizedBox(height: 6),
      Text('$total', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: win ? color : c.t1)),
    ]));
}
