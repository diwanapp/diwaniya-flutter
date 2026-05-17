import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';
import '../../../core/services/calendar_service.dart';
import '../../../core/services/user_service.dart';
import 'home_handle.dart';

class HomeCalendarSection extends StatefulWidget {
  final List<DiwaniyaCalendarEvent> events;
  final List<DiwaniyaCalendarDayAttendance> dayAttendance;
  final bool isManager;
  final void Function(DateTime day) onCreate;
  final void Function(DateTime day, bool attending) onDayAttendanceToggle;
  final void Function(DateTime day) onShowDayAttendees;
  final void Function(DiwaniyaCalendarEvent event) onAttendToggle;
  final void Function(DiwaniyaCalendarEvent event) onEdit;
  final void Function(DiwaniyaCalendarEvent event) onDelete;

  const HomeCalendarSection({
    super.key,
    required this.events,
    required this.dayAttendance,
    required this.isManager,
    required this.onCreate,
    required this.onDayAttendanceToggle,
    required this.onShowDayAttendees,
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
    final diff = (day.weekday + 1) % 7;
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

  DiwaniyaCalendarDayAttendance? _attendanceForDay(DateTime day) {
    for (final row in widget.dayAttendance) {
      if (_sameDay(row.date, day)) return row;
    }
    return null;
  }

  int _totalGoingForDay(DateTime day) {
    final row = _attendanceForDay(day);
    if (row != null) return row.totalUniqueAttendeesCount;

    final ids = <String>{};
    for (final e in _eventsForDay(day)) {
      if (e.isAttending) ids.add(UserService.currentName.trim());
    }
    return ids.length;
  }

  bool _isCurrentUserGoing(DateTime day) {
    return _attendanceForDay(day)?.isCurrentUserAttending ?? false;
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

  String _summaryText() {
    final events = _eventsForDay(_selectedDay);
    final going = _totalGoingForDay(_selectedDay);

    if (events.isEmpty && going == 0) return 'لا توجد مناسبات اليوم';
    if (events.isEmpty && going > 0) return '$going جايين اليوم';

    final eventText = events.length == 1
        ? 'مناسبة واحدة'
        : events.length == 2
            ? 'مناسبتان'
            : '${events.length} مناسبات';

    if (going > 0) return '$going جايين اليوم · $eventText';
    return eventText;
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

  bool _canAddForSelectedDay() {
    return _eventsForDay(_selectedDay).length < 4;
  }

  void _select(DateTime day) {
    setState(() => _selectedDay = _startOfDay(day));
  }

  void _goToday() {
    setState(() => _selectedDay = _startOfDay(DateTime.now()));
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

  void _toggleSelectedDayAttendance() {
    widget.onDayAttendanceToggle(
      _selectedDay,
      !_isCurrentUserGoing(_selectedDay),
    );
  }

  void _openMonthPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MonthPickerSheet(
        initialDay: _selectedDay,
        eventsForDay: _eventsForDay,
        attendanceCountForDay: _totalGoingForDay,
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
    final goingCount = _totalGoingForDay(_selectedDay);
    final isGoing = _isCurrentUserGoing(_selectedDay);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.border.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 8),
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
            goingCount: goingCount,
            isGoing: isGoing,
            onToday: _goToday,
            onMonth: _openMonthPicker,
            onCreate: _createForSelectedDay,
            onToggleGoing: _toggleSelectedDayAttendance,
            onShowGoing: () => widget.onShowDayAttendees(_selectedDay),
          ),
          const SizedBox(height: 14),
          _WeekStrip(
            days: _weekDays,
            selectedDay: _selectedDay,
            eventsForDay: _eventsForDay,
            attendanceCountForDay: _totalGoingForDay,
            isCurrentUserGoing: _isCurrentUserGoing,
            onSelect: _select,
          ),
          const SizedBox(height: 14),
          _SelectedDayPanel(
            selectedDay: _selectedDay,
            events: selectedEvents,
            goingCount: goingCount,
            isGoing: isGoing,
            canManage: _canManage,
            onCreate: _createForSelectedDay,
            onAttendToggle: widget.onAttendToggle,
            onEdit: widget.onEdit,
            onDelete: widget.onDelete,
            onToggleDayAttendance: _toggleSelectedDayAttendance,
            onShowGoing: () => widget.onShowDayAttendees(_selectedDay),
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
  final int goingCount;
  final bool isGoing;
  final VoidCallback onToday;
  final VoidCallback onMonth;
  final VoidCallback onCreate;
  final VoidCallback onToggleGoing;
  final VoidCallback onShowGoing;

  const _CalendarTopBar({
    required this.title,
    required this.headline,
    required this.summary,
    required this.goingCount,
    required this.isGoing,
    required this.onToday,
    required this.onMonth,
    required this.onCreate,
    required this.onToggleGoing,
    required this.onShowGoing,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onCreate,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(Icons.event_available_rounded, color: c.accent, size: 22),
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
              const SizedBox(height: 6),
              InkWell(
                onTap: goingCount > 0 ? onShowGoing : null,
                borderRadius: BorderRadius.circular(999),
                child: Text(
                  goingCount > 0 ? '$goingCount جايين اليوم · $summary' : summary,
                  style: TextStyle(
                    color: goingCount > 0 ? c.accent : c.t2,
                    fontSize: 12.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          children: [
            _MiniAction(
              label: isGoing ? 'حضورك مسجل' : 'جاي اليوم',
              icon: isGoing ? Icons.check_circle_rounded : Icons.how_to_reg_rounded,
              onTap: onToggleGoing,
              filled: true,
              compact: isGoing,
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
  final bool compact;

  const _MiniAction({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.filled,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final fg = filled ? Colors.white : c.accent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        width: compact ? 96 : 88,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: filled ? c.accent : c.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: filled ? null : Border.all(color: c.accent.withValues(alpha: 0.20)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fg, size: 16),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg,
                  fontSize: 11.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekStrip extends StatefulWidget {
  final List<DateTime> days;
  final DateTime selectedDay;
  final List<DiwaniyaCalendarEvent> Function(DateTime day) eventsForDay;
  final int Function(DateTime day) attendanceCountForDay;
  final bool Function(DateTime day) isCurrentUserGoing;
  final void Function(DateTime day) onSelect;

  const _WeekStrip({
    required this.days,
    required this.selectedDay,
    required this.eventsForDay,
    required this.attendanceCountForDay,
    required this.isCurrentUserGoing,
    required this.onSelect,
  });

  @override
  State<_WeekStrip> createState() => _WeekStripState();
}

class _WeekStripState extends State<_WeekStrip> {
  static const int _basePage = 500;
  late final PageController _controller;
  late DateTime _baseWeek;

  @override
  void initState() {
    super.initState();
    _baseWeek = _startOfWeek(DateTime.now());
    _controller = PageController(initialPage: _pageFor(widget.selectedDay));
  }

  @override
  void didUpdateWidget(covariant _WeekStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = _pageFor(widget.selectedDay);
    if (_controller.hasClients && (_controller.page?.round() ?? target) != target) {
      _controller.animateToPage(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  DateTime _startOfWeek(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    final diff = (day.weekday + 1) % 7;
    return day.subtract(Duration(days: diff));
  }

  int _pageFor(DateTime day) {
    final target = _startOfWeek(day);
    final diffDays = target.difference(_baseWeek).inDays;
    return _basePage + (diffDays ~/ 7);
  }

  DateTime _weekForPage(int page) {
    return _baseWeek.add(Duration(days: (page - _basePage) * 7));
  }

  String _dayLabel(DateTime day) {
    switch (day.weekday) {
      case DateTime.saturday:
        return 'سبت';
      case DateTime.sunday:
        return 'أحد';
      case DateTime.monday:
        return 'اثن';
      case DateTime.tuesday:
        return 'ثلث';
      case DateTime.wednesday:
        return 'أربع';
      case DateTime.thursday:
        return 'خميس';
      default:
        return 'جمعة';
    }
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SizedBox(
        height: 62,
        child: PageView.builder(
          controller: _controller,
          itemBuilder: (_, page) {
            final start = _weekForPage(page);
            final days = List.generate(7, (i) => start.add(Duration(days: i)));

            return Row(
              children: List.generate(days.length, (i) {
                final day = days[i];
                return Expanded(
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(
                      start: i == 0 ? 0 : 3,
                      end: i == days.length - 1 ? 0 : 3,
                    ),
                    child: _DayCell(
                      label: _dayLabel(day),
                      day: day,
                      selected: _sameDay(day, widget.selectedDay),
                      currentMonth: true,
                      events: widget.eventsForDay(day),
                      attendanceCount: widget.attendanceCountForDay(day),
                      isCurrentUserGoing: widget.isCurrentUserGoing(day),
                      onTap: () => widget.onSelect(day),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final String label;
  final DateTime day;
  final bool selected;
  final bool currentMonth;
  final List<DiwaniyaCalendarEvent> events;
  final int attendanceCount;
  final bool isCurrentUserGoing;
  final VoidCallback onTap;
  final bool compact;

  const _DayCell({
    required this.label,
    required this.day,
    required this.selected,
    required this.currentMonth,
    required this.events,
    required this.onTap,
    this.attendanceCount = 0,
    this.isCurrentUserGoing = false,
    this.compact = false,
  });

  bool get _hasEvent => events.isNotEmpty;

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
        height: compact ? 36 : 60,
        padding: EdgeInsets.symmetric(vertical: compact ? 3 : 6, horizontal: 3),
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
        child: compact
            ? Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      color: fg,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  if (_hasEvent || attendanceCount > 0)
                    Positioned(
                      bottom: 3,
                      child: Container(
                        width: 4.5,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: selected ? Colors.white : c.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        color: selected ? Colors.white.withValues(alpha: 0.88) : c.t3,
                        fontSize: 9.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      color: fg,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 9,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (attendanceCount > 0)
                          Container(
                            constraints: const BoxConstraints(minWidth: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 0.5),
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.white.withValues(alpha: 0.22)
                                  : c.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$attendanceCount',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: selected ? Colors.white : c.accent,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                            ),
                          )
                        else if (_hasEvent)
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: selected ? Colors.white : c.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        if (isCurrentUserGoing) ...[
                          const SizedBox(width: 2.5),
                          Icon(
                            Icons.check_circle_rounded,
                            size: 9,
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
  final int goingCount;
  final bool isGoing;
  final bool Function(DiwaniyaCalendarEvent event) canManage;
  final VoidCallback onCreate;
  final void Function(DiwaniyaCalendarEvent event) onAttendToggle;
  final void Function(DiwaniyaCalendarEvent event) onEdit;
  final void Function(DiwaniyaCalendarEvent event) onDelete;
  final VoidCallback onToggleDayAttendance;
  final VoidCallback onShowGoing;
  final String Function(DateTime dt) timeText;

  const _SelectedDayPanel({
    required this.selectedDay,
    required this.events,
    required this.goingCount,
    required this.isGoing,
    required this.canManage,
    required this.onCreate,
    required this.onAttendToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleDayAttendance,
    required this.onShowGoing,
    required this.timeText,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    if (events.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: c.inputBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.border.withValues(alpha: 0.38)),
        ),
        child: Row(
          children: [
            Icon(Icons.groups_rounded, color: c.accent, size: 21),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: goingCount > 0 ? onShowGoing : null,
                borderRadius: BorderRadius.circular(12),
                child: Text(
                  goingCount > 0 ? '$goingCount جايين اليوم' : 'لا توجد مناسبات اليوم',
                  style: TextStyle(
                    color: goingCount > 0 ? c.accent : c.t1,
                    fontSize: 13.4,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: onToggleDayAttendance,
              child: Text(isGoing ? 'إلغاء' : 'جاي'),
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
            padding: const EdgeInsets.only(bottom: 7),
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
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: c.inputBg.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: event.isAttending
                ? c.success.withValues(alpha: 0.16)
                : c.border.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
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
                    size: 20,
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    event.title,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: c.t1,
                      fontSize: 14.4,
                      fontWeight: FontWeight.w900,
                      height: 1.08,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Wrap(
                spacing: 6,
                runSpacing: 5,
                children: [
                  _TinyBadge(
                    icon: Icons.schedule_rounded,
                    label: widget.timeText(event.startsAt),
                  ),
                  _TinyBadge(
                    icon: Icons.groups_rounded,
                    label: '${event.attendeesCount} جاي',
                  ),
                  if (event.isAttending)
                    _TinyBadge(
                      icon: Icons.check_circle_rounded,
                      label: 'حضورك مسجل',
                      success: true,
                    ),
                ],
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if ((event.description ?? '').trim().isNotEmpty) ...[
                      Text(
                        event.description!.trim(),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: c.t2,
                          fontSize: 12.1,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 9),
                    ],
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: SizedBox(
                        height: 34,
                        child: event.isAttending
                            ? OutlinedButton(
                                onPressed: widget.onAttendToggle,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: c.t3,
                                  side: BorderSide(color: c.border.withValues(alpha: 0.42)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                ),
                                child: const Text('إلغاء'),
                              )
                            : FilledButton.icon(
                                onPressed: widget.onAttendToggle,
                                icon: const Icon(Icons.how_to_reg_rounded, size: 15),
                                label: const Text('جاي'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: c.accent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 140),
            ),
          ],
        ),
      ),
    );
  }
}

class _TinyBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool success;

  const _TinyBadge({
    required this.icon,
    required this.label,
    this.success = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final color = success ? c.success : c.t3;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: success
            ? c.success.withValues(alpha: 0.10)
            : c.card.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: success
              ? c.success.withValues(alpha: 0.12)
              : c.border.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.5, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: success ? c.success : c.t2,
              fontSize: 10.6,
              fontWeight: FontWeight.w900,
              height: 1,
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
  final int Function(DateTime day) attendanceCountForDay;
  final void Function(DateTime day) onSelect;

  const _MonthPickerSheet({
    required this.initialDay,
    required this.eventsForDay,
    required this.attendanceCountForDay,
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
                mainAxisSpacing: 7,
                crossAxisSpacing: 6,
                childAspectRatio: 1.0,
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
                  attendanceCount: widget.attendanceCountForDay(day),
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
