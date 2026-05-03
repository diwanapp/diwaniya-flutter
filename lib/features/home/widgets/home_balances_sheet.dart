import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';
import '../../../core/models/expense_models.dart';
import '../../../core/models/mock_data.dart';
import '../../../l10n/ar.dart';
import 'home_handle.dart';

class HomeBalancesSheet extends StatelessWidget {
  final List<Debt> debts;
  final void Function(Debt)? onSettle;

  const HomeBalancesSheet({super.key, required this.debts, this.onSettle});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: c.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        HomeHandle(c),
        const SizedBox(height: 16),
        Text(Ar.balancesTitle, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.t1)),
        const SizedBox(height: 16),
        if (debts.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle_rounded, size: 48, color: c.success),
              const SizedBox(height: 12),
              Text(Ar.noDebts, style: TextStyle(fontSize: 14, color: c.t2)),
            ]))
        else
          Flexible(child: ListView.separated(
            shrinkWrap: true, itemCount: debts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, i) {
              final b = debts[i];
              final fromM = diwaniyaMembers.values.expand((l) => l).where((m) => m.name == b.from).firstOrNull;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: c.inputBg, borderRadius: BorderRadius.circular(13)),
                child: Row(children: [
                  CircleAvatar(radius: 16,
                    backgroundColor: (fromM?.avatarColor ?? c.accent).withValues(alpha: 0.15),
                    child: Text(fromM?.initials ?? '?',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: fromM?.avatarColor ?? c.accent))),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    RichText(text: TextSpan(
                      style: TextStyle(fontSize: 13, fontFamily: 'IBM Plex Sans Arabic', color: c.t1),
                      children: [
                        TextSpan(text: b.from, style: const TextStyle(fontWeight: FontWeight.w600)),
                        TextSpan(text: ' ${Ar.paysTo} ', style: TextStyle(color: c.t3)),
                        TextSpan(text: b.to, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    )),
                    const SizedBox(height: 2),
                    Text('${b.amount.toInt()} ر.س',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.error)),
                  ])),
                  GestureDetector(
                    onTap: onSettle != null ? () => onSettle!(b) : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(8)),
                      child: Text(Ar.settlement,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.tInverse))),
                  ),
                ]),
              );
            },
          )),
      ]),
    );
  }
}
