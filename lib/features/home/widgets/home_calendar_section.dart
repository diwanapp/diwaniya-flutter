import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';
import '../../../core/services/calendar_service.dart';
import '../../../core/services/user_service.dart';
import 'home_handle.dart';

class HomeCalendarSection extends StatefulWidget {
  final List<DiwaniyaCalendarEvent> events;
  final bool isManager;
  final VoidCallback onCreate;
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
  bool _monthExpanded = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _startOfDay(DateTime.now());
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _startOfWeek(DateTime d) {
    // Saudi-friendly visual week: Saturday to Friday.
    final day = _startOfDay(d);
    final diff = (day.weekday + 1) % 7; // Saturday = 0
    return day.subtract(Duration(days: diff));
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  List<DateTime> get _weekDays {
    final start = _startOfWeek(_selectedDay);
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  List<DateTime> get _monthDays {
    final first = DateTime(_selectedDay.year, _selectedDay.month);
    final leading = (first.weekday + 1) % 7; // Saturday grid start
    final gridStart = first.subtract(Duration(days: leading));
    return List.generate(42, (i) => gridStart.add(Duration(days: i)));
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

  String _headerSubtitle() {
    final upcoming = _upcomingEvents;
    if (upcoming.isEmpty) return 'لا توجد مناسبات قريبة';

    final first = upcoming.first.startsAt.toLocal();
    final now = DateTime.now();
    final today = _startOfDay(now);
    final firstDay = _startOfDay(first);
    final time = _timeText(first);

    if (firstDay == today) return 'أقرب مناسبة اليوم الساعة $time';

    final count = _weekEventCount();
    if (count == 1) return 'عندكم مناسبة هذا الأسبوع';
    if (count == 2) return 'عندكم مناسبتين هذا الأسبوع';
    if (count >= 3 && count <= 10) return 'عندكم $count مناسبات هذا الأسبوع';
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

  bool _canManage(DiwaniyaCalendarEvent event) {
    return widget.isManager || event.createdByName.trim() == UserService.currentName.trim();
  }

  void _select(DateTime day) {
    setState(() => _selectedDay = _startOfDay(day));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final selectedEvents = _eventsForDay(_selectedDay);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.border.withValues(alpha: 0.85)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CalendarHeader(
            subtitle: _headerSubtitle(),
            monthExpanded: _monthExpanded,
            onToggleCalendar: () => setState(() => _monthExpanded = !_monthExpanded),
            onCreate: widget.onCreate,
          ),
          const SizedBox(height: 14),
          if (_monthExpanded)
            _MonthGrid(
              days: _monthDays,
              selectedDay: _selectedDay,
              currentMonth: _selectedDay.month,
              eventsForDay: _eventsForDay,
              onSelect: _select,
            )
          else
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
            onCreate: widget.onCreate,
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

class _CalendarHeader extends StatelessWidget {
  final String subtitle;
  final bool monthExpanded;
  final VoidCallback onToggleCalendar;
  final VoidCallback onCreate;

  const _CalendarHeader({
    required this.subtitle,
    required this.monthExpanded,
    required this.onToggleCalendar,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: c.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.event_available_rounded, color: c.accent, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'جمعتنا على خير',
                style: TextStyle(
                  color: c.t1,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: c.t3,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _MiniAction(
          label: monthExpanded ? 'الأسبوع' : 'الشهر',
          icon: monthExpanded ? Icons.view_week_rounded : Icons.calendar_month_rounded,
          onTap: onToggleCalendar,
          filled: false,
        ),
        const SizedBox(width: 7),
        _MiniAction(
          label: 'مناسبة',
          icon: Icons.add_rounded,
          onTap: onCreate,
          filled: true,
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? c.accent : c.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: filled ? null : Border.all(color: c.accent.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: fg, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 11.8,
                fontWeight: FontWeight.w800,
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
    return Row(
      children: List.generate(days.length, (i) {
        final day = days[i];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i == days.length - 1 ? 0 : 5),
            child: _DayCell(
              label: _dayNames[i],
              day: day,
              selected: _isSameDay(day, selectedDay),
              currentMonth: true,
              events: eventsForDay(day),
              onTap: () => onSelect(day),
            ),
          ),
        );
      }),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

class _MonthGrid extends StatelessWidget {
  final List<DateTime> days;
  final DateTime selectedDay;
  final int currentMonth;
  final List<DiwaniyaCalendarEvent> Function(DateTime day) eventsForDay;
  final void Function(DateTime day) onSelect;

  const _MonthGrid({
    required this.days,
    required this.selectedDay,
    required this.currentMonth,
    required this.eventsForDay,
    required this.onSelect,
  });

  static const _dayNames = ['سبت', 'أحد', 'اثن', 'ثلث', 'أربع', 'خميس', 'جمعة'];

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Column(
      children: [
        Row(
          children: _dayNames
              .map(
                (d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        color: c.t3,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
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
            mainAxisSpacing: 6,
            crossAxisSpacing: 5,
            childAspectRatio: 0.88,
          ),
          itemBuilder: (_, i) {
            final day = days[i];
            return _DayCell(
              label: '',
              day: day,
              selected: _sameDay(day, selectedDay),
              currentMonth: day.month == currentMonth,
              events: eventsForDay(day),
              compact: true,
              onTap: () => onSelect(day),
            );
          },
        ),
      ],
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
            ? c.accent.withValues(alpha: 0.09)
            : c.inputBg;
    final fg = selected
        ? Colors.white
        : currentMonth
            ? c.t1
            : c.t3.withValues(alpha: 0.55);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(vertical: compact ? 7 : 9, horizontal: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected
                ? c.accent
                : isToday
                    ? c.accent.withValues(alpha: 0.26)
                    : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!compact)
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white.withValues(alpha: 0.92) : c.t3,
                  fontSize: 10.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (!compact) const SizedBox(height: 4),
            Text(
              '${day.day}',
              style: TextStyle(
                color: fg,
                fontSize: compact ? 12.8 : 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (events.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(minWidth: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: selected ? Colors.white.withValues(alpha: 0.22) : c.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        events.length == 1 ? '•' : '${events.length}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected ? Colors.white : c.accent,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  if (_hasAttendance) ...[
                    const SizedBox(width: 3),
                    Icon(
                      Icons.check_circle_rounded,
                      size: 11,
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.inputBg,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: c.border.withValues(alpha: 0.55)),
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'لا توجد مناسبة في هذا اليوم',
                    style: TextStyle(
                      color: c.t1,
                      fontSize: 13.4,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'أضف مناسبة.',
                    style: TextStyle(
                      color: c.t3,
                      fontSize: 12.2,
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
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: events
          .map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _EventCard(
                event: event,
                canManage: canManage(event),
                onAttendToggle: () => onAttendToggle(event),
                onEdit: () => onEdit(event),
                onDelete: () => onDelete(event),
                timeText: timeText,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _EventCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final c = context.cl;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: c.inputBg,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: event.isAttending ? c.success.withValues(alpha: 0.32) : c.border.withValues(alpha: 0.55),
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
                    fontSize: 14.4,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (canManage)
                PopupMenuButton<String>(
                  tooltip: 'إدارة المناسبة',
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.more_horiz_rounded, color: c.t3),
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('تعديل')),
                    PopupMenuItem(value: 'delete', child: Text('حذف')),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Pill(icon: Icons.schedule_rounded, label: timeText(event.startsAt)),
              _Pill(icon: Icons.groups_rounded, label: '${event.attendeesCount} بيحضر'),
            ],
          ),
          if ((event.description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              event.description!.trim(),
              style: TextStyle(color: c.t2, fontSize: 12.5, height: 1.45),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 11),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onAttendToggle,
              icon: Icon(
                event.isAttending ? Icons.check_circle_rounded : Icons.how_to_reg_rounded,
                size: 18,
              ),
              label: Text(event.isAttending ? 'ما أقدر أحضر' : 'بحضر'),
              style: OutlinedButton.styleFrom(
                foregroundColor: event.isAttending ? c.success : c.accent,
                side: BorderSide(
                  color: (event.isAttending ? c.success : c.accent).withValues(alpha: 0.35),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Pill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: c.t3),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: c.t2,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
  final Future<void> Function(HomeCalendarEventDraft draft) onSave;

  const HomeCalendarEventSheet({
    super.key,
    this.initial,
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
  bool _attendingByDefault = true;
  bool _allowGuests = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _title = TextEditingController(text: initial?.title ?? '');
    _description = TextEditingController(text: initial?.description ?? '');
    _startsAt = initial?.startsAt.toLocal() ?? DateTime.now().add(const Duration(hours: 1));
    _endsAt = initial?.endsAt?.toLocal();
    _attendingByDefault = initial?.isAttending ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
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
    return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
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
                const SizedBox(height: 18),
                _Field(controller: _title, label: 'عنوان المناسبة'),
                const SizedBox(height: 12),
                _Field(controller: _description, label: 'وصف مختصر', maxLines: 3),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _pickStart,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.inputBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.event_rounded, color: c.accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _dateText(_startsAt),
                            style: TextStyle(color: c.t1, fontWeight: FontWeight.w800),
                          ),
                        ),
                        Icon(Icons.edit_calendar_rounded, color: c.t3),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _SwitchTile(
                  title: 'أنا بحضر',
                  subtitle: 'تسجيل حضورك تلقائيًا عند إنشاء المناسبة',
                  value: _attendingByDefault,
                  onChanged: (v) => setState(() => _attendingByDefault = v),
                ),
                const SizedBox(height: 10),
                _SwitchTile(
                  title: 'السماح بإضافة ضيوف',
                  subtitle: 'تضاف لاحقًا كتفاصيل للمناسبة',
                  value: _allowGuests,
                  onChanged: (v) => setState(() => _allowGuests = v),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: c.accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

class _SwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: c.inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: c.t1, fontSize: 13.2, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: c.t3, fontSize: 11.6, height: 1.3)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
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
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.border),
        ),
      ),
    );
  }
}
