import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../l10n/ar.dart';

class AvatarPickerScreen extends StatefulWidget {
  const AvatarPickerScreen({super.key});

  @override
  State<AvatarPickerScreen> createState() => _AvatarPickerScreenState();
}

class _AvatarPickerScreenState extends State<AvatarPickerScreen> {
  static final _presets = <_AvatarPreset>[
    const _AvatarPreset('saudi_falcon', 'الصقر', Icons.shield_moon_rounded, Color(0xFF2E8B57)),
    const _AvatarPreset('saudi_poet', 'الشاعر', Icons.auto_stories_rounded, Color(0xFF8B5E3C)),
    const _AvatarPreset('saudi_rider', 'الفارس', Icons.workspace_premium_rounded, Color(0xFFC08A2E)),
    const _AvatarPreset('saudi_majlis', 'المضيف', Icons.groups_3_rounded, Color(0xFF2563EB)),
    const _AvatarPreset('saudi_coffee', 'المقهوي', Icons.local_cafe_rounded, Color(0xFFB45309)),
    const _AvatarPreset('saudi_heritage', 'الأصيل', Icons.account_balance_rounded, Color(0xFF7C3AED)),
  ];

  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(backgroundColor: c.bg),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(Ar.avatarTitle,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: c.t1)),
              const SizedBox(height: 10),
              Text(Ar.avatarSubtitle,
                  style: TextStyle(fontSize: 15, height: 1.7, color: c.t2)),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.builder(
                  itemCount: _presets.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.88,
                  ),
                  itemBuilder: (context, index) {
                    final preset = _presets[index];
                    final selected = _selectedId == preset.id;
                    return InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => setState(() => _selectedId = preset.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: selected ? preset.color : c.border,
                            width: selected ? 1.6 : 1,
                          ),
                          boxShadow: [BoxShadow(color: c.shadow, blurRadius: 10)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              height: 112,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topRight,
                                  end: Alignment.bottomLeft,
                                  colors: [preset.color.withValues(alpha: 0.25), preset.color.withValues(alpha: 0.08)],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(preset.icon, size: 54, color: preset.color),
                            ),
                            const SizedBox(height: 14),
                            Text(preset.title,
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.t1)),
                            const SizedBox(height: 6),
                            Text(Ar.avatarFlavor,
                                style: TextStyle(fontSize: 12.5, height: 1.6, color: c.t2)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _selectedId == null
                      ? null
                      : () async {
                          await AuthService.selectAvatar(_selectedId!);
                          if (!context.mounted) return;
                          context.go('/diwaniya-access');
                        },
                  child: const Text(Ar.continueText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarPreset {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  const _AvatarPreset(this.id, this.title, this.icon, this.color);
}
