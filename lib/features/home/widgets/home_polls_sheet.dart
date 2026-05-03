import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';
import '../../../core/models/mock_data.dart';
import '../../../core/services/user_service.dart';
import '../../../l10n/ar.dart';
import 'home_handle.dart';

class HomePollsSheet extends StatelessWidget {
  final List<DiwaniyaPoll> polls;
  final VoidCallback? onCreatePoll;
  final void Function(DiwaniyaPoll)? onTapPoll;

  const HomePollsSheet({
    super.key,
    required this.polls,
    this.onCreatePoll,
    this.onTapPoll,
  });

  String _monthLabel(DateTime date) {
    const months = <int, String>{
      1: 'يناير',
      2: 'فبراير',
      3: 'مارس',
      4: 'أبريل',
      5: 'مايو',
      6: 'يونيو',
      7: 'يوليو',
      8: 'أغسطس',
      9: 'سبتمبر',
      10: 'أكتوبر',
      11: 'نوفمبر',
      12: 'ديسمبر',
    };
    return '${months[date.month] ?? date.month.toString()} ${date.year}';
  }

  Map<String, List<DiwaniyaPoll>> _groupEndedByMonth(List<DiwaniyaPoll> ended) {
    final grouped = <String, List<DiwaniyaPoll>>{};
    for (final poll in ended) {
      final date = poll.closedAt ?? poll.createdAt;
      final label = _monthLabel(date.toLocal());
      grouped.putIfAbsent(label, () => <DiwaniyaPoll>[]).add(poll);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final active = polls.where((p) => p.isActive).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final ended = polls.where((p) => !p.isActive).toList()
      ..sort((a, b) => (b.closedAt ?? b.createdAt).compareTo(a.closedAt ?? a.createdAt));
    final endedByMonth = _groupEndedByMonth(ended);

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.84),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HomeHandle(c),
          const SizedBox(height: 14),
          Row(
            children: [
              const SizedBox(width: 40),
              Expanded(
                child: Text(
                  Ar.pollsTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: c.t1,
                  ),
                ),
              ),
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  tooltip: Ar.createPoll,
                  onPressed: onCreatePoll,
                  icon: Icon(Icons.add_rounded, color: c.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (polls.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.how_to_vote_outlined, size: 36, color: c.t3),
                  const SizedBox(height: 8),
                  Text(Ar.noPolls, style: TextStyle(fontSize: 13, color: c.t3)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: onCreatePoll,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(Ar.createPoll),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (active.isNotEmpty) ...[
                    Text(
                      'التصويتات القائمة',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.t3),
                    ),
                    const SizedBox(height: 8),
                    ...active.map(
                      (p) => HomePollCard(
                        poll: p,
                        isActive: true,
                        onTap: onTapPoll != null ? () => onTapPoll!(p) : null,
                      ),
                    ),
                  ],
                  if (endedByMonth.isNotEmpty) ...[
                    if (active.isNotEmpty) const SizedBox(height: 16),
                    Text(
                      Ar.ended,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.t3),
                    ),
                    const SizedBox(height: 8),
                    ...endedByMonth.entries.expand(
                      (entry) => <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: Text(
                            entry.key,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.t2),
                          ),
                        ),
                        ...entry.value.map(
                          (p) => HomePollCard(
                            poll: p,
                            isActive: false,
                            onTap: onTapPoll != null ? () => onTapPoll!(p) : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class HomePollCard extends StatelessWidget {
  final DiwaniyaPoll poll;
  final bool isActive;
  final VoidCallback? onTap;

  const HomePollCard({
    super.key,
    required this.poll,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final pct = poll.totalMembers > 0 ? (poll.totalVotes / poll.totalMembers * 100).round() : 0;
    final myVote = poll.votedMembers[UserService.currentName];

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isActive ? c.accentSurface : c.inputBg,
            borderRadius: BorderRadius.circular(14),
            border: isActive ? Border.all(color: c.accent.withValues(alpha: 0.12)) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      poll.question,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.t1),
                    ),
                  ),
                  if (myVote != null) Icon(Icons.check_circle_rounded, size: 14, color: c.accent),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: poll.options.map((o) {
                  final v = poll.votesPerOption[o] ?? 0;
                  final isMine = myVote == o;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isMine ? c.accent.withValues(alpha: 0.12) : c.card,
                      borderRadius: BorderRadius.circular(6),
                      border: isMine ? Border.all(color: c.accent.withValues(alpha: 0.3)) : null,
                    ),
                    child: Text(
                      '$o ($v)',
                      style: TextStyle(
                        fontSize: 11,
                        color: isMine ? c.accent : c.t2,
                        fontWeight: isMine ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: SizedBox(
                        height: 4,
                        child: LinearProgressIndicator(
                          value: pct / 100,
                          color: isActive ? c.accent : c.t3,
                          backgroundColor: c.divider,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${poll.totalVotes}/${poll.totalMembers}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.t3),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
