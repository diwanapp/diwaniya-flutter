import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';

class AppPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final double height;
  const AppPrimaryButton({super.key, required this.label, this.onPressed, this.height = 50});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final enabled = onPressed != null;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? c.accent : c.inputBg,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w600,
          color: enabled ? c.tInverse : c.t3)),
      ),
    );
  }
}
