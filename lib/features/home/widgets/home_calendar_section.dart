import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';
import '../../../core/services/calendar_service.dart';
import '../../../core/services/user_service.dart';
import 'home_handle.dart';

class HomeCalendarSection extends StatefulWidget {
  final List<DiwaniyaCalendarEvent> events;
  final bool isManager;
  final void Function(DateTime day) onCreate;
  final void Function(DiwaniyaCalendarEvent event) onAttendToggle;
  final void Function(DiwaniyaCalendarEvent event) onEdit;
  final void Function(DiwaniyaCalendarEvent event) onDelete;

  const HomeCalendarSection({
    super.key,
    required this.events,
    required this.isManager,
    required this.onCreate,
    required this.onAttendToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<HomeCalendarSection> createState() => _HomeCalendarSectionState();
}

class _HomeCalendarSectionState extends State<HomeCalendarSection> {
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _startOfDay(DateTime.now());
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _startOfWeek(DateTime d) {
    final day = _startOfDay(d);
    final diff = (day.weekday + 1) % 7; // Saturday = 0
    return day.subtract(Duration(days: diff));
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<DateTime> get _weekDays {
    final start = _startOfWeek(_selectedDay);
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  List<DiwaniyaCalendarEvent> _eventsForDay(DateTime day) {
    return widget.events
        .where((e) => !e.isCancelled && _sameDay(e.startsAt.toLocal(), day))
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  List<DiwaniyaCalendarEvent> get _upcomingEvents {
    final now = DateTime.now();
    return widget.events
        .where((e) => !e.isCancelled && e.startsAt.toLocal().isAfter(now.subtract(const Duration(minutes: 1))))
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  int _weekEventCount() {
    final start = _startOfWeek(DateTime.now());
    final end = start.add(const Duration(days: 7));
    return widget.events.where((e) {
      final local = e.startsAt.toLocal();
      return !e.isCancelled && !local.isBefore(start) && local.isBefore(end);
    }).length;
  }

  int _selectedAttendanceCount() {
    final ids = <String>{};
    for (final e in _eventsForDay(_selectedDay)) {
      if (e.isAttending) ids.add(UserService.currentName.trim());
      // Backend currently returns aggregate count, not attendees list.
      // We show event attendee totals separately in event cards.
    }
    return ids.length;
  }

  String _summaryText() {
    final events = _eventsForDay(_selectedDay);
    if (events.isEmpty) return 'لا توجد مناسبات اليوم';

    final total = events.length;
    if (total == 1) return 'مناسبة واحدة اليوم';
    if (total == 2) return 'مناسبتان اليوم';
    if (total <= 10) return '$total مناسبات اليوم';
    return '$total مناسبة اليوم';
  }

  String _headlineText() {
    final upcoming = _upcomingEvents;
    if (upcoming.isEmpty) return 'لا توجد مناسبات قريبة';

    final first = upcoming.first.startsAt.toLocal();
    final today = _startOfDay(DateTime.now());
    final firstDay = _startOfDay(first);
    final time = _timeText(first);

    if (firstDay == today) return 'أقرب مناسبة اليوم $time';

    final count = _weekEventCount();
    if (count == 1) return 'مناسبة هذا الأسبوع';
    if (count == 2) return 'مناسبتان هذا الأسبوع';
    if (count >= 3 && count <= 10) return '$count مناسبات هذا الأسبوع';
    return 'لا توجد مناسبات قريبة';
  }

  String _timeText(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour;
    final m = local.minute.toString().padLeft(2, '0');
    final suffix = h >= 12 ? 'م' : 'ص';
    final displayHour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$displayHour:$m $suffix';
  }

  String _dateTitle(DateTime day) {
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return '${day.day} ${months[day.month - 1]}';
  }

  bool _canManage(DiwaniyaCalendarEvent event) {
    return widget.isManager || event.createdByName.trim() == UserService.currentName.trim();
  }

  void _select(DateTime day) {
    setState(() => _selectedDay = _startOfDay(day));
  }

  void _goToday() {
    setState(() => _selectedDay = _startOfDay(DateTime.now()));
  }

  bool _canAddForSelectedDay() {
    return _eventsForDay(_selectedDay).length < 4;
  }

  void _createForSelectedDay() {
    if (!_canAddForSelectedDay()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نكتفي بمناسبات اليوم')),
      );
      return;
    }
    widget.onCreate(_selectedDay);
  }

  void _openMonthPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MonthPickerSheet(
        initialDay: _selectedDay,
        eventsForDay: _eventsForDay,
        onSelect: (day) {
          Navigator.pop(context);
          _select(day);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final selectedEvents = _eventsForDay(_selectedDay);
    final attendanceCount = _selectedAttendanceCount();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.border.withValues(alpha: 0.75)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CalendarTopBar(
            title: _dateTitle(_selectedDay),
            headline: _headlineText(),
            summary: _summaryText(),
            attendanceCount: attendanceCount,
            onToday: _goToday,
            onMonth: _openMonthPicker,
            onCreate: _createForSelectedDay,
          ),
          const SizedBox(height: 14),
          _WeekStrip(
            days: _weekDays,
            selectedDay: _selectedDay,
            eventsForDay: _eventsForDay,
            onSelect: _select,
          ),
          const SizedBox(height: 14),
          _SelectedDayPanel(
            selectedDay: _selectedDay,
            events: selectedEvents,
            canManage: _canManage,
            onCreate: _createForSelectedDay,
            onAttendToggle: widget.onAttendToggle,
            onEdit: widget.onEdit,
            onDelete: widget.onDelete,
            timeText: _timeText,
          ),
        ],
      ),
    );
  }
}

class _CalendarTopBar extends StatelessWidget {
  final String title;
  final String headline;
  final String summary;
  final int attendanceCount;
  final VoidCallback onToday;
  final VoidCallback onMonth;
  final VoidCallback onCreate;

  const _CalendarTopBar({
    required this.title,
    required this.headline,
    required this.summary,
    required this.attendanceCount,
    required this.onToday,
    required this.onMonth,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToday,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(Icons.today_rounded, color: c.accent, size: 22),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: c.t1,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  height: 1.08,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                headline,
                style: TextStyle(
                  color: c.t3,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                attendanceCount > 0 ? '$attendanceCount حضور مسجل · $summary' : summary,
                style: TextStyle(
                  color: c.t2,
                  fontSize: 12.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          children: [
            _MiniAction(
              label: 'مناسبة',
              icon: Icons.add_rounded,
              onTap: onCreate,
              filled: true,
            ),
            const SizedBox(height: 8),
            _MiniAction(
              label: 'الشهر',
              icon: Icons.calendar_month_rounded,
              onTap: onMonth,
              filled: false,
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  const _MiniAction({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final fg = filled ? Colors.white : c.accent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        width: 82,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
        decoration: BoxDecoration(
          color: filled ? c.accent : c.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(13),
          border: filled ? null : Border.all(color: c.accent.withValues(alpha: 0.20)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fg, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 11.6,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  final List<DateTime> days;
  final DateTime selectedDay;
  final List<DiwaniyaCalendarEvent> Function(DateTime day) eventsForDay;
  final void Function(DateTime day) onSelect;

  const _WeekStrip({
    required this.days,
    required this.selectedDay,
    required this.eventsForDay,
    required this.onSelect,
  });

  static const _dayNames = ['سبت', 'أحد', 'اثن', 'ثلث', 'أربع', 'خميس', 'جمعة'];

  @override
  Widget build(BuildContext context) {
    final start = days.first.subtract(const Duration(days: 7));
    final scrollDays = List.generate(21, (i) => start.add(Duration(days: i)));

    return SizedBox(
      height: 66,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: true,
        itemCount: scrollDays.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (_, i) {
          final day = scrollDays[i];
          final label = _dayNames[i % 7];
          return SizedBox(
            width: 58,
            child: _DayCell(
              label: label,
              day: day,
              selected: _sameDay(day, selectedDay),
              currentMonth: true,
              events: eventsForDay(day),
              onTap: () => onSelect(day),
            ),
          );
        },
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayCell extends StatelessWidget {
  final String label;
  final DateTime day;
  final bool selected;
  final bool currentMonth;
  final List<DiwaniyaCalendarEvent> events;
  final VoidCallback onTap;
  final bool compact;

  const _DayCell({
    required this.label,
    required this.day,
    required this.selected,
    required this.currentMonth,
    required this.events,
    required this.onTap,
    this.compact = false,
  });

  bool get _hasAttendance => events.any((e) => e.isAttending);

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final today = DateTime.now();
    final isToday = today.year == day.year && today.month == day.month && today.day == day.day;

    final bg = selected
        ? c.accent
        : isToday
            ? c.accent.withValues(alpha: 0.08)
            : c.inputBg;

    final fg = selected
        ? Colors.white
        : currentMonth
            ? c.t1
            : c.t3.withValues(alpha: 0.45);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: compact ? 38 : 62,
        padding: EdgeInsets.symmetric(vertical: compact ? 6 : 7, horizontal: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? c.accent
                : isToday
                    ? c.accent.withValues(alpha: 0.24)
                    : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!compact)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: selected ? Colors.white.withValues(alpha: 0.90) : c.t3,
                    fontSize: 9.4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            if (!compact) const SizedBox(height: 3),
            Text(
              '${day.day}',
              style: TextStyle(
                color: fg,
                fontSize: compact ? 12.4 : 16,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (events.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(minWidth: 13),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: selected ? Colors.white.withValues(alpha: 0.22) : c.accent.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        events.length == 1 ? '•' : '${events.length}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected ? Colors.white : c.accent,
                          fontSize: 8.6,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                  if (_hasAttendance) ...[
                    const SizedBox(width: 3),
                    Icon(
                      Icons.check_circle_rounded,
                      size: 9.5,
                      color: selected ? Colors.white : c.success,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedDayPanel extends StatelessWidget {
  final DateTime selectedDay;
  final List<DiwaniyaCalendarEvent> events;
  final bool Function(DiwaniyaCalendarEvent event) canManage;
  final VoidCallback onCreate;
  final void Function(DiwaniyaCalendarEvent event) onAttendToggle;
  final void Function(DiwaniyaCalendarEvent event) onEdit;
  final void Function(DiwaniyaCalendarEvent event) onDelete;
  final String Function(DateTime dt) timeText;

  const _SelectedDayPanel({
    required this.selectedDay,
    required this.events,
    required this.canManage,
    required this.onCreate,
    required this.onAttendToggle,
    required this.onEdit,
    required this.onDelete,
    required this.timeText,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    if (events.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: c.inputBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.border.withValues(alpha: 0.58)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(Icons.event_busy_rounded, color: c.t3, size: 19),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'لا توجد مناسبات',
                    style: TextStyle(
                      color: c.t1,
                      fontSize: 13.6,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'أضف مناسبة لهذا اليوم.',
                    style: TextStyle(
                      color: c.t3,
                      fontSize: 12.1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('إضافة'),
              style: TextButton.styleFrom(
                foregroundColor: c.accent,
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      );
    }

    final visible = events.take(4).toList();
    final remaining = events.length - visible.length;

    return Column(
      children: [
        for (final event in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: _EventCard(
              event: event,
              canManage: canManage(event),
              onAttendToggle: () => onAttendToggle(event),
              onEdit: () => onEdit(event),
              onDelete: () => onDelete(event),
              timeText: timeText,
            ),
          ),
        if (remaining > 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: c.inputBg.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border.withValues(alpha: 0.45)),
            ),
            child: Text(
              'نكتفي بمناسبات اليوم',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.t3,
                fontSize: 12.4,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }
}

class _EventCard extends StatefulWidget {
  final DiwaniyaCalendarEvent event;
  final bool canManage;
  final VoidCallback onAttendToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String Function(DateTime dt) timeText;

  const _EventCard({
    required this.event,
    required this.canManage,
    required this.onAttendToggle,
    required this.onEdit,
    required this.onDelete,
    required this.timeText,
  });

  @override
  State<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<_EventCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final event = widget.event;

    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.inputBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: event.isAttending ? c.success.withValues(alpha: 0.28) : c.border.withValues(alpha: 0.52),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: TextStyle(
                      color: c.t1,
                      fontSize: 14.2,
                      fontWeight: FontWeight.w900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.canManage)
                  PopupMenuButton<String>(
                    tooltip: 'إدارة المناسبة',
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.more_horiz_rounded, color: c.t3, size: 20),
                    onSelected: (value) {
                      if (value == 'edit') widget.onEdit();
                      if (value == 'delete') widget.onDelete();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('تعديل')),
                      PopupMenuItem(value: 'delete', child: Text('حذف')),
                    ],
                  )
                else
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: c.t3,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 6,
              children: [
                _Pill(icon: Icons.schedule_rounded, label: widget.timeText(event.startsAt)),
                _Pill(icon: Icons.groups_rounded, label: '${event.attendeesCount} جاي'),
                if (event.isAttending) _Pill(icon: Icons.check_circle_rounded, label: 'حضورك مسجل', success: true),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((event.description ?? '').trim().isNotEmpty) ...[
                      Text(
                        event.description!.trim(),
                        style: TextStyle(color: c.t2, fontSize: 12.5, height: 1.45),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: event.isAttending
                              ? OutlinedButton(
                                  onPressed: widget.onAttendToggle,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: c.t3,
                                    side: BorderSide(color: c.border),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                                  ),
                                  child: const Text('إلغاء'),
                                )
                              : FilledButton.icon(
                                  onPressed: widget.onAttendToggle,
                                  icon: const Icon(Icons.how_to_reg_rounded, size: 17),
                                  label: const Text('جاي'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: c.accent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 160),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool success;

  const _Pill({
    required this.icon,
    required this.label,
    this.success = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final color = success ? c.success : c.t3;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5.5),
      decoration: BoxDecoration(
        color: c.card.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: success ? c.success : c.t2,
              fontSize: 11.2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthPickerSheet extends StatefulWidget {
  final DateTime initialDay;
  final List<DiwaniyaCalendarEvent> Function(DateTime day) eventsForDay;
  final void Function(DateTime day) onSelect;

  const _MonthPickerSheet({
    required this.initialDay,
    required this.eventsForDay,
    required this.onSelect,
  });

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.initialDay.year, widget.initialDay.month);
  }

  List<DateTime> _monthDays() {
    final first = DateTime(_month.year, _month.month);
    final leading = (first.weekday + 1) % 7;
    final gridStart = first.subtract(Duration(days: leading));
    return List.generate(42, (i) => gridStart.add(Duration(days: i)));
  }

  String _monthTitle() {
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return '${months[_month.month - 1]} ${_month.year}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    const dayNames = ['سبت', 'أحد', 'اثن', 'ثلث', 'أربع', 'خميس', 'جمعة'];
    final days = _monthDays();

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HomeHandle(c),
            const SizedBox(height: 14),
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                  icon: Icon(Icons.chevron_right_rounded, color: c.t2),
                ),
                Expanded(
                  child: Text(
                    _monthTitle(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.t1, fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                  icon: Icon(Icons.chevron_left_rounded, color: c.t2),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: dayNames
                  .map(
                    (d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: TextStyle(color: c.t3, fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: days.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 6,
                childAspectRatio: 0.82,
              ),
              itemBuilder: (_, i) {
                final day = days[i];
                final selected = day.year == widget.initialDay.year &&
                    day.month == widget.initialDay.month &&
                    day.day == widget.initialDay.day;
                return _DayCell(
                  label: '',
                  day: day,
                  selected: selected,
                  currentMonth: day.month == _month.month,
                  events: widget.eventsForDay(day),
                  compact: true,
                  onTap: () => widget.onSelect(day),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class HomeCalendarEventDraft {
  final String title;
  final String? description;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? location;

  const HomeCalendarEventDraft({
    required this.title,
    required this.description,
    required this.startsAt,
    required this.endsAt,
    this.location,
  });
}

class HomeCalendarEventSheet extends StatefulWidget {
  final DiwaniyaCalendarEvent? initial;
  final DateTime? initialDate;
  final Future<void> Function(HomeCalendarEventDraft draft) onSave;

  const HomeCalendarEventSheet({
    super.key,
    this.initial,
    this.initialDate,
    required this.onSave,
  });

  @override
  State<HomeCalendarEventSheet> createState() => _HomeCalendarEventSheetState();
}

class _HomeCalendarEventSheetState extends State<HomeCalendarEventSheet> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late DateTime _startsAt;
  DateTime? _endsAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _title = TextEditingController(text: initial?.title ?? '');
    _description = TextEditingController(text: initial?.description ?? '');

    final base = widget.initialDate ?? DateTime.now();
    final smartDefault = _smartDefaultTime(base);

    _startsAt = initial?.startsAt.toLocal() ?? smartDefault;
    _endsAt = initial?.endsAt?.toLocal();
  }

  DateTime _smartDefaultTime(DateTime base) {
    final day = DateTime(base.year, base.month, base.day);
    final now = DateTime.now();

    if (day.year == now.year && day.month == now.month && day.day == now.day) {
      if (now.hour >= 21) return now.add(const Duration(hours: 1));
      return DateTime(day.year, day.month, day.day, 21);
    }

    return DateTime(day.year, day.month, day.day, 21);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  void _applySuggestion(String value) {
    setState(() => _title.text = value);
  }

  Future<void> _pickStart() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt),
    );
    if (time == null || !mounted) return;

    setState(() {
      _startsAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (_endsAt != null && _endsAt!.isBefore(_startsAt)) _endsAt = null;
    });
  }

  String _dateText(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year}  $h:$m';
  }

  Future<void> _save() async {
    if (_saving) return;
    final title = _title.text.trim();
    if (title.isEmpty) return;

    setState(() => _saving = true);
    try {
      await widget.onSave(
        HomeCalendarEventDraft(
          title: title,
          description: _description.text.trim().isEmpty ? null : _description.text.trim(),
          startsAt: _startsAt,
          endsAt: _endsAt,
          location: null,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    const suggestions = ['عشاء', 'مباراة', 'قهوة', 'سهرة', 'اجتماع', 'تحدي'];

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                HomeHandle(c),
                const SizedBox(height: 14),
                Text(
                  widget.initial == null ? 'إضافة مناسبة' : 'تعديل المناسبة',
                  style: TextStyle(color: c.t1, fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: suggestions
                      .map(
                        (s) => ActionChip(
                          label: Text(s),
                          onPressed: () => _applySuggestion(s),
                          backgroundColor: c.accent.withValues(alpha: 0.10),
                          labelStyle: TextStyle(color: c.accent, fontWeight: FontWeight.w900),
                          side: BorderSide(color: c.accent.withValues(alpha: 0.18)),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),
                _Field(controller: _title, label: 'عنوان المناسبة'),
                const SizedBox(height: 12),
                _Field(controller: _description, label: 'وصف مختصر', maxLines: 3),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _pickStart,
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.inputBg,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.event_rounded, color: c.accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _dateText(_startsAt),
                            style: TextStyle(color: c.t1, fontWeight: FontWeight.w900),
                          ),
                        ),
                        Icon(Icons.edit_calendar_rounded, color: c.t3),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: c.accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: Text(_saving ? 'جاري الحفظ...' : 'حفظ المناسبة'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;

  const _Field({
    required this.controller,
    required this.label,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textDirection: TextDirection.rtl,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: c.inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: c.border),
        ),
      ),
    );
  }
}
