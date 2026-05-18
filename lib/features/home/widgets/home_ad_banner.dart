import 'dart:async';

import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';

class HomeAdBanner extends StatefulWidget {
  const HomeAdBanner({super.key});

  @override
  State<HomeAdBanner> createState() => _HomeAdBannerState();
}

class _HomeAdBannerState extends State<HomeAdBanner> {
  final PageController _controller = PageController();
  Timer? _timer;
  int _index = 0;

  static const List<_AdItem> _ads = [
    _AdItem(
      title: 'عرض خاص',
      subtitle: 'خصومات موسمية على أطقم الهلال',
      footnote: 'إعلان تجريبي',
      assetPath: 'assets/ads/bluewave_test.png',
      icon: Icons.local_offer_rounded,
    ),
    _AdItem(
      title: 'مساحة إعلان',
      subtitle: 'سيتم التحكم بها لاحقًا من لوحة المالك',
      footnote: 'تجربة مؤقتة',
      assetPath: null,
      icon: Icons.campaign_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();

    if (_ads.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted || !_controller.hasClients) return;
        final next = (_index + 1) % _ads.length;
        _controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 480),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    return SizedBox(
      height: 104,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: _ads.length,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (context, i) {
                return _AdSlide(
                  ad: _ads[i],
                  c: c,
                );
              },
            ),
            PositionedDirectional(
              bottom: 9,
              start: 0,
              end: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_ads.length, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 15 : 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.white.withValues(alpha: 0.88)
                          : Colors.white.withValues(alpha: 0.30),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdSlide extends StatelessWidget {
  final _AdItem ad;
  final CL c;

  const _AdSlide({
    required this.ad,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = ad.assetPath != null;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasImage)
          Image.asset(
            ad.assetPath!,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => _GradientFallback(ad: ad, c: c),
          )
        else
          _GradientFallback(ad: ad, c: c),

        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
              colors: [
                Colors.black.withValues(alpha: 0.58),
                Colors.black.withValues(alpha: 0.18),
                Colors.black.withValues(alpha: 0.55),
              ],
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Icon(
                  ad.icon,
                  color: c.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      ad.title,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17.5,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      ad.subtitle,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 12.4,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      ad.footnote,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.accent,
                        fontSize: 11.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GradientFallback extends StatelessWidget {
  final _AdItem ad;
  final CL c;

  const _GradientFallback({
    required this.ad,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            c.accent.withValues(alpha: 0.28),
            c.card,
            c.accent.withValues(alpha: 0.18),
          ],
        ),
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            start: -28,
            bottom: -34,
            child: Container(
              width: 124,
              height: 124,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.accent.withValues(alpha: 0.08),
              ),
            ),
          ),
          PositionedDirectional(
            end: -26,
            top: -34,
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.accent.withValues(alpha: 0.06),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdItem {
  final String title;
  final String subtitle;
  final String footnote;
  final String? assetPath;
  final IconData icon;

  const _AdItem({
    required this.title,
    required this.subtitle,
    required this.footnote,
    required this.assetPath,
    required this.icon,
  });
}
