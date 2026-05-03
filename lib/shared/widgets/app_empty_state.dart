import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const AppEmptyState({super.key, required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Center(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 48, color: c.t3),
        const SizedBox(height: 14),
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.t1)),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: c.t3)),
        ],
      ]),
    ));
  }
}
