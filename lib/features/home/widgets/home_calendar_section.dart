import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';
import '../../../core/services/calendar_service.dart';
import '../../../core/services/user_service.dart';
import 'home_handle.dart';

class HomeCalendarSection extends StatefulWidget {
  final List<DiwaniyaCalendarEvent> events;
  final List<DiwaniyaCalendarDayAttendance> dayAttendance;
  final bool isManager;
  final void Function(DateTime day, bool attending) onDayAttendanceToggle;
  final void Function(DateTime day) onShowDayAttendees;
  final void Function(DiwaniyaCalendarEvent event) onAttendToggle;
  final void Function(DiwaniyaCalendarEvent event) onEdit;
  final void Function(DiwaniyaCalendarEvent event) onDelete;
  final ValueChanged<DateTime> onCreate;
  const HomeCalendarSection({
    super.key,
    required this.events,
    required this.dayAttendance,
    required this.isManager,
    required this.onDayAttendanceToggle,
    required this.onShowDayAttendees,
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
    final horizon = now.add(const Duration(days: 370));

    return widget.events.where((e) {
      final local = e.startsAt.toLocal();
      return !e.isCancelled &&
          !local.isBefore(now.subtract(const Duration(minutes: 1))) &&
          !local.isAfter(horizon);
    }).toList()
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

  DiwaniyaCalendarEvent? get _nearestUpcomingEvent {
    final upcoming = _upcomingEvents;
    if (upcoming.isEmpty) return null;
    return upcoming.first;
  }

  String _nearestEventTitle() {
    final event = _nearestUpcomingEvent;
    if (event == null) return 'لا توجد مناسبات قريبة';

    final title = event.title.trim();
    return title.isEmpty ? 'مناسبة قادمة' : title;
  }

  String _nearestEventMeta() {
    final event = _nearestUpcomingEvent;
    if (event == null) return '';

    final startsAt = event.startsAt.toLocal();
    return '${_eventDateBrief(startsAt)} · ${_timeText(startsAt)}';
  }

  String _headlineText() {
    return _nearestEventTitle();
  }

  String _eventDateBrief(DateTime dt) {
    final day = _startOfDay(dt);
    final today = _startOfDay(DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));

    if (_sameDay(day, today)) return 'اليوم';
    if (_sameDay(day, tomorrow)) return 'غدًا';

    return '${dt.day} ${_monthName(dt.month)}';
  }

  String _monthName(int month) {
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

    if (month < 1 || month > 12) return month.toString();
    return months[month - 1];
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
    return '${day.day} ${_monthName(day.month)}';
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
          Future.microtask(() {
            if (!mounted) return;
            widget.onCreate(day);
          });
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
    final showWeekStrip = false;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.border.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.018),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CalendarTopBar(
            title: _dateTitle(_selectedDay),
            headline: _headlineText(),
            nearestMeta: _nearestEventMeta(),
            summary: _summaryText(),
            goingCount: goingCount,
            isGoing: isGoing,
            onToday: _goToday,
            onMonth: _openMonthPicker,
            onToggleGoing: _toggleSelectedDayAttendance,
          ),
          if (showWeekStrip) ...[
            const SizedBox(height: 12),
            _WeekStrip(
              days: _weekDays,
              selectedDay: _selectedDay,
              eventsForDay: _eventsForDay,
              attendanceCountForDay: _totalGoingForDay,
              isCurrentUserGoing: _isCurrentUserGoing,
              onSelect: _select,
            ),
            const SizedBox(height: 12),
          ] else
            const SizedBox(height: 9),
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
  final String nearestMeta;
  final String summary;
  final int goingCount;
  final bool isGoing;
  final VoidCallback onToday;
  final VoidCallback onMonth;
  final VoidCallback onToggleGoing;

  const _CalendarTopBar({
    required this.title,
    required this.headline,
    required this.nearestMeta,
    required this.summary,
    required this.goingCount,
    required this.isGoing,
    required this.onToday,
    required this.onMonth,
    required this.onToggleGoing,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final hasNearest = nearestMeta.trim().isNotEmpty &&
        headline.trim() != 'لا توجد مناسبات قريبة';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  textDirection: TextDirection.rtl,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: onMonth,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: c.accent.withValues(alpha: 0.075),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: c.accent.withValues(alpha: 0.13),
                          ),
                        ),
                        child: Icon(
                          Icons.calendar_month_rounded,
                          color: c.accent,
                          size: 21,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        title,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        style: TextStyle(
                          color: c.t1,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          height: 1.02,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _DailyAttendancePill(
                isGoing: isGoing,
                onToggleGoing: onToggleGoing,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'أقرب مناسبة',
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.visible,
                style: TextStyle(
                  color: c.accent,
                  fontSize: 12.6,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
              if (hasNearest) ...[
                const SizedBox(width: 10),
                Flexible(
                  flex: 4,
                  child: Text(
                    headline,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.t1,
                      fontSize: 17.4,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.t3.withValues(alpha: 0.42),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  flex: 6,
                  child: Text(
                    nearestMeta,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    style: TextStyle(
                      color: c.t2,
                      fontSize: 12.2,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    headline,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.t3,
                      fontSize: 13.6,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DailyAttendancePill extends StatelessWidget {
  final bool isGoing;
  final VoidCallback onToggleGoing;

  const _DailyAttendancePill({
    required this.isGoing,
    required this.onToggleGoing,
  });

  static const Color _confirmedGreen = Color(0xFF79A886);
  static const Color _confirmedGreenLight = Color(0xFF9FC6A8);
  static const Color _dangerRed = Color(0xFFB76B6B);

  void _handleTap(BuildContext context) {
    if (!isGoing) {
      onToggleGoing();
      return;
    }

    final c = context.cl;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Container(
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: c.border.withValues(alpha: 0.12)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'حضورك اليوم',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: c.t1,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'أنت مسجل حاضر. إذا تغيّرت خطتك، اختر ما أقدر.',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: c.t2,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('حاضر'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _confirmedGreen,
                            foregroundColor: c.bg,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(17),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            onToggleGoing();
                          },
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('ما أقدر'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _dangerRed,
                            side: const BorderSide(color: _dangerRed),
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(17),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    return InkWell(
      onTap: () => _handleTap(context),
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 92,
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          gradient: isGoing
              ? const LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [_confirmedGreenLight, _confirmedGreen],
                )
              : const LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Color(0xFFE8D8B8), Color(0xFFC8AD83)],
                ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isGoing
                ? _confirmedGreen.withValues(alpha: 0.25)
                : const Color(0xFFC8AD83).withValues(alpha: 0.22),
          ),
          boxShadow: [
            BoxShadow(
              color: (isGoing ? _confirmedGreen : const Color(0xFFC8AD83))
                  .withValues(alpha: 0.13),
              blurRadius: 18,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isGoing ? Icons.check_rounded : Icons.how_to_reg_rounded,
              color: c.bg,
              size: 19,
            ),
            const SizedBox(height: 5),
            Text(
              isGoing ? 'حاضر' : 'جاي اليوم',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.bg,
                fontSize: 12.4,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  final bool compact;
  final bool danger;

  const _MiniAction({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.filled,
    this.compact = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final dangerColor = c.error;
    final fg = filled
        ? Colors.white
        : danger
            ? dangerColor
            : c.accent;

    final bg = filled
        ? c.accent
        : danger
            ? dangerColor.withValues(alpha: 0.08)
            : c.accent.withValues(alpha: 0.06);

    final borderColor = danger
        ? dangerColor.withValues(alpha: 0.18)
        : c.accent.withValues(alpha: 0.16);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 88,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: filled ? null : Border.all(color: borderColor),
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
            : c.inputBg.withValues(alpha: 0.78);

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
  final void Function(DiwaniyaCalendarEvent event) onAttendToggle;
  final void Function(DiwaniyaCalendarEvent event) onEdit;
  final void Function(DiwaniyaCalendarEvent event) onDelete;
  final VoidCallback onToggleDayAttendance;
  final VoidCallback onShowGoing;
  final String Function(DateTime dt) timeText;
  final VoidCallback onCreate;
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
      return InkWell(
        onTap: onCreate,
borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: c.inputBg.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(16),
            border: Border(
              bottom: BorderSide(
                color: c.border.withValues(alpha: 0.07),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: goingCount > 0 ? c.accent : c.t3.withValues(alpha: 0.42),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: InkWell(
                  onTap: goingCount > 0 ? onShowGoing : onCreate,
                  borderRadius: BorderRadius.circular(10),
                  child: Text(
                    goingCount > 0 ? '$goingCount جايين اليوم' : 'لا توجد مناسبات اليوم',
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: goingCount > 0 ? c.accent : c.t2,
                      fontSize: 13.3,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 32,
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.055),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: c.accent.withValues(alpha: 0.09)),
                ),
                child: Icon(Icons.add_rounded, color: c.accent, size: 24),
              ),
            ],
          ),
        ),
      );
    }

    final visible = events.take(4).toList();
    final remaining = events.length - visible.length;

    return Column(
      children: [
        for (final event in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
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
      onTap: () {
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _EventRsvpSheet(
            event: event,
            onAttendToggle: widget.onAttendToggle,
            timeText: widget.timeText,
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: event.isAttending
              ? c.success.withValues(alpha: 0.035)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border(
            bottom: BorderSide(
              color: c.border.withValues(alpha: 0.09),
              width: 1,
            ),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: event.isAttending ? c.success : c.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    event.title,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.t1,
                      fontSize: 13.7,
                      fontWeight: FontWeight.w900,
                      height: 1.12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _TinyInlineMeta(
                  icon: Icons.schedule_rounded,
                  label: widget.timeText(event.startsAt),
                ),
                const SizedBox(width: 5),
                _TinyInlineMeta(
                  icon: Icons.groups_rounded,
                  label: '${event.attendeesCount} جاي',
                ),
                if (widget.canManage) ...[
                  const SizedBox(width: 2),
                  PopupMenuButton<String>(
                    tooltip: 'إدارة المناسبة',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 104),
                    icon: Icon(Icons.more_horiz_rounded, color: c.t3, size: 19),
                    onSelected: (value) {
                      if (value == 'edit') widget.onEdit();
                      if (value == 'delete') widget.onDelete();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('تعديل')),
                      PopupMenuItem(value: 'delete', child: Text('حذف')),
                    ],
                  ),
                ] else ...[
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: c.t3,
                    size: 18,
                  ),
                ],
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Row(
                  children: [
                    if ((event.description ?? '').trim().isNotEmpty)
                      Expanded(
                        child: Text(
                          event.description!.trim(),
                          textAlign: TextAlign.right,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.t2,
                            fontSize: 11.5,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 30,
                      child: event.isAttending
                          ? OutlinedButton(
                              onPressed: widget.onAttendToggle,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: c.t3,
                                side: BorderSide(
                                  color: c.border.withValues(alpha: 0.24),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              child: const Text('إلغاء'),
                            )
                          : FilledButton(
                              onPressed: widget.onAttendToggle,
                              style: FilledButton.styleFrom(
                                backgroundColor: c.accent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                              ),
                              child: const Text('جاي'),
                            ),
                    ),
                  ],
                ),
              ),
              crossFadeState:
                  _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 130),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventRsvpSheet extends StatefulWidget {
  final DiwaniyaCalendarEvent event;
  final VoidCallback onAttendToggle;
  final String Function(DateTime dt) timeText;

  const _EventRsvpSheet({
    required this.event,
    required this.onAttendToggle,
    required this.timeText,
  });

  @override
  State<_EventRsvpSheet> createState() => _EventRsvpSheetState();
}

class _EventRsvpSheetState extends State<_EventRsvpSheet> {
  static const Color _green = Color(0xFF79A886);
  static const Color _orange = Color(0xFFC58A49);
  static const Color _red = Color(0xFFB76B6B);

  CalendarEventRsvps? _rsvps;
  bool _loading = true;
  String? _savingStatus;

  @override
  void initState() {
    super.initState();
    _loadRsvps();
  }

  Future<void> _loadRsvps() async {
    try {
      final rsvps = await CalendarService.fetchEventRsvps(
        widget.event.diwaniyaId,
        widget.event.id,
      );
      if (!mounted) return;
      setState(() {
        _rsvps = rsvps;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _setStatus(String status) async {
    if (_savingStatus != null) return;

    setState(() => _savingStatus = status);
    try {
      final updated = await CalendarService.setEventRsvp(
        widget.event.diwaniyaId,
        widget.event.id,
        status: status,
      );

      if (status == 'going' && !widget.event.isAttending) {
        widget.onAttendToggle();
      } else if (status != 'going' && widget.event.isAttending) {
        widget.onAttendToggle();
      }

      if (!mounted) return;
      setState(() => _rsvps = updated);

      final label = switch (status) {
        'going' => 'تم تسجيل حضورك',
        'maybe' => 'تم تسجيلك ضمن يمكن',
        'declined' => 'تم تسجيل اعتذارك',
        _ => 'تم تحديث الرد',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(label)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحديث الرد على المناسبة')),
      );
    } finally {
      if (mounted) setState(() => _savingStatus = null);
    }
  }

  Widget _section({
    required String title,
    required int count,
    required List<CalendarEventRsvpAttendee> attendees,
    required Color color,
  }) {
    final c = context.cl;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: c.inputBg.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$title ($count)',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: c.t1,
                    fontSize: 13.6,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (attendees.isEmpty)
            Text(
              'لا يوجد أسماء بعد',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: c.t3,
                fontSize: 12.2,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Wrap(
              textDirection: TextDirection.rtl,
              spacing: 7,
              runSpacing: 7,
              children: attendees
                  .map(
                    (a) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: color.withValues(alpha: 0.12)),
                      ),
                      child: Text(
                        a.userName.trim().isEmpty ? 'عضو' : a.userName.trim(),
                        style: TextStyle(
                          color: c.t1,
                          fontSize: 11.8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final event = widget.event;
    final local = event.startsAt.toLocal();
    final dateText = '${local.day}/${local.month}/${local.year} · ${widget.timeText(event.startsAt)}';
    final currentStatus = _rsvps?.currentUserStatus;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(14),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: c.border.withValues(alpha: 0.12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                event.title.trim().isEmpty ? 'مناسبة' : event.title.trim(),
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: c.t1,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                dateText,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: c.t2,
                  fontSize: 13.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _RsvpActionButton(
                      label: 'حاضر',
                      color: _green,
                      filled: currentStatus == 'going',
                      loading: _savingStatus == 'going',
                      onTap: () => _setStatus('going'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _RsvpActionButton(
                      label: 'يمكن',
                      color: _orange,
                      filled: currentStatus == 'maybe',
                      loading: _savingStatus == 'maybe',
                      onTap: () => _setStatus('maybe'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _RsvpActionButton(
                      label: 'أعتذر',
                      color: _red,
                      filled: currentStatus == 'declined',
                      loading: _savingStatus == 'declined',
                      onTap: () => _setStatus('declined'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_loading)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.inputBg.withValues(alpha: 0.36),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: c.border.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'جاري تحميل سجل الحضور...',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: c.t2,
                            fontSize: 12.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                _section(
                  title: 'الحاضرون',
                  count: _rsvps?.goingCount ?? 0,
                  attendees: _rsvps?.going ?? const <CalendarEventRsvpAttendee>[],
                  color: _green,
                ),
                const SizedBox(height: 8),
                _section(
                  title: 'يمكن يحضرون',
                  count: _rsvps?.maybeCount ?? 0,
                  attendees: _rsvps?.maybe ?? const <CalendarEventRsvpAttendee>[],
                  color: _orange,
                ),
                const SizedBox(height: 8),
                _section(
                  title: 'المعتذرون',
                  count: _rsvps?.declinedCount ?? 0,
                  attendees: _rsvps?.declined ?? const <CalendarEventRsvpAttendee>[],
                  color: _red,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RsvpActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  final bool loading;
  final VoidCallback onTap;

  const _RsvpActionButton({
    required this.label,
    required this.color,
    required this.filled,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    if (filled) {
      return FilledButton(
        onPressed: loading ? null : onTap,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: c.bg,
          minimumSize: const Size.fromHeight(46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: loading
            ? SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(strokeWidth: 2, color: c.bg),
              )
            : Text(label),
      );
    }

    return OutlinedButton(
      onPressed: loading ? null : onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        minimumSize: const Size.fromHeight(46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: loading
          ? SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          : Text(label),
    );
  }
}


class _TinyInlineMeta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TinyInlineMeta({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
      decoration: BoxDecoration(
        color: c.card.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11.5, color: c.t3),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: c.t2,
              fontSize: 10.2,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ],
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
              : c.border.withValues(alpha: 0.055),
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
                  style: IconButton.styleFrom(
                    backgroundColor: c.inputBg.withValues(alpha: 0.55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                  icon: Icon(Icons.chevron_left_rounded, color: c.t2),
                ),
                Expanded(
                  child: Text(
                    _monthTitle(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.t1, fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: c.inputBg.withValues(alpha: 0.55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                  icon: Icon(Icons.chevron_right_rounded, color: c.t2),
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
    const suggestions = ['عشاء', 'مباراة', 'قهوة', 'حفلة'];

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
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.85,
                  children: suggestions
                      .map(
                        (item) => InkWell(
                          onTap: () => _applySuggestion(item),
                          borderRadius: BorderRadius.circular(15),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: c.accent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: c.accent.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Text(
                              item,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: c.accent,
                                fontSize: 13.2,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
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
