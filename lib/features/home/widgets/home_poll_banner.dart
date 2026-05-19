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
      constraints: const BoxConstraints(minHeight: 104),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            blue.withValues(alpha: 0.115),
            blue.withValues(alpha: 0.045),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: blue.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: blue.withValues(alpha: 0.060),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: blue.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.how_to_vote_rounded,
              size: 25,
              color: blue,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  showMultiple
                      ? '$activeCount ${Ar.activePollsLabel}'
                      : poll.question,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.4,
                    fontWeight: FontWeight.w900,
                    color: c.t1,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  showMultiple
                      ? poll.question
                      : '${poll.totalVotes} من ${poll.totalMembers} صوّتوا',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.4,
                    color: c.t2,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: blue,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: blue.withValues(alpha: 0.18),
                  blurRadius: 11,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Text(
              showMultiple ? Ar.viewPolls : Ar.voteNow,
              style: TextStyle(
                fontSize: 11.6,
                fontWeight: FontWeight.w900,
                color: c.tInverse,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
