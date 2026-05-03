import 'package:flutter/material.dart';
import 'store_offer_model.dart';

class Store {
  final String id;
  final String name;
  final String category;
  final String? subcategory;
  final String city;
  final String district;
  final String? coverImage;
  final List<String> gallery;
  final double rating;
  final int reviewCount;
  final double distanceKm;
  final String? deliveryEtaText;
  final bool isOpenNow;
  final bool isFeatured;
  final bool isSponsored;
  final String? phone;
  final String? whatsapp;
  final String? mapUrl;
  final String description;
  final List<StoreOffer> offers;
  final List<String> tags;
  final IconData icon;

  const Store({
    required this.id,
    required this.name,
    required this.category,
    this.subcategory,
    required this.city,
    required this.district,
    this.coverImage,
    this.gallery = const [],
    required this.rating,
    this.reviewCount = 0,
    required this.distanceKm,
    this.deliveryEtaText,
    required this.isOpenNow,
    this.isFeatured = false,
    this.isSponsored = false,
    this.phone,
    this.whatsapp,
    this.mapUrl,
    required this.description,
    this.offers = const [],
    this.tags = const [],
    this.icon = Icons.storefront_rounded,
  });

  List<StoreOffer> get activeOffers => offers.where((o) => o.isActive).toList();
  bool get hasActiveOffers => activeOffers.isNotEmpty;
}
