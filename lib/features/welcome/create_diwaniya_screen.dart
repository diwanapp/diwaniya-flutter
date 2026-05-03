import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme/app_colors.dart';
import '../../core/models/subscription_status.dart';
import '../../core/api/api_exception.dart';
import '../../core/services/auth_service.dart';

class CreateDiwaniyaScreen extends StatefulWidget {
  const CreateDiwaniyaScreen({super.key});

  @override
  State<CreateDiwaniyaScreen> createState() => _CreateDiwaniyaScreenState();
}

class _CreateDiwaniyaScreenState extends State<CreateDiwaniyaScreen> {
  final _name = TextEditingController();
  final _district = TextEditingController();
  final _code = TextEditingController();

  static const Map<String, List<String>> _gulfCities = {
    'السعودية': [
      'الرياض',
      'جدة',
      'مكة',
      'المدينة',
      'القصيم',
      'الدمام',
      'الخبر',
      'الظهران',
      'الأحساء',
      'حايل',
      'الطائف',
      'المنطقة الشمالية',
      'المنطقة الجنوبية',
    ],
    'الإمارات': ['دبي', 'أبوظبي', 'الشارقة', 'العين', 'عجمان'],
    'الكويت': ['مدينة الكويت', 'حولي', 'الفروانية', 'الأحمدي'],
    'قطر': ['الدوحة', 'الريان', 'الوكرة', 'الخور'],
    'البحرين': ['المنامة', 'المحرق', 'الرفاع', 'مدينة عيسى'],
    'عُمان': ['مسقط', 'صلالة', 'صحار', 'نزوى'],
  };

  String _selectedCountry = 'السعودية';
  String _selectedCity = 'الرياض';
  bool _loading = false;

  bool get _detailsValid =>
      _name.text.trim().length >= 3 &&
      _selectedCountry.trim().isNotEmpty &&
      _selectedCity.trim().isNotEmpty &&
      _district.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _code.text = _generateCode();
  }

  @override
  void dispose() {
    _name.dispose();
    _district.dispose();
    _code.dispose();
    super.dispose();
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<void> _finish() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await AuthService.savePendingCreateDraft(
        name: _name.text.trim(),
        city: _selectedCity,
        district: _district.text.trim(),
        invitationCode: _code.text,
        color: AppColors.accent,
      );

      // Primary path: create on free tier directly via the backend.
      // Plan selection is no longer part of the creation flow — it is
      // an upgrade destination now.
      final ok = await AuthService.createDiwaniyaViaApi(
        plan: SubscriptionPlan.free,
      );

      if (!mounted) return;

      if (!ok) {
        // Dev-only local fallback path was taken (gated inside
        // createDiwaniyaViaApi behind kDebugMode). Surface a clearly-
        // marked snackbar so it's impossible to mistake this for a
        // production-grade create. Routing continues normally so the
        // developer can keep iterating on downstream screens.
        if (kDebugMode) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'تم إنشاء الديوانية محليًا مؤقتًا لبيئة التطوير',
              ),
            ),
          );
          // Keep _loading = true through navigation (matches success
          // path) so the button stays in its loading state until the
          // next screen replaces this one.
          context.go(AuthService.nextRoute());
          return;
        }
        // Production: surface a real error and let the user retry.
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذّر إنشاء الديوانية. تحقق من الاتصال وحاول مرة أخرى.',
            ),
          ),
        );
        return;
      }

      // Keep _loading = true through navigation so the button keeps
      // showing the loading label until the next screen replaces this
      // one. Avoids a dead frame between state-clear and route swap.
      context.go(AuthService.nextRoute());
    } on ApiException catch (e, stackTrace) {
      debugPrint('❌ CreateDiwaniya ApiException: $e');
      debugPrint(
        '❌ status=${e.statusCode} code=${e.code} details=${e.details}',
      );
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ CreateDiwaniya unexpected error: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر إنشاء الديوانية: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final cities = _gulfCities[_selectedCountry] ?? const <String>[];

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(backgroundColor: c.bg),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const _CreateHeroCard(),
            const SizedBox(height: 16),
            _SectionCard(
              child: Column(
                children: [
                  _Field(
                    label: 'اسم الديوانية',
                    controller: _name,
                    hint: 'مثال: ديوانية الخميس',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  _DropdownField<String>(
                    label: 'الدولة',
                    value: _selectedCountry,
                    items: _gulfCities.keys.toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      final nextCities =
                          _gulfCities[value] ?? const <String>[];
                      setState(() {
                        _selectedCountry = value;
                        _selectedCity =
                            nextCities.isNotEmpty ? nextCities.first : '';
                        _district.clear();
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  _DropdownField<String>(
                    label: 'المدينة',
                    value: cities.contains(_selectedCity)
                        ? _selectedCity
                        : (cities.isNotEmpty ? cities.first : null),
                    items: cities,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedCity = value;
                        _district.clear();
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  _Field(
                    label: 'الحي',
                    controller: _district,
                    hint: 'اكتب اسم الحي',
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'رمز الدعوة',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: c.t2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'يُستخدم هذا الرمز لانضمام الأعضاء إلى الديوانية.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.7,
                      color: c.t3,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 22,
                      horizontal: 18,
                    ),
                    decoration: BoxDecoration(
                      color: c.cardElevated,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: c.border),
                    ),
                    child: Text(
                      _code.text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        color: c.accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              setState(() => _code.text = _generateCode()),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('تجديد الرمز'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _code.text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم نسخ الرمز')),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('نسخ الرمز'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: (_detailsValid && !_loading) ? _finish : null,
                child: _loading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                c.tInverse,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text('ثواني بس واستمتع'),
                        ],
                      )
                    : const Text('إنشاء الديوانية والمتابعة'),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'بعد الإنشاء يمكنكم دعوة الأعضاء مباشرة برمز الدعوة.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.7,
                color: c.t3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateHeroCard extends StatelessWidget {
  const _CreateHeroCard();

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            c.accent.withValues(alpha: 0.14),
            c.accent.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.accent.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.add_home_work_rounded,
              color: c.accent,
              size: 22,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'إنشاء ديوانية',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: c.t1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'أدخل معلومات ديوانيتكم وابدأ بدعوة الأعضاء بعدها',
            style: TextStyle(
              fontSize: 14.5,
              height: 1.8,
              color: c.t2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: child,
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: c.t2,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: keyboardType,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: c.t2,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items
              .map(
                (e) => DropdownMenuItem<T>(
                  value: e,
                  child: Text(e.toString()),
                ),
              )
              .toList(),
          onChanged: onChanged,
          decoration: const InputDecoration(),
          dropdownColor: c.card,
          style: TextStyle(color: c.t1, fontSize: 14),
          iconEnabledColor: c.t2,
        ),
      ],
    );
  }
}

class _InviteEntry {
  final TextEditingController nameController;
  final TextEditingController phoneController;

  _InviteEntry({
    String name = '',
    String phone = '',
  })  : nameController = TextEditingController(text: name),
        phoneController = TextEditingController(text: phone);

  void dispose() {
    nameController.dispose();
    phoneController.dispose();
  }
}

class _BulkInviteSheet extends StatefulWidget {
  final String diwaniyaName;
  final String invitationCode;

  const _BulkInviteSheet({
    required this.diwaniyaName,
    required this.invitationCode,
  });

  @override
  State<_BulkInviteSheet> createState() => _BulkInviteSheetState();
}

class _BulkInviteSheetState extends State<_BulkInviteSheet> {
  final List<_InviteEntry> _entries = [_InviteEntry()];

  @override
  void dispose() {
    for (final e in _entries) {
      e.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    setState(() => _entries.add(_InviteEntry()));
  }

  void _removeRow(int index) {
    final item = _entries.removeAt(index);
    item.dispose();
    setState(() {});
  }

  String _composeInviteText(String name, String phone) {
    final targetName = name.trim().isEmpty ? 'حيّاك الله' : 'حيّاك الله $name';
    return '$targetName\n'
        'تمت دعوتك للانضمام إلى ${widget.diwaniyaName} عبر تطبيق ديوانية.\n'
        'رمز الدعوة: ${widget.invitationCode}\n'
        'رقم الجوال المخصص للدعوة: $phone';
  }

  void _copyAllInvites() {
    final valid = _entries
        .where((e) => e.phoneController.text.trim().isNotEmpty)
        .toList();

    if (valid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف رقم جوال واحدًا على الأقل')),
      );
      return;
    }

    final text = valid
        .map(
          (e) => _composeInviteText(
            e.nameController.text.trim(),
            e.phoneController.text.trim(),
          ),
        )
        .join('\n\n──────────\n\n');

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ رسالة الدعوات')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final insets = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + insets),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: c.t3.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'دعوة الأعضاء',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: c.t1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'أضف أكثر من عضو دفعة واحدة، ثم انسخ رسالة جاهزة لمشاركتها عبر واتساب.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.7,
                  color: c.t2,
                ),
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 16),
              for (int i = 0; i < _entries.length; i++) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.inputBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.border),
                  ),
                  child: Column(
                    children: [
                      _Field(
                        label: 'اسم العضو (اختياري)',
                        controller: _entries[i].nameController,
                        hint: 'مثال: خالد',
                      ),
                      const SizedBox(height: 10),
                      _Field(
                        label: 'رقم الجوال',
                        controller: _entries[i].phoneController,
                        hint: '05XXXXXXXX',
                        keyboardType: TextInputType.phone,
                      ),
                      if (_entries.length > 1) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => _removeRow(i),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                            ),
                            label: const Text('حذف'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _addRow,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('إضافة عضو آخر'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _copyAllInvites,
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('نسخ رسالة الدعوات'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إنهاء'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}