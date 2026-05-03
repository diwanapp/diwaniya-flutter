import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../l10n/ar.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _left;
  late final Animation<double> _right;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _left = Tween<double>(begin: 0, end: -1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
    _right = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
    _fade = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _boot();
  }

  Future<void> _boot() async {
    final initialRoute = AuthService.nextRoute();

    await Future.wait([
      _controller.forward(),
      Future<void>.delayed(const Duration(seconds: 3)),
    ]);

    if (AuthService.nextRoute() == '/welcome') {
      await AuthService.markWelcomeSeen();
    }

    if (!mounted) return;
    final target =
        initialRoute == '/welcome' ? AuthService.nextRoute() : initialRoute;
    context.go(target);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Scaffold(
      backgroundColor: c.bg,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [c.bg, c.card],
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Opacity(
                          opacity: 1 - _controller.value * 0.35,
                          child: Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              color: c.accentMuted,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: c.accent.withValues(alpha: 0.22),
                              ),
                            ),
                            child: Icon(
                              Icons.groups_rounded,
                              size: 50,
                              color: c.accent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          Ar.appName,
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: c.t1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'تنظيم الديوانية، وإدارة التفاصيل، ومتابعة ما يلزم، في تجربة واحدة أكثر وضوحًا.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14.5,
                            height: 1.8,
                            color: c.t2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (AuthService.nextRoute() == '/welcome') ...[
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(
                      MediaQuery.of(context).size.width * _left.value,
                      0,
                    ),
                    child: const _CurtainPanel(side: Alignment.centerLeft),
                  ),
                ),
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(
                      MediaQuery.of(context).size.width * _right.value,
                      0,
                    ),
                    child: const _CurtainPanel(side: Alignment.centerRight),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: _fade.value,
                      child: const Center(
                        child: Text(
                          Ar.curtainWelcome,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CurtainPanel extends StatelessWidget {
  final Alignment side;
  const _CurtainPanel({required this.side});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: side,
      child: Container(
        width: MediaQuery.of(context).size.width / 2 + 12,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF50211D), Color(0xFF7C3429), Color(0xFFA64733)],
          ),
        ),
        child: CustomPaint(
          painter: _CurtainPainter(),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _CurtainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.06);
    const spacing = 28.0;
    for (double x = 14; x < size.width; x += spacing) {
      canvas.drawRRect(
        RRect.fromLTRBR(x, 0, x + 10, size.height, const Radius.circular(6)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
