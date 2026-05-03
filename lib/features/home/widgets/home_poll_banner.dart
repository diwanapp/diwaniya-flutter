import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';
import '../../../core/models/mock_data.dart';
import '../../../l10n/ar.dart';

class HomePollBanner extends StatelessWidget {
  final DiwaniyaPoll poll;
  final int activeCount;
  const HomePollBanner({super.key, required this.poll, this.activeCount = 1});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final showMultiple = activeCount > 1;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.accentSurface, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.accent.withValues(alpha: 0.15)),
      ),
      child: Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(color: c.accentMuted, borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.how_to_vote_rounded, size: 20, color: c.accent)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(showMultiple ? '$activeCount ${Ar.activePollsLabel}' : poll.question,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.t1)),
          const SizedBox(height: 2),
          Text(showMultiple ? poll.question : '${poll.totalVotes} من ${poll.totalMembers} صوّتوا',
              style: TextStyle(fontSize: 12, color: c.t2), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(8)),
          child: Text(showMultiple ? Ar.viewPolls : Ar.voteNow,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.tInverse)),
        ),
      ]),
    );
  }
}
