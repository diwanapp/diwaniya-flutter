import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../config/theme/app_colors.dart';
import '../../core/models/mock_data.dart';
import '../../core/services/auth_service.dart';
import '../../l10n/ar.dart';
import '../legal/delete_account_screen.dart';

class AccountDetailsScreen extends StatefulWidget {
  const AccountDetailsScreen({super.key});

  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  void _snack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  bool _isValidPhone(String value) {
    final normalized = value.trim().replaceAll(' ', '');
    final local = RegExp(r'^05\d{8}$');
    final intl = RegExp(r'^\+9665\d{8}$');
    return local.hasMatch(normalized) || intl.hasMatch(normalized);
  }

  Future<void> _changePhone() async {
    final profile = AuthService.profile;
    if (profile == null) {
      _snack('تعذر تحميل بيانات الحساب حالياً');
      return;
    }

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _PhoneUpdateSheet(
          initialPhone: profile.phone,
          isValidPhone: _isValidPhone,
        );
      },
    );

    if (result == null || result.trim().isEmpty || result.trim() == profile.phone) {
      return;
    }

    await AuthService.createOrUpdateProfileDraft(
      firstName: profile.firstName,
      lastName: profile.lastName,
      phone: result.trim(),
    );

    if (!mounted) {
      return;
    }
    setState(() {});
    _snack('تم تحديث رقم الجوال بنجاح');
  }

  Future<void> _changeName() async {
    final profile = AuthService.profile;
    if (profile == null) {
      _snack('تعذر تحميل بيانات الحساب حالياً');
      return;
    }
    final controller = TextEditingController(text: profile.fullName);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('تغيير الاسم'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(hintText: 'الاسم الجديد'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogCtx).pop(controller.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty || result == profile.fullName) {
      return;
    }
    try {
      await AuthService.updateDisplayName(result);
      if (!mounted) return;
      setState(() {});
      _snack('تم تحديث الاسم بنجاح');
    } catch (_) {
      if (!mounted) return;
      _snack('تعذر تحديث الاسم. حاول مرة أخرى.');
    }
  }

  Future<void> _pickProfileImage() async {
    final c = context.cl;
    final source = await showModalBottomSheet<ImageSource>(
      context: context, backgroundColor: Colors.transparent,
      builder: (d) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: c.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: Icon(Icons.camera_alt_rounded, color: c.accent),
              title: Text('الكاميرا', style: TextStyle(color: c.t1)),
              onTap: () => Navigator.pop(d, ImageSource.camera)),
          ListTile(leading: Icon(Icons.photo_library_rounded, color: c.accent),
              title: Text('المعرض', style: TextStyle(color: c.t1)),
              onTap: () => Navigator.pop(d, ImageSource.gallery)),
          if (AuthService.profileImagePath != null)
            ListTile(leading: Icon(Icons.delete_outline_rounded, color: c.error),
                title: Text(Ar.removeProfileImage, style: TextStyle(color: c.error)),
                onTap: () { Navigator.pop(d); _removeProfileImage(); }),
        ]),
      ),
    );
    if (source == null || !mounted) { return; }

    await Future.delayed(Duration.zero);
    if (!mounted) { return; }

    final picked = await ImagePicker().pickImage(source: source, maxWidth: 512, maxHeight: 512, imageQuality: 80);
    if (picked == null || !mounted) { return; }

    final dir = await getApplicationDocumentsDirectory();
    final filename = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final saved = await File(picked.path).copy('${dir.path}/$filename');

    await AuthService.updateProfileImage(saved.path);
    if (!mounted) { return; }
    setState(() {});
    _snack(Ar.profileImageUpdated);
  }

  Future<void> _removeProfileImage() async {
    await AuthService.updateProfileImage(null);
    if (!mounted) { return; }
    setState(() {});
    _snack(Ar.profileImageRemoved);
  }

  List<DiwaniyaInfo> get _visibleDiwaniyas => List<DiwaniyaInfo>.from(allDiwaniyas);

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final profile = AuthService.profile;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(Ar.accountDetailsTitle,
            style: TextStyle(color: c.t1, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Center(
            child: Column(children: [
              GestureDetector(
                onTap: _pickProfileImage,
                child: Stack(children: [
                  if (profile?.profileImagePath != null && File(profile!.profileImagePath!).existsSync())
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        image: DecorationImage(
                          image: FileImage(File(profile.profileImagePath!)),
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          c.accent.withValues(alpha: 0.28),
                          c.accent.withValues(alpha: 0.08),
                        ]),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Center(
                        child: Text(profile?.initials ?? 'ض',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: c.accent)),
                      ),
                    ),
                  Positioned(bottom: 0, left: 0,
                    child: Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.camera_alt_rounded, size: 14, color: c.tInverse),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              Text(
                ((profile?.firstName ?? '').isNotEmpty ? profile!.fullName : Ar.account),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: c.t1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                profile?.phone ?? '',
                style: TextStyle(fontSize: 14, color: c.t3),
              ),
            ]),
          ),
          const SizedBox(height: 28),

          _InfoCard(c: c, children: [
            _InfoRow(
              c: c,
              icon: Icons.person_rounded,
              label: Ar.account,
              value: ((profile?.firstName ?? '').isNotEmpty ? profile!.fullName : ''),
              trailing: TextButton.icon(
                onPressed: _changeName,
                icon: Icon(Icons.edit_rounded, size: 16, color: c.accent),
                label: Text('تغيير',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.accent),
                ),
              ),
            ),
            Divider(height: 1, color: c.divider),
            _InfoRow(
              c: c,
              icon: Icons.phone_iphone_rounded,
              label: Ar.phoneNumber,
              value: profile?.phone ?? '',
              trailing: TextButton.icon(
                onPressed: _changePhone,
                icon: Icon(Icons.edit_rounded, size: 16, color: c.accent),
                label: Text(
                  'تغيير',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: c.accent,
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.infoM,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.info.withValues(alpha: 0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: c.info),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'تغيير رقم الجوال يعمل محليًا داخل النسخة الحالية، مع تحقق OTP تجريبي مناسب لمرحلة local-first.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: c.t1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.only(right: 2, bottom: 8),
            child: Text(
              Ar.joinedDiwaniyas,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.t3,
              ),
            ),
          ),
          if (_visibleDiwaniyas.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                Ar.noDiwaniyas,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: c.t3),
              ),
            )
          else
            ..._visibleDiwaniyas.map((d) => _DiwaniyaRow(c: c, diw: d)),
          const SizedBox(height: 28),

          _DeleteAccountQuietCard(c: c),
        ],
      ),
    );
  }
}


class _DeleteAccountQuietCard extends StatelessWidget {
  final dynamic c;

  const _DeleteAccountQuietCard({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.divider.withValues(alpha: 0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: c.t3),
              const SizedBox(width: 8),
              Text(
                'إدارة الحساب',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: c.t2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'حذف الحساب خيار نهائي. قبل إتمامه يجب التأكد من عدم وجود مبالغ أو تسويات معلّقة لك أو عليك داخل أي ديوانية.',
            style: TextStyle(fontSize: 12.5, height: 1.55, color: c.t3),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: c.error.withValues(alpha: 0.82),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DeleteAccountScreen(),
                ),
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text(
                'حذف الحساب',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneUpdateSheet extends StatefulWidget {
  final String initialPhone;
  final bool Function(String value) isValidPhone;

  const _PhoneUpdateSheet({
    required this.initialPhone,
    required this.isValidPhone,
  });

  @override
  State<_PhoneUpdateSheet> createState() => _PhoneUpdateSheetState();
}

class _PhoneUpdateSheetState extends State<_PhoneUpdateSheet> {
  late final TextEditingController _phoneCtrl;
  final TextEditingController _otpCtrl = TextEditingController();
  final Random _random = Random();
  String? _generatedOtp;
  bool _codeSent = false;
  bool _verifying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _phoneCtrl = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _sendCode() {
    final phone = _phoneCtrl.text.trim();
    if (!widget.isValidPhone(phone)) {
      setState(() {
        _error = 'الرجاء إدخال رقم جوال سعودي صحيح';
      });
      return;
    }

    final code = (1000 + _random.nextInt(9000)).toString();
    setState(() {
      _generatedOtp = code;
      _codeSent = true;
      _error = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('رمز التحقق التجريبي: $code'),
      ),
    );
  }

  void _verifyAndSave() {
    if (!_codeSent || _generatedOtp == null) {
      setState(() {
        _error = 'أرسل رمز التحقق أولاً';
      });
      return;
    }

    if (_otpCtrl.text.trim() != _generatedOtp) {
      setState(() {
        _error = 'رمز التحقق غير صحيح';
      });
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });

    Navigator.of(context).pop(_phoneCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: c.divider,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'تغيير رقم الجوال',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: c.t1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'سيتم التحقق من الرقم الجديد عبر OTP محلي مناسب للنسخة الحالية.',
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: c.t3,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'رقم الجوال الجديد',
                hintText: '05xxxxxxxx',
              ),
            ),
            if (_codeSent) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'رمز التحقق',
                  hintText: 'أدخل الرمز المرسل',
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(
                  fontSize: 12,
                  color: c.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        Ar.cancel,
                        style: TextStyle(color: c.t3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _verifying
                          ? null
                          : (_codeSent ? _verifyAndSave : _sendCode),
                      child: Text(_codeSent ? 'تأكيد التغيير' : 'إرسال الرمز'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final CL c;
  final List<Widget> children;
  const _InfoCard({required this.c, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final CL c;
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  const _InfoRow({
    required this.c,
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: c.accentMuted,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 17, color: c.accent),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: c.t2))),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c.t1,
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ]),
    );
  }
}

class _DiwaniyaRow extends StatelessWidget {
  final CL c;
  final DiwaniyaInfo diw;
  const _DiwaniyaRow({required this.c, required this.diw});

  @override
  Widget build(BuildContext context) {
    final count = diwaniyaMembers[diw.id]?.length ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: diw.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                diw.name.trim().isEmpty ? 'د' : diw.name.trim().substring(0, 1),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: diw.color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  diw.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.t1,
                  ),
                ),
                Text(
                  '${diw.district} · $count ${Ar.memberUnit}',
                  style: TextStyle(fontSize: 11, color: c.t3),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
