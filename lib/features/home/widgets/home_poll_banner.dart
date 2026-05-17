import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';
import '../../../core/models/mock_data.dart';
import '../../../l10n/ar.dart';

class HomePollBanner extends StatelessWidget {
  final DiwaniyaPoll poll;
  final int activeCount;

  const HomePollBanner({
    super.key,
    required this.poll,
    this.activeCount = 1,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final showMultiple = activeCount > 1;
    const blue = Color(0xFF60A5FA);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: blue.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: blue.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: blue.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.how_to_vote_rounded,
              size: 19,
              color: blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  showMultiple ? '$activeCount ${Ar.activePollsLabel}' : poll.question,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.8,
                    fontWeight: FontWeight.w900,
                    color: c.t1,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  showMultiple
                      ? poll.question
                      : '${poll.totalVotes} من ${poll.totalMembers} صوّتوا',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.7,
                    color: c.t2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: blue.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              showMultiple ? Ar.viewPolls : Ar.voteNow,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: c.tInverse,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
