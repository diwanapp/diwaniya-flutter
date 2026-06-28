import 'package:flutter/material.dart';

class MarketplaceCategoryUi {
  final String key;
  final String label;
  final IconData icon;

  const MarketplaceCategoryUi({
    required this.key,
    required this.label,
    required this.icon,
  });
}

const marketplaceCategories = <MarketplaceCategoryUi>[
  MarketplaceCategoryUi(
    key: 'restaurants',
    label: 'مطاعم',
    icon: Icons.restaurant_rounded,
  ),
  MarketplaceCategoryUi(
    key: 'cafes',
    label: 'مقاهي',
    icon: Icons.coffee_rounded,
  ),
  MarketplaceCategoryUi(
    key: 'sweets',
    label: 'حلويات',
    icon: Icons.cake_rounded,
  ),
  MarketplaceCategoryUi(
    key: 'meat_butchery',
    label: 'ذبائح وملاحم',
    icon: Icons.storefront_rounded,
  ),
  MarketplaceCategoryUi(
    key: 'groceries',
    label: 'تموينات',
    icon: Icons.store_rounded,
  ),
  MarketplaceCategoryUi(
    key: 'roasters',
    label: 'محامص وقهوة',
    icon: Icons.coffee_maker_rounded,
  ),
  MarketplaceCategoryUi(
    key: 'events_hospitality',
    label: 'مناسبات وضيافة',
    icon: Icons.celebration_rounded,
  ),
  MarketplaceCategoryUi(
    key: 'camps_resthouses',
    label: 'مخيمات واستراحات',
    icon: Icons.cabin_rounded,
  ),
  MarketplaceCategoryUi(
    key: 'laundry',
    label: 'مغاسل',
    icon: Icons.local_laundry_service_rounded,
  ),
  MarketplaceCategoryUi(
    key: 'home_services',
    label: 'صيانة منزلية',
    icon: Icons.home_repair_service_rounded,
  ),
  MarketplaceCategoryUi(
    key: 'flowers_gifts',
    label: 'هدايا وورد',
    icon: Icons.local_florist_rounded,
  ),
  MarketplaceCategoryUi(
    key: 'nearby_offers',
    label: 'عروض قريبة',
    icon: Icons.local_offer_rounded,
  ),
];

MarketplaceCategoryUi? marketplaceCategoryByKey(String? key) {
  if (key == null || key.trim().isEmpty) return null;
  for (final category in marketplaceCategories) {
    if (category.key == key) return category;
  }
  return null;
}
