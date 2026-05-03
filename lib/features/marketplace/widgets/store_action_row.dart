import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme/app_colors.dart';
import '../../../l10n/ar.dart';
import '../models/store_model.dart';

class StoreActionRow extends StatelessWidget {
  final Store store;
  const StoreActionRow({super.key, required this.store});

  void _copyAndSnack(BuildContext context, String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم نسخ $label')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final actions = <Widget>[
      if (store.phone != null)
        Expanded(
          child: _ActionBtn(
            icon: Icons.call_rounded,
            label: Ar.callAction,
            color: c.success,
            enabled: true,
            onTap: () => _copyAndSnack(context, Ar.callAction, store.phone!),
          ),
        ),
      if (store.phone != null && store.whatsapp != null) const SizedBox(width: 10),
      if (store.whatsapp != null)
        Expanded(
          child: _ActionBtn(
            icon: Icons.chat_rounded,
            label: Ar.whatsappAction,
            color: const Color(0xFF25D366),
            enabled: true,
            onTap: () => _copyAndSnack(context, Ar.whatsappAction, store.whatsapp!),
          ),
        ),
      if ((store.phone != null || store.whatsapp != null) && store.mapUrl != null)
        const SizedBox(width: 10),
      if (store.mapUrl != null)
        Expanded(
          child: _ActionBtn(
            icon: Icons.map_rounded,
            label: Ar.mapsAction,
            color: c.info,
            enabled: true,
            onTap: () => _copyAndSnack(context, Ar.mapsAction, store.mapUrl!),
          ),
        ),
    ];

    if (actions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.inputBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 18, color: c.t3),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'سيتم تفعيل وسائل التواصل مع المتجر عند ربط البيانات الحية.',
                style: TextStyle(fontSize: 12.5, color: c.t3, height: 1.5),
              ),
            ),
          ],
        ),
      );
    }

    return Row(children: actions);
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback? onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: enabled ? 0.10 : 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 22, color: enabled ? color : color.withValues(alpha: 0.45)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: enabled ? color : color.withValues(alpha: 0.45),
              ),
            ),
          ]),
        ),
      );
}
