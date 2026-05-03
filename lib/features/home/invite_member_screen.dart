import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme/app_colors.dart';
import '../../l10n/ar.dart';

class InviteMemberScreen extends StatelessWidget {
  final String diwaniyaName;
  final String invitationCode;

  const InviteMemberScreen({
    super.key,
    required this.diwaniyaName,
    required this.invitationCode,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(Ar.inviteTitle,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.t1)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: c.border),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: c.accentMuted,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(Icons.group_add_rounded, size: 32, color: c.accent),
                    ),
                    const SizedBox(height: 20),
                    Text(diwaniyaName,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.t1)),
                    const SizedBox(height: 12),
                    Text(Ar.inviteSubtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, height: 1.7, color: c.t2)),
                    const SizedBox(height: 28),
                    Text(Ar.invitationCode,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.t3)),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: c.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: c.accent.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        invitationCode.isEmpty ? '—' : invitationCode,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                          color: c.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: invitationCode.isEmpty
                      ? null
                      : () {
                          Clipboard.setData(ClipboardData(text: invitationCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text(Ar.codeCopied)),
                          );
                        },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text(Ar.shareCode),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
