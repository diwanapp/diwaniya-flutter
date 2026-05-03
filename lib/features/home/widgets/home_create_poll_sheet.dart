import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';
import '../../../l10n/ar.dart';
import 'home_handle.dart';

class HomeCreatePollSheet extends StatefulWidget {
  final void Function(String question, List<String> options) onSave;
  const HomeCreatePollSheet({super.key, required this.onSave});
  @override
  State<HomeCreatePollSheet> createState() => _HomeCreatePollSheetState();
}

class _HomeCreatePollSheetState extends State<HomeCreatePollSheet> {
  final _qCtrl = TextEditingController();
  final _optCtrls = <TextEditingController>[TextEditingController(), TextEditingController()];

  List<String> get _trimmedOpts => _optCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
  bool get _hasDuplicates => _trimmedOpts.length != _trimmedOpts.toSet().length;
  bool get _isValid => _qCtrl.text.trim().isNotEmpty && _trimmedOpts.length >= 2 && !_hasDuplicates;

  @override
  void dispose() {
    _qCtrl.dispose();
    for (final controller in _optCtrls) { controller.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: BoxDecoration(color: c.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeHandle(c),
          const SizedBox(height: 16),
          Center(child: Text(Ar.createPoll,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.t1))),
          const SizedBox(height: 20),
          Text(Ar.pollQuestion, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.t2)),
          const SizedBox(height: 8),
          TextField(controller: _qCtrl, onChanged: (_) => setState(() {}),
            style: TextStyle(color: c.t1), textDirection: TextDirection.rtl, textAlign: TextAlign.right,
            decoration: InputDecoration(hintText: 'مثال: مين حاضر الخميس؟',
                hintStyle: TextStyle(color: c.t3), hintTextDirection: TextDirection.rtl)),
          const SizedBox(height: 16),
          Text(Ar.pollOptions, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.t2)),
          const SizedBox(height: 8),
          ...List.generate(_optCtrls.length, (index) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(controller: _optCtrls[index], onChanged: (_) => setState(() {}),
              style: TextStyle(color: c.t1), textDirection: TextDirection.rtl, textAlign: TextAlign.right,
              decoration: InputDecoration(hintText: 'خيار ${index + 1}',
                  hintStyle: TextStyle(color: c.t3), hintTextDirection: TextDirection.rtl)),
          )),
          GestureDetector(
            onTap: () => setState(() { _optCtrls.add(TextEditingController()); }),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_circle_outline_rounded, size: 16, color: c.accent),
              const SizedBox(width: 6),
              Text(Ar.addOption, style: TextStyle(fontSize: 13, color: c.accent, fontWeight: FontWeight.w600)),
            ]),
          ),
          if (_hasDuplicates) Padding(padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: c.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                Icon(Icons.error_outline_rounded, size: 16, color: c.error),
                const SizedBox(width: 8),
                Expanded(child: Text('لا يمكن تكرار نفس الخيار', style: TextStyle(fontSize: 12, color: c.error))),
              ]),
            )),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
            onPressed: _isValid ? () { widget.onSave(_qCtrl.text.trim(), _trimmedOpts); Navigator.pop(context); } : null,
            style: ElevatedButton.styleFrom(backgroundColor: _isValid ? c.accent : c.inputBg,
                elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
            child: Text(Ar.savePoll, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                color: _isValid ? c.tInverse : c.t3)))),
        ],
      )),
    );
  }
}
