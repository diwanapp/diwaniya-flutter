import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';
import '../../../core/models/mock_data.dart';
import '../../../l10n/ar.dart';
import 'home_handle.dart';

class HomeMembersSheet extends StatelessWidget {
  final List<DiwaniyaMember> members;
  final String managerId;
  final VoidCallback onAddMember;

  const HomeMembersSheet({super.key, required this.members, required this.managerId, required this.onAddMember});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final sorted = List<DiwaniyaMember>.from(members)
      ..sort((a, b) => a.role == 'manager' ? -1 : (b.role == 'manager' ? 1 : 0));

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.78),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: c.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        HomeHandle(c),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Column(children: [
            Text(Ar.membersTitle, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.t1)),
            const SizedBox(height: 4),
            Text('${members.length} ${Ar.memberUnit}', style: TextStyle(fontSize: 13, color: c.t3)),
          ])),
          IconButton(onPressed: onAddMember,
            style: IconButton.styleFrom(backgroundColor: c.accentMuted,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            icon: Icon(Icons.add_rounded, color: c.accent), tooltip: Ar.addMember),
        ]),
        const SizedBox(height: 16),
        Flexible(child: ListView.separated(
          shrinkWrap: true, itemCount: sorted.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (_, i) {
            final m = sorted[i];
            final isMgr = m.role == 'manager';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: c.inputBg, borderRadius: BorderRadius.circular(12),
                  border: isMgr ? Border.all(color: c.accent.withValues(alpha: 0.2)) : null),
              child: Row(children: [
                CircleAvatar(radius: 20, backgroundColor: m.avatarColor.withValues(alpha: 0.15),
                  child: Text(m.initials, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: m.avatarColor))),
                const SizedBox(width: 12),
                Expanded(child: Text(m.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.t1))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: isMgr ? c.accentMuted : c.cardElevated, borderRadius: BorderRadius.circular(6)),
                  child: Text(isMgr ? Ar.manager : Ar.member,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isMgr ? c.accent : c.t3))),
              ]),
            );
          },
        )),
      ]),
    );
  }
}
