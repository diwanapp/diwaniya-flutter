import 'package:flutter/material.dart';

class DiwaniyaBrandMark extends StatelessWidget {
  final double size;
  final bool animated;

  const DiwaniyaBrandMark({
    super.key,
    this.size = 178,
    this.animated = true,
  });

  // Transparent logo mark for in-app splash/welcome usage.
  // App icon files should be used later for launcher/store only.
  static const String assetPath = 'assets/brand/logo_mark_splash_1024.png';

  @override
  Widget build(BuildContext context) {
    final mark = Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
    );

    if (!animated) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(child: mark),
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 950),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final scale = 0.94 + (0.06 * value);
        final turns = (1 - value) * -0.012;

        return Transform.rotate(
          angle: turns,
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: child,
            ),
          ),
        );
      },
      child: SizedBox(
        width: size,
        height: size,
        child: Center(child: mark),
      ),
    );
  }
}
