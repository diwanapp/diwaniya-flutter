import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../navigation/app_routes.dart';

enum PaywallTrigger {
  secondDiwaniya,
  memberLimit,
  photoLimit,
  pollLimit,
  dashboard,
  homeBanner,
  settingsCard,
}

/// Minimal paywall service.
///
/// Both `show*` methods navigate to the plan selection screen, which
/// serves as the upgrade destination in the post-correction flow.
/// Neither method confirms that an upgrade actually happened — the user
/// may return from `/plans` without upgrading. Return value is `false`
/// in both cases so callers do not fire false "premium activated"
/// snackbars.
///
/// A real modal paywall layer can be added later without changing call
/// sites; for now the plans screen handles the full upgrade UI.
class PaywallService {
  PaywallService._();

  static void trackEvent(String event, {Map<String, dynamic>? properties}) {
    // Analytics placeholder — no-op in this phase.
  }

  /// Show a brief contextual message (as a snackbar) explaining the
  /// limit, then navigate to the plans screen. Always returns `false`;
  /// actual upgrade confirmation happens asynchronously via the plans
  /// screen and the home screen rebuilds from `dataVersion`.
  static Future<bool> showContextualPaywall(
    BuildContext context, {
    required PaywallTrigger trigger,
    required String title,
    required String message,
    required IconData icon,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(content: Text(message)),
    );
    if (!context.mounted) return false;
    context.push(AppRoutes.plans);
    return false;
  }

  /// Navigate directly to the plans screen. Used by the home upgrade
  /// banner and the settings upgrade card.
  static Future<bool> showFullPaywall(
    BuildContext context, {
    required PaywallTrigger trigger,
  }) async {
    context.push(AppRoutes.plans);
    return false;
  }
}
