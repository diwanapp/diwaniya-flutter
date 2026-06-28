import 'package:flutter/material.dart';
import 'store_offer_model.dart';

class StoreProductPreview {
  final String id;
  final String name;
  final String? category;
  final String? description;
  final double? price;
  final String? currency;
  final String? imageUrl;

  const StoreProductPreview({
    required this.id,
    required this.name,
    this.category,
    this.description,
    this.price,
    this.currency,
    this.imageUrl,
  });
}

class Store {
  final String id;
  final String name;
  final String category;
  final String? categoryKey;
  final String? subcategory;
  final String city;
  final String district;
  final String? coverImage;
  final List<String> gallery;
  final double? rating;
  final int? reviewCount;
  final double? distanceKm;
  final String? deliveryEtaText;
  final bool? isOpenNow;
  final bool isFeatured;
  final bool isSponsored;
  final bool isVerifiedMerchant;
  final String source;
  final String? attributionLabel;
  final String? placeId;
  final String? merchantStoreId;
  final String? merchantAdId;
  final String? phone;
  final String? whatsapp;
  final String? mapUrl;
  final String? directionsUrl;
  final String? website;
  final List<String> openingHours;
  final String? attribution;
  final List<StoreProductPreview> products;
  final String description;
  final List<StoreOffer> offers;
  final List<String> tags;
  final IconData icon;

  const Store({
    required this.id,
    required this.name,
    required this.category,
    this.categoryKey,
    this.subcategory,
    required this.city,
    required this.district,
    this.coverImage,
    this.gallery = const [],
    this.rating,
    this.reviewCount,
    this.distanceKm,
    this.deliveryEtaText,
    this.isOpenNow,
    this.isFeatured = false,
    this.isSponsored = false,
    this.isVerifiedMerchant = false,
    this.source = 'diwaniya_merchant',
    this.attributionLabel,
    this.placeId,
    this.merchantStoreId,
    this.merchantAdId,
    this.phone,
    this.whatsapp,
    this.mapUrl,
    this.directionsUrl,
    this.website,
    this.openingHours = const [],
    this.attribution,
    this.products = const [],
    required this.description,
    this.offers = const [],
    this.tags = const [],
    this.icon = Icons.storefront_rounded,
  });

  List<StoreOffer> get activeOffers => offers.where((o) => o.isActive).toList();
  bool get hasActiveOffers => activeOffers.isNotEmpty;
  bool get hasRating => rating != null && rating! > 0;
  bool get hasReviewCount => reviewCount != null && reviewCount! > 0;
  bool get hasDistance => distanceKm != null && distanceKm! > 0;
  bool get isKnownOpen => isOpenNow == true;
}
