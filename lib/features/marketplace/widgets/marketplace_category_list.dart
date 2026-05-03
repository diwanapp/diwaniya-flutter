import 'package:flutter/material.dart';

import '../../../l10n/ar.dart';
import '../../../shared/widgets/app_chip.dart';
import '../data/marketplace_mock_data.dart';

class MarketplaceCategoryList extends StatelessWidget {
  final String? selectedCategory;
  final ValueChanged<String?> onCategoryChanged;
  const MarketplaceCategoryList({super.key, required this.selectedCategory, required this.onCategoryChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: marketplaceCategories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i == 0) {
            return AppChip(
              label: Ar.allCategories,
              icon: Icons.grid_view_rounded,
              selected: selectedCategory == null,
              onTap: () => onCategoryChanged(null),
            );
          }
          final cat = marketplaceCategories.keys.elementAt(i - 1);
          return AppChip(
            label: cat,
            icon: marketplaceCategories[cat]!,
            selected: selectedCategory == cat,
            onTap: () => onCategoryChanged(selectedCategory == cat ? null : cat),
          );
        },
      ),
    );
  }
}
