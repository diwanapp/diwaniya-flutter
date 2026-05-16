import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';
import '../../../core/services/calendar_service.dart';
import '../../../core/services/user_service.dart';
import 'home_handle.dart';

class HomeCalendarSection extends StatelessWidget {
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

  List<DiwaniyaCalendarEvent> get _visibleEvents {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    return events
        .where((e) => e.startsAt.isAfter(startOfToday.subtract(const Duration(minutes: 1))))
        .take(3)
        .toList();
  }

  bool _canManage(DiwaniyaCalendarEvent event) {
    return isManager || event.createdByName.trim() == UserService.currentName.trim();
  }

  String _dateLabel(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(local.year, local.month, local.day);
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

    if (eventDay == today) return 'اليوم $time';
    if (eventDay == today.add(const Duration(days: 1))) return 'بكرة $time';
    return '${local.day}/${local.month} $time';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final visible = _visibleEvents;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.event_available_rounded, color: c.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تقويم الديوانية',
                      style: TextStyle(
                        color: c.t1,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      visible.isEmpty ? 'لا توجد مناسبات قادمة' : 'مناسبات اليوم والقادمة',
                      style: TextStyle(
                        color: c.t3,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: onCreate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'أضف',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (visible.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: c.inputBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'أضف مناسبة أو موعد للديوانية، وخل الأعضاء يحددون حضورهم.',
                style: TextStyle(
                  color: c.t3,
                  fontSize: 12.8,
                  height: 1.5,
                ),
              ),
            )
          else
            ...visible.map((event) {
              final canManage = _canManage(event);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.inputBg,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: event.isAttending
                          ? c.success.withValues(alpha: 0.28)
                          : Colors.transparent,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              event.title,
                              style: TextStyle(
                                color: c.t1,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
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
                                if (value == 'edit') onEdit(event);
                                if (value == 'delete') onDelete(event);
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
                          _Pill(
                            icon: Icons.schedule_rounded,
                            label: _dateLabel(event.startsAt),
                          ),
                          if ((event.location ?? '').trim().isNotEmpty)
                            _Pill(
                              icon: Icons.place_outlined,
                              label: event.location!.trim(),
                            ),
                          _Pill(
                            icon: Icons.groups_rounded,
                            label: '${event.attendeesCount} بيحضر',
                          ),
                        ],
                      ),
                      if ((event.description ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          event.description!.trim(),
                          style: TextStyle(
                            color: c.t2,
                            fontSize: 12.5,
                            height: 1.45,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => onAttendToggle(event),
                              icon: Icon(
                                event.isAttending
                                    ? Icons.check_circle_rounded
                                    : Icons.how_to_reg_rounded,
                                size: 18,
                              ),
                              label: Text(event.isAttending ? 'إلغاء الحضور' : 'بحضر'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: event.isAttending ? c.success : c.accent,
                                side: BorderSide(
                                  color: (event.isAttending ? c.success : c.accent)
                                      .withValues(alpha: 0.35),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
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
              fontWeight: FontWeight.w600,
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
    required this.location,
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
  late final TextEditingController _location;
  late DateTime _startsAt;
  DateTime? _endsAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _title = TextEditingController(text: initial?.title ?? '');
    _description = TextEditingController(text: initial?.description ?? '');
    _location = TextEditingController(text: initial?.location ?? '');
    _startsAt = initial?.startsAt.toLocal() ?? DateTime.now().add(const Duration(hours: 1));
    _endsAt = initial?.endsAt?.toLocal();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
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
          location: _location.text.trim().isEmpty ? null : _location.text.trim(),
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
                  style: TextStyle(
                    color: c.t1,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                _Field(controller: _title, label: 'عنوان المناسبة'),
                const SizedBox(height: 12),
                _Field(
                  controller: _description,
                  label: 'وصف مختصر',
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                _Field(controller: _location, label: 'المكان'),
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
                            style: TextStyle(
                              color: c.t1,
                              fontWeight: FontWeight.w700,
                            ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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
