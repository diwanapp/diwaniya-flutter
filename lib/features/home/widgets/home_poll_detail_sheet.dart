import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';
import '../../../core/models/mock_data.dart';
import '../../../core/services/user_service.dart';
import '../../../l10n/ar.dart';
import 'home_handle.dart';

class HomePollDetailSheet extends StatelessWidget {
  final DiwaniyaPoll poll;
  final bool isManager;
  final void Function(String option)? onVote;
  final VoidCallback? onEnd;

  const HomePollDetailSheet({super.key, required this.poll, this.isManager = false, this.onVote, this.onEnd});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final hasVoted = poll.votedMembers.containsKey(UserService.currentName);
    final myVote = poll.votedMembers[UserService.currentName];
    final maxVotes = poll.votesPerOption.values.fold(0, (a, b) => a > b ? a : b);
    final canChangeVote = hasVoted && poll.isActive;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: c.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        HomeHandle(c),
        const SizedBox(height: 16),
        Text(poll.question, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.t1)),
        const SizedBox(height: 4),
        Text('${poll.totalVotes} من ${poll.totalMembers} صوّتوا', style: TextStyle(fontSize: 13, color: c.t3)),
        if (!poll.isActive) ...[
          const SizedBox(height: 4),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: c.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: Text(Ar.ended, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.error))),
        ],
        if (canChangeVote) ...[
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle_rounded, size: 14, color: c.accent),
              const SizedBox(width: 6),
              Text('${Ar.yourVote}: $myVote · ${Ar.changeVote}',
                  style: TextStyle(fontSize: 12, color: c.accent, fontWeight: FontWeight.w600)),
            ])),
        ],
        const SizedBox(height: 20),
        ...poll.options.map((o) {
          final votes = poll.votesPerOption[o] ?? 0;
          final pct = poll.totalVotes > 0 ? (votes / poll.totalVotes * 100).round() : 0;
          final isLeading = votes == maxVotes && votes > 0;
          final isMyVote = myVote == o;

          if (hasVoted || !poll.isActive) {
            return Padding(padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: (poll.isActive && onVote != null && !isMyVote) ? () => onVote!(o) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isMyVote ? c.accent.withValues(alpha: 0.08) : c.inputBg,
                    borderRadius: BorderRadius.circular(10),
                    border: isMyVote ? Border.all(color: c.accent.withValues(alpha: 0.3)) : null),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(o, style: TextStyle(fontSize: 14,
                          fontWeight: isLeading ? FontWeight.w700 : FontWeight.w500,
                          color: isLeading ? c.accent : c.t1))),
                      if (isMyVote) Icon(Icons.check_circle_rounded, size: 16, color: c.accent),
                      if (isMyVote) const SizedBox(width: 6),
                      Text('$pct%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                          color: isLeading ? c.accent : c.t2)),
                      const SizedBox(width: 6),
                      Text('($votes)', style: TextStyle(fontSize: 11, color: c.t3)),
                    ]),
                    const SizedBox(height: 6),
                    ClipRRect(borderRadius: BorderRadius.circular(3),
                      child: SizedBox(height: 5, child: LinearProgressIndicator(
                          value: pct / 100, backgroundColor: c.divider,
                          color: isLeading ? c.accent : c.t3.withValues(alpha: 0.5)))),
                  ]),
                ),
              ),
            );
          } else {
            return Padding(padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
                onPressed: onVote != null ? () => onVote!(o) : null,
                style: ElevatedButton.styleFrom(backgroundColor: c.inputBg, foregroundColor: c.t1,
                    elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: Text(o, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.t1)))));
          }
        }),
        if (poll.isActive && isManager) ...[
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, height: 44, child: OutlinedButton.icon(
            onPressed: onEnd,
            icon: Icon(Icons.stop_circle_outlined, size: 18, color: c.error),
            label: Text(Ar.endPoll, style: TextStyle(color: c.error, fontSize: 14)),
            style: OutlinedButton.styleFrom(
                side: BorderSide(color: c.error.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
        ],
        const SizedBox(height: 8),
      ])),
    );
  }
}
