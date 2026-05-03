import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme/app_colors.dart';

enum InquiryType { technical, suggestion, question }

extension InquiryTypeX on InquiryType {
  String get label {
    switch (this) {
      case InquiryType.technical:
        return 'مشكلة تقنية';
      case InquiryType.suggestion:
        return 'اقتراح / تحسين';
      case InquiryType.question:
        return 'استفسار / سؤال';
    }
  }
}

class InquiriesScreen extends StatefulWidget {
  const InquiriesScreen({super.key});

  @override
  State<InquiriesScreen> createState() => _InquiriesScreenState();
}

class _InquiriesScreenState extends State<InquiriesScreen> {
  InquiryType _type = InquiryType.technical;
  final _details = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  bool get _canSend => _details.text.trim().length >= 5 && !_sending;

  static const String _supportEmail = 'support@diwaniya.app';

  Future<void> _submit() async {
    if (!_canSend) return;
    setState(() => _sending = true);
    try {
      final subject = '[ديوانية] ${_type.label}';
      final body = '${_type.label}\n\n${_details.text.trim()}';
      final uri = Uri(
        scheme: 'mailto',
        path: _supportEmail,
        query: _encodeQuery({
          'subject': subject,
          'body': body,
        }),
      );
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      setState(() => _sending = false);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذّر فتح تطبيق البريد. يرجى التواصل عبر support@diwaniya.app',
            ),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم فتح البريد لإرسال الإبلاغ')),
      );
      _details.clear();
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدث خطأ غير متوقع، حاول مرة أخرى.'),
        ),
      );
    }
  }

  /// Encode mailto query params manually because Uri's queryParameters
  /// uses '+' for spaces, which most mail clients render literally.
  String _encodeQuery(Map<String, String> params) {
    return params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        title: Text('للاستفسارات والاقتراحات',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: c.t1)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('نوع الإبلاغ',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: c.t2)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.border),
                ),
                child: Column(
                  children: InquiryType.values.map((t) {
                    final selected = _type == t;
                    return InkWell(
                      onTap: () => setState(() => _type = t),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 20,
                              color: selected ? c.accent : c.t3,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(t.label,
                                  style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                      color: c.t1)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 22),
              Text('تفاصيل الإبلاغ',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: c.t2)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.border),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                child: TextField(
                  controller: _details,
                  maxLines: 6,
                  minLines: 6,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'اكتب أي نص لإضافته',
                    hintStyle: TextStyle(color: c.t3),
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _canSend ? _submit : null,
                  child: Text(_sending ? 'جاري فتح البريد...' : 'إرسال الإبلاغ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
