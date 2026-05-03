import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';
import '../models/store_offer_model.dart';

class OfferChip extends StatelessWidget {
  final StoreOffer offer;
  const OfferChip({super.key, required this.offer});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.accentSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.local_offer_rounded, size: 13, color: c.accent),
        const SizedBox(width: 6),
        Flexible(child: Text(offer.title,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.accent))),
      ]),
    );
  }
}

class OfferCard extends StatelessWidget {
  final StoreOffer offer;
  const OfferCard({super.key, required this.offer});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.accentSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.accent.withValues(alpha: 0.12)),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: c.accentMuted, borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.local_offer_rounded, size: 18, color: c.accent),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(offer.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.t1)),
          if (offer.description != null)
            Text(offer.description!, style: TextStyle(fontSize: 12, color: c.t2)),
        ])),
        if (offer.badgeText != null) Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: c.accentMuted, borderRadius: BorderRadius.circular(6)),
          child: Text(offer.badgeText!,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.accent)),
        ),
      ]),
    );
  }
}
