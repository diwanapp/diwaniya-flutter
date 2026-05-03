import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';

class AppSectionTitle extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry padding;
  const AppSectionTitle(this.title, {super.key, this.padding = const EdgeInsets.only(right: 2, bottom: 8)});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Padding(
      padding: padding,
      child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.t1)),
    );
  }
}
