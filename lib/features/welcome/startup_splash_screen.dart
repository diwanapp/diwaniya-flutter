import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../shared/widgets/diwaniya_brand_mark.dart';

/// Startup splash shown on every cold boot for a fixed duration before
/// routing to the correct destination.
///
/// Deliberately independent of any persisted "welcome seen" flag —
/// this screen runs every launch, and its only job is to pause briefly
/// then delegate to [AuthService.nextRoute] so routing logic stays
/// centralized in one place.
///
/// The current visual is a plain logo + name fade. A branded animation
/// can replace the body without touching the timing or routing logic.
class StartupSplashScreen extends StatefulWidget {
  const StartupSplashScreen({super.key});

  @override
  State<StartupSplashScreen> createState() => _StartupSplashScreenState();
}

class _StartupSplashScreenState extends State<StartupSplashScreen>
    with SingleTickerProviderStateMixin {
  static const _splashDuration = Duration(seconds: 3);

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _navTimer = Timer(_splashDuration, _goNext);
  }

  void _goNext() {
    if (!mounted) return;
    final next = AuthService.nextRoute();
    // Legacy safety: if nextRoute ever returns /welcome, route to
    // /auth instead — the welcome curtain no longer renders.
    final target = next == '/welcome' ? '/auth' : next;
    context.go(target);
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const DiwaniyaBrandMark(size: 188),
                const SizedBox(height: 14),
                Text(
                  'ديوانية',
                  style: GoogleFonts.notoKufiArabic(
                    fontSize: 31,
                    fontWeight: FontWeight.w800,
                    color: c.t1,
                    letterSpacing: 0.2,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
