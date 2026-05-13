import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme/app_colors.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/services/auth_service.dart';
import '../../l10n/ar.dart';

class JoinRequestPendingScreen extends StatelessWidget {
  const JoinRequestPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final requests =
        AuthService.pendingJoinRequests.where((r) => r.isPending).toList();
    final title = requests.length <= 1
        ? Ar.waitingApprovalSingle
        : Ar.waitingApprovalMultiple;
    final diwaniyaName = requests.isNotEmpty ? requests.first.diwaniyaName : '';
    final body = diwaniyaName.isNotEmpty
        ? '${Ar.waitingApprovalBody}\n$diwaniyaName'
        : Ar.waitingApprovalBody;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(
          Ar.waitingApprovalTitle,
          style: TextStyle(color: c.t1, fontWeight: FontWeight.w700),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hourglass_top_rounded, size: 64, color: c.accent),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: c.t1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.7, color: c.t2),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await AuthService.signOutFromApi();
                    if (!context.mounted) return;
                    context.go(AppRoutes.auth);
                  },
                  icon: Icon(Icons.logout_rounded, color: c.error),
                  label: Text(Ar.signOut, style: TextStyle(color: c.error)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
