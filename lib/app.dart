import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'config/theme/app_theme.dart';
import 'core/services/auth_service.dart';
import 'core/services/session_service.dart';
import 'features/album/album_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/expenses/expenses_screen.dart';
import 'features/home/home_screen.dart';
import 'features/home/invite_member_screen.dart';
import 'features/maqadi/maqadi_screen.dart';
import 'features/marketplace/marketplace_screen.dart';
import 'features/scorekeeping/scorekeeping_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/diwaniya_details_screen.dart';
import 'features/settings/account_details_screen.dart';
import 'features/settings/inquiries_screen.dart';
import 'features/settings/notification_settings_screen.dart';
import 'features/settings/manager_join_requests_screen.dart';
import 'features/marketplace/store_details_screen.dart';
import 'features/welcome/auth_screen.dart';
import 'features/welcome/create_diwaniya_screen.dart';
import 'features/welcome/diwaniya_access_screen.dart';
import 'features/welcome/join_diwaniya_screen.dart';
import 'features/welcome/join_request_pending_screen.dart';
import 'features/welcome/otp_verification_screen.dart';
import 'features/welcome/plan_selection_screen.dart';
import 'features/welcome/startup_splash_screen.dart';
import 'features/welcome/welcome_screen.dart';
import 'l10n/ar.dart';
import 'core/navigation/app_routes.dart';
import 'shared/widgets/app_shell.dart';

export 'core/navigation/app_routes.dart';

class DiwaniyaApp extends StatelessWidget {
  const DiwaniyaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark ||
            (mode == ThemeMode.system &&
                WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                    Brightness.dark);

        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor:
                isDark ? const Color(0xFF1A1D27) : Colors.white,
            systemNavigationBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
          ),
        );

        return ValueListenableBuilder<int>(
          valueListenable: SessionService.stateVersion,
          builder: (context, _, __) {
            return MaterialApp.router(
              debugShowCheckedModeBanner: false,
              title: 'ديوانية',
              routerConfig: _router,
              locale: const Locale('ar'),
              supportedLocales: const [Locale('ar')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: mode,
              builder: (context, child) => Directionality(
                textDirection: TextDirection.rtl,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(1.0),
                  ),
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── State-based auth guard ──
//
// Determines the user's current progression state from SessionService
// and AuthService, then decides whether the requested location is
// permissible or the user must be redirected to the canonical route
// for their current state.
//
// /startup is always allowed and never redirected — it's a pure
// animation screen that routes itself to the correct next destination
// when the splash timer fires.
//
// States (in order, evaluated only when not on /startup):
//   S1: no profile                  → /auth only
//   S2: profile but no OTP in session → /auth (cold boot) or /otp (live)
//   S3: authenticated, no diwaniya  → diwaniya-access / create / join
//   S4: authenticated + diwaniya    → home shell + upgrade + switcher;
//                                     earlier-state screens blocked
String? _authGuard(BuildContext context, GoRouterState state) {
  final location = state.matchedLocation;

  // Startup splash is always allowed — it handles its own navigation.
  if (location == AppRoutes.startup) return null;

  final hasProfile = AuthService.profile != null;
  final otpVerified = AuthService.otpVerified;
  final hasDiwaniya = AuthService.hasDiwaniya;

  // S1: no profile on disk
  if (!hasProfile) {
    return location == AppRoutes.auth ? null : AppRoutes.auth;
  }
  // S2: profile exists but OTP not yet verified. /otp is only valid
  // if an OTP was actually requested in the current live session —
  // otherwise (e.g. cold boot mid-flow), bounce back to /auth so the
  // user can restart the request rather than landing on an orphaned
  // OTP screen.
  if (!otpVerified) {
    if (!AuthService.otpRequestedInSession) {
      return location == AppRoutes.auth ? null : AppRoutes.auth;
    }
    return location == AppRoutes.otp ? null : AppRoutes.otp;
  }
  // S3: authenticated, no approved diwaniya. If the user has at
  // least one pending join request, route them to the waiting-for-
  // approval placeholder; otherwise the original create/join entry.
  // The waiting screen, create, join, and access screens are all
  // allowed in this state so the user can sign out, switch paths,
  // or revisit any of them without being bounced.
  if (!hasDiwaniya) {
    const allowed = {
      AppRoutes.diwaniyaAccess,
      AppRoutes.createDiwaniya,
      AppRoutes.joinDiwaniya,
      AppRoutes.joinRequestPending,
    };
    if (allowed.contains(location)) return null;
    return AuthService.hasPendingJoinRequest
        ? AppRoutes.joinRequestPending
        : AppRoutes.diwaniyaAccess;
  }
  // S4: fully onboarded — block earlier-state screens. createDiwaniya
  // and joinDiwaniya remain allowed so users can manage multiple
  // diwaniyas from the home switcher.
  const blockedWhenOnboarded = {
    AppRoutes.welcome,
    AppRoutes.auth,
    AppRoutes.otp,
    AppRoutes.diwaniyaAccess,
    AppRoutes.joinRequestPending,
  };
  if (blockedWhenOnboarded.contains(location)) {
    return AppRoutes.home;
  }
  return null;
}

final GoRouter _router = GoRouter(
  initialLocation: AppRoutes.startup,
  redirect: _authGuard,
  routes: [
    GoRoute(
      path: AppRoutes.startup,
      builder: (_, __) => const StartupSplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.welcome,
      builder: (_, __) => const WelcomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.auth,
      builder: (_, __) => const AuthScreen(),
    ),
    GoRoute(
      path: AppRoutes.otp,
      builder: (_, __) => const OtpVerificationScreen(),
    ),
    GoRoute(
      path: AppRoutes.diwaniyaAccess,
      builder: (_, __) => const DiwaniyaAccessScreen(),
    ),
    GoRoute(
      path: AppRoutes.createDiwaniya,
      builder: (_, __) => const CreateDiwaniyaScreen(),
    ),
    GoRoute(
      path: AppRoutes.joinDiwaniya,
      builder: (_, __) => const JoinDiwaniyaScreen(),
    ),
    GoRoute(
      path: AppRoutes.joinRequestPending,
      builder: (_, __) => const JoinRequestPendingScreen(),
    ),
    GoRoute(
      path: AppRoutes.plans,
      builder: (_, __) => const PlanSelectionScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (_, __) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.expenses,
              builder: (_, __) => const ExpensesScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.marketplace,
              builder: (_, __) => const MarketplaceScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.maqadi,
              builder: (_, __) => const MaqadiScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.scorekeeping,
              builder: (_, __) => const ScorekeepingScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (_, __) => const SettingsScreen(),
    ),
    GoRoute(
      path: AppRoutes.chat,
      builder: (_, __) => const ChatScreen(),
    ),
    GoRoute(
      path: AppRoutes.album,
      builder: (_, __) => const AlbumScreen(),
    ),
    GoRoute(
      path: AppRoutes.inviteMember,
      builder: (context, state) {
        final args = state.extra is InviteMemberArgs
            ? state.extra as InviteMemberArgs
            : const InviteMemberArgs(
                diwaniyaName: '',
                invitationCode: '',
              );

        return InviteMemberScreen(
          diwaniyaName: args.diwaniyaName,
          invitationCode: args.invitationCode,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.diwaniyaDetails,
      builder: (context, state) {
        final diwaniyaId = state.extra is String ? state.extra as String : '';
        return DiwaniyaDetailsScreen(diwaniyaId: diwaniyaId);
      },
    ),
    GoRoute(
      path: AppRoutes.managerJoinRequests,
      builder: (context, state) {
        final diwaniyaId = state.extra is String ? state.extra as String : '';
        return ManagerJoinRequestsScreen(diwaniyaId: diwaniyaId);
      },
    ),
    GoRoute(
      path: AppRoutes.accountDetails,
      builder: (_, __) => const AccountDetailsScreen(),
    ),
    GoRoute(
      path: AppRoutes.inquiries,
      builder: (_, __) => const InquiriesScreen(),
    ),
    GoRoute(
      path: AppRoutes.notifSettings,
      builder: (_, __) => const NotificationSettingsScreen(),
    ),
    GoRoute(
      path: AppRoutes.storeDetails,
      builder: (context, state) {
        final storeId = state.extra is String ? state.extra as String : '';
        return StoreDetailsScreen(storeId: storeId);
      },
    ),
  ],
  errorBuilder: (context, state) => const Scaffold(
    body: Center(
      child: Text(Ar.loadingRoute),
    ),
  ),
);