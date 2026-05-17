import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';

class HomeAdBanner extends StatelessWidget {
  const HomeAdBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    return Container(
      height: 86,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.border.withValues(alpha: 0.10)),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            c.card,
            c.accent.withValues(alpha: 0.10),
            c.card,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.018),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            PositionedDirectional(
              top: -22,
              start: -18,
              child: _SoftCircle(size: 78, color: c.accent.withValues(alpha: 0.10)),
            ),
            PositionedDirectional(
              bottom: -30,
              end: -18,
              child: _SoftCircle(size: 92, color: const Color(0xFF60A5FA).withValues(alpha: 0.09)),
            ),
            PositionedDirectional(
              top: 15,
              end: 16,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.campaign_rounded, color: c.accent, size: 22),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 13, 72, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مساحة إعلان',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.t1,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'سيتم التحكم بها لاحقًا من لوحة المالك',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.t2,
                      fontSize: 11.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'تجربة مؤقتة',
                    style: TextStyle(
                      color: c.accent,
                      fontSize: 10.8,
                      fontWeight: FontWeight.w900,
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

class _SoftCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _SoftCircle({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
