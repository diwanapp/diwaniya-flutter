import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';

class HomeHandle extends StatelessWidget {
  final CL c;
  const HomeHandle(this.c, {super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 40, height: 4,
      decoration: BoxDecoration(
        color: c.t3.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}
