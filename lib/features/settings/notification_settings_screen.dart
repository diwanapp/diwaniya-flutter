import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';
import '../../core/services/notification_preferences_service.dart';
import '../../core/services/user_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final isManager = UserService.isManager();

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        title: Text('إعدادات الإشعارات',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: c.t1)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            _NotificationStatusCard(c: c),
            const SizedBox(height: 18),
            _SectionLabel(c: c, label: 'إشعارات الاستخدام العام'),
            _Group(c: c, children: [
              _ToggleRow(
                c: c,
                icon: Icons.chat_bubble_outline_rounded,
                label: 'إشعارات المحادثات',
                value: NotificationPreferencesService.chat,
                onChanged: (v) async {
                  await NotificationPreferencesService.setChat(v);
                  setState(() {});
                },
              ),
              _Divider(c: c),
              _ToggleRow(
                c: c,
                icon: Icons.how_to_vote_rounded,
                label: 'إشعارات التصويتات',
                value: NotificationPreferencesService.poll,
                onChanged: (v) async {
                  await NotificationPreferencesService.setPoll(v);
                  setState(() {});
                },
              ),
              _Divider(c: c),
              _ToggleRow(
                c: c,
                icon: Icons.shopping_basket_rounded,
                label: 'إشعارات المقاضي',
                value: NotificationPreferencesService.maqadi,
                onChanged: (v) async {
                  await NotificationPreferencesService.setMaqadi(v);
                  setState(() {});
                },
              ),
              _Divider(c: c),
              _ToggleRow(
                c: c,
                icon: Icons.notifications_active_outlined,
                label: 'إشعارات النشاط العام',
                value: NotificationPreferencesService.activity,
                onChanged: (v) async {
                  await NotificationPreferencesService.setActivity(v);
                  setState(() {});
                },
              ),
            ]),
            if (isManager) ...[
              const SizedBox(height: 22),
              _SectionLabel(c: c, label: 'إشعارات إدارة الديوانية'),
              _Group(c: c, children: [
                _ToggleRow(
                  c: c,
                  icon: Icons.person_add_alt_1_rounded,
                  label: 'طلبات الانضمام',
                  value: NotificationPreferencesService.managerJoinRequests,
                  onChanged: (v) async {
                    await NotificationPreferencesService
                        .setManagerJoinRequests(v);
                    setState(() {});
                  },
                ),
                _Divider(c: c),
                _ToggleRow(
                  c: c,
                  icon: Icons.admin_panel_settings_outlined,
                  label: 'طلبات الأدوار والصلاحيات',
                  value: NotificationPreferencesService.managerRoleRequests,
                  onChanged: (v) async {
                    await NotificationPreferencesService
                        .setManagerRoleRequests(v);
                    setState(() {});
                  },
                ),
                _Divider(c: c),
                _ToggleRow(
                  c: c,
                  icon: Icons.task_alt_rounded,
                  label: 'طلبات الموافقات',
                  value: NotificationPreferencesService.managerApprovals,
                  onChanged: (v) async {
                    await NotificationPreferencesService
                        .setManagerApprovals(v);
                    setState(() {});
                  },
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}


class _NotificationStatusCard extends StatelessWidget {
  final CL c;
  const _NotificationStatusCard({required this.c});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c.accentMuted,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                Icons.info_outline_rounded,
                color: c.accent,
                size: 19,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تفضيلات الإشعارات',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: c.t1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'هذه المفاتيح تتحكم بإشعارات التطبيق الداخلية حاليًا. إشعارات الجهاز الفعلية على Android و iPhone تحتاج ربط Push Notifications في مرحلة الإطلاق.',
                    style: TextStyle(
                      fontSize: 12.2,
                      height: 1.55,
                      color: c.t3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  final CL c;
  final String label;
  const _SectionLabel({required this.c, required this.label});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, right: 4),
        child: Text(label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: c.t2)),
      );
}

class _Group extends StatelessWidget {
  final CL c;
  final List<Widget> children;
  const _Group({required this.c, required this.children});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Column(children: children),
      );
}

class _Divider extends StatelessWidget {
  final CL c;
  const _Divider({required this.c});
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, color: c.divider, indent: 56);
}

class _ToggleRow extends StatelessWidget {
  final CL c;
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({
    required this.c,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.accentMuted,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: c.accent, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: c.t1)),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: c.accent,
          ),
        ]),
      );
}
