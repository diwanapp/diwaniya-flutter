import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/mock_data.dart';

/// Builds the invitation message text and triggers the native share
/// sheet via share_plus. Single source of truth for invite message
/// formatting so the wording cannot drift between call sites.
class InviteShareService {
  InviteShareService._();

  // App link placeholder — replace with the real store/landing URL
  // when distribution links exist.
  static const String _appLinkPlaceholder = 'https://diwaniya.online';

  /// Build the ready-made invitation message for the given diwaniya.
  /// Includes diwaniya name, invitation code, and the app link.
  static String buildMessage(DiwaniyaInfo diw) {
    final code = diw.invitationCode ?? '';
    return 'حياك الله 🌟\n'
        'ندعوك للانضمام إلى ديوانية ${diw.name} عبر تطبيق ديوانية.\n'
        'رمز الدعوة الخاص بك: $code\n'
        'حمّل التطبيق وأدخل الرمز للانضمام مباشرة.\n'
        '$_appLinkPlaceholder';
  }

  static String buildAppInviteMessage() {
    return 'حمّل تطبيق ديوانية وابدأ بتنظيم ديوانيتك بكل سهولة.\n\n'
        'من خلال التطبيق تقدر:\n'
        '- تنشئ ديوانيتك الخاصة\n'
        '- ترسل رموز الدعوة للأعضاء\n'
        '- تدير الألبوم والتنبيهات والمشاركات\n'
        '- تتابع السوق والخدمات المرتبطة بديوانيتك\n\n'
        'رابط التحميل:\n'
        '$_appLinkPlaceholder';
  }

  static Future<void> sharePlainText(
    BuildContext context,
    String message, {
    String? subject,
  }) async {
    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      message,
      subject: subject,
      sharePositionOrigin:
          box != null ? box.localToGlobal(Offset.zero) & box.size : null,
    );
  }

  /// Open the native share sheet with the invitation message for the
  /// given diwaniya. No-op if the diwaniya has no invitation code.
  static Future<void> shareForDiwaniya(
    BuildContext context,
    DiwaniyaInfo diw,
  ) async {
    if (diw.invitationCode == null || diw.invitationCode!.isEmpty) {
      return;
    }
    final message = buildMessage(diw);
    await sharePlainText(
      context,
      message,
      subject: 'دعوة للانضمام إلى ديوانية ${diw.name}',
    );
  }
}
