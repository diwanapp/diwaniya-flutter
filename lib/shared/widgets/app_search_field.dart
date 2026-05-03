import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';

class AppSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  const AppSearchField({super.key, required this.controller, required this.hint, required this.onChanged, this.onClear});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final hasText = controller.text.isNotEmpty;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
      style: TextStyle(fontSize: 14, color: c.t1),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.t3),
        prefixIcon: Icon(Icons.search_rounded, color: c.t3, size: 20),
        suffixIcon: hasText
            ? GestureDetector(
                onTap: () { controller.clear(); onClear?.call(); },
                child: Icon(Icons.close_rounded, color: c.t3, size: 18))
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        filled: true,
        fillColor: c.card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }
}
