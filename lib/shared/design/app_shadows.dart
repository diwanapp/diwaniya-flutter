import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';

abstract final class AppShadows {
  static List<BoxShadow> card(BuildContext context) => [
    BoxShadow(color: context.cl.shadow, blurRadius: 6),
  ];

  static List<BoxShadow> elevated(BuildContext context) => [
    BoxShadow(color: context.cl.shadow, blurRadius: 12, offset: const Offset(0, 2)),
  ];

  static const none = <BoxShadow>[];
}
