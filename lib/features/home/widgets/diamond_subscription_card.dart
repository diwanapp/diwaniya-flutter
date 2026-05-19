
import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';

class DiamondSubscriptionCard extends StatelessWidget {
  final String title;
  final String description;
  final String badgeLine1;
  final String badgeLine2;
  final String offerPercent;
  final String offerText;
  final String buttonText;
  final VoidCallback onPressed;
  final VoidCallback onDismiss;

  const DiamondSubscriptionCard({
    super.key,
    required this.title,
    required this.description,
    required this.badgeLine1,
    required this.badgeLine2,
    required this.offerPercent,
    required this.offerText,
    required this.buttonText,
    required this.onPressed,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Container(
        decoration: BoxDecoration(
          color: _D.majlisBlueDark,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: _D.sandTaupe.withValues(alpha: 0.22),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: _D.majlisBlue.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            const Positioned.fill(child: _CardBackground()),
            PositionedDirectional(
              top: 13,
              start: 13,
              child: _DismissButton(
                color: c.t3,
                onPressed: onDismiss,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopComposition(
                    badgeLine1: badgeLine1,
                    badgeLine2: badgeLine2,
                  ),
                  const SizedBox(height: 18),
                  _TitleLine(title: title),
                  const SizedBox(height: 10),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.visible,
                    style: TextStyle(
                      color: _D.softTaupe.withValues(alpha: 0.98),
                      fontSize: 15.1,
                      fontWeight: FontWeight.w600,
                      height: 1.38,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _OfferBox(
                    percent: offerPercent,
                    offerText: offerText,
                  ),
                  const SizedBox(height: 17),
                  _PrimaryOfferButton(
                    text: buttonText,
                    onPressed: onPressed,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _D {
  static const majlisBlueDark = Color(0xFF0B1724);
  static const majlisBlue = Color(0xFF10263A);
  static const majlisBlueSoft = Color(0xFF183B55);

  static const sandTaupe = Color(0xFFB79A72);
  static const sandTaupeLight = Color(0xFFC8AD83);
  static const sandGold = Color(0xFFD9B56D);

  static const warmIvory = Color(0xFFF5EFE3);
  static const softTaupe = Color(0xFFB8AFA2);
}

class _CardBackground extends StatelessWidget {
  const _CardBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            _D.majlisBlueSoft,
            _D.majlisBlue,
            _D.majlisBlueDark,
          ],
          stops: [0.0, 0.42, 1.0],
        ),
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            top: -38,
            end: -30,
            child: _GlowOrb(
              size: 124,
              color: _D.sandTaupe.withValues(alpha: 0.030),
            ),
          ),
          PositionedDirectional(
            bottom: -58,
            start: -40,
            child: _GlowOrb(
              size: 148,
              color: _D.sandTaupeLight.withValues(alpha: 0.024),
            ),
          ),
          PositionedDirectional(
            bottom: -54,
            end: -42,
            child: _GlowOrb(
              size: 152,
              color: _D.majlisBlueSoft.withValues(alpha: 0.12),
            ),
          ),
          PositionedDirectional(
            top: 88,
            end: 18,
            child: _LightStreak(
              width: 78,
              color: _D.sandTaupeLight.withValues(alpha: 0.52),
            ),
          ),
          PositionedDirectional(
            top: 286,
            end: 58,
            child: _LightStreak(
              width: 70,
              color: _D.sandTaupe.withValues(alpha: 0.46),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopComposition extends StatelessWidget {
  final String badgeLine1;
  final String badgeLine2;

  const _TopComposition({
    required this.badgeLine1,
    required this.badgeLine2,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const PositionedDirectional(
            top: 0,
            end: 0,
            child: _DiamondIconBox(),
          ),
          PositionedDirectional(
            top: 0,
            child: _LaunchBadge(
              line1: badgeLine1,
              line2: badgeLine2,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiamondIconBox extends StatelessWidget {
  const _DiamondIconBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            _D.warmIvory.withValues(alpha: 0.13),
            _D.majlisBlueSoft.withValues(alpha: 0.32),
            _D.majlisBlue.withValues(alpha: 0.24),
          ],
        ),
        border: Border.all(
          color: _D.sandTaupeLight.withValues(alpha: 0.34),
        ),
        boxShadow: [
          BoxShadow(
            color: _D.warmIvory.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(-2, -2),
          ),
          BoxShadow(
            color: _D.sandTaupe.withValues(alpha: 0.13),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Colors.white,
            _D.warmIvory,
            _D.sandTaupeLight,
          ],
        ).createShader(bounds),
        child: const Icon(
          Icons.diamond_rounded,
          color: Colors.white,
          size: 35,
        ),
      ),
    );
  }
}

class _LaunchBadge extends StatelessWidget {
  final String line1;
  final String line2;

  const _LaunchBadge({
    required this.line1,
    required this.line2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [
            _D.sandTaupeLight.withValues(alpha: 0.98),
            _D.warmIvory.withValues(alpha: 0.28),
            _D.majlisBlueSoft.withValues(alpha: 0.40),
            _D.sandTaupeLight.withValues(alpha: 0.98),
          ],
          stops: const [0.0, 0.38, 0.62, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: _D.sandTaupeLight.withValues(alpha: 0.18),
            blurRadius: 13,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.35),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _D.majlisBlueDark.withValues(alpha: 0.92),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.055),
            ),
          ),
          child: Stack(
            children: [
              PositionedDirectional(
                top: 7,
                end: 10,
                child: _BadgeSpark(
                  size: 10,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
              PositionedDirectional(
                bottom: 10,
                start: 11,
                child: _BadgeSpark(
                  size: 8,
                  color: _D.sandTaupeLight.withValues(alpha: 0.82),
                ),
              ),
              Center(
                child: Text(
                  '$line1\n$line2',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _D.sandTaupeLight,
                    fontSize: 12.2,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TitleLine extends StatelessWidget {
  final String title;

  const _TitleLine({required this.title});

  @override
  Widget build(BuildContext context) {
    final parts = title.split(' ');
    final first = parts.isNotEmpty ? parts.first : title;
    final rest = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: TextDirection.rtl,
        children: [
          const Text(
            'ديوانيتكم ',
            style: TextStyle(
              color: _D.warmIvory,
              fontSize: 29,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [
                _D.warmIvory,
                _D.sandTaupeLight,
                _D.sandTaupe,
              ],
            ).createShader(bounds),
            child: Text(
              rest.isEmpty ? first : rest,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 29,
                fontWeight: FontWeight.w900,
                height: 1.05,
                shadows: [
                  Shadow(
                    color: _D.majlisBlueSoft,
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferBox extends StatelessWidget {
  final String percent;
  final String offerText;

  const _OfferBox({
    required this.percent,
    required this.offerText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: _D.sandTaupe.withValues(alpha: 0.34),
        ),
        boxShadow: [
          BoxShadow(
            color: _D.sandTaupeLight.withValues(alpha: 0.045),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white,
                _D.sandTaupeLight,
                _D.sandGold,
              ],
            ).createShader(bounds),
            child: Text(
              percent,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 37,
                fontWeight: FontWeight.w900,
                height: 0.95,
                shadows: [
                  Shadow(
                    color: _D.sandTaupeLight,
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 1,
            height: 38,
            margin: const EdgeInsets.symmetric(horizontal: 15),
            color: _D.warmIvory.withValues(alpha: 0.18),
          ),
          Expanded(
            child: Row(
              textDirection: TextDirection.rtl,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.local_offer_outlined,
                  size: 20,
                  color: _D.sandTaupeLight,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      offerText,
                      maxLines: 1,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: _D.warmIvory,
                        fontSize: 14.4,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryOfferButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _PrimaryOfferButton({
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [
              _D.sandTaupe,
              _D.sandTaupeLight,
              _D.warmIvory,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: _D.sandTaupeLight.withValues(alpha: 0.20),
              blurRadius: 17,
              offset: const Offset(0, 9),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.11),
              blurRadius: 9,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Stack(
          children: [
            PositionedDirectional(
              top: 0,
              start: 24,
              end: 24,
              child: Container(
                height: 1.2,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.55),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                textDirection: TextDirection.rtl,
                children: [
                  Icon(
                    Icons.diamond_rounded,
                    size: 22,
                    color: _D.majlisBlueDark.withValues(alpha: 0.76),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    text,
                    style: const TextStyle(
                      color: _D.majlisBlueDark,
                      fontSize: 16.6,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DismissButton extends StatelessWidget {
  final Color color;
  final VoidCallback onPressed;

  const _DismissButton({
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.22),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Icon(
          Icons.close_rounded,
          size: 20,
          color: color,
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}

class _LightStreak extends StatelessWidget {
  final double width;
  final Color color;

  const _LightStreak({
    required this.width,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: width,
        height: 1.3,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              color,
              Colors.white.withValues(alpha: 0.70),
              color,
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeSpark extends StatelessWidget {
  final double size;
  final Color color;

  const _BadgeSpark({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size,
              height: 1.1,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Container(
              width: 1.1,
              height: size,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
