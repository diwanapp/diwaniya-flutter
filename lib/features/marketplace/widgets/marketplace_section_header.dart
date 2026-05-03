import 'package:flutter/material.dart';

import '../../../shared/widgets/app_section_title.dart';
import '../models/store_model.dart';
import 'store_card.dart';

class MarketplaceSectionHeader extends StatelessWidget {
  final String title;
  const MarketplaceSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return AppSectionTitle(title,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10));
  }
}

/// Horizontal scrollable store section with title + card row.
class MarketplaceHorizontalSection extends StatelessWidget {
  final String title;
  final List<Store> stores;
  const MarketplaceHorizontalSection({super.key, required this.title, required this.stores});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        MarketplaceSectionHeader(title: title),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            clipBehavior: Clip.none,
            itemCount: stores.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => SizedBox(
              width: 260,
              child: StoreCard(store: stores[i], compact: true),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }
}
