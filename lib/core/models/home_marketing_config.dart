class HomeMarketingConfig {
  final bool homeAdsEnabled;
  final HomeUpgradeCardConfig? upgradeCard;

  const HomeMarketingConfig({
    required this.homeAdsEnabled,
    required this.upgradeCard,
  });

  factory HomeMarketingConfig.fromJson(Map<String, dynamic> json) {
    final rawCard = json['home_upgrade_card'];

    return HomeMarketingConfig(
      homeAdsEnabled: json['home_ads_enabled'] == true,
      upgradeCard: rawCard is Map<String, dynamic>
          ? HomeUpgradeCardConfig.fromJson(rawCard)
          : null,
    );
  }
}

class HomeUpgradeCardConfig {
  final bool enabled;
  final String title;
  final String description;
  final String ctaLabel;
  final DateTime? startsAt;
  final DateTime? endsAt;

  const HomeUpgradeCardConfig({
    required this.enabled,
    required this.title,
    required this.description,
    required this.ctaLabel,
    required this.startsAt,
    required this.endsAt,
  });

  factory HomeUpgradeCardConfig.fromJson(Map<String, dynamic> json) {
    return HomeUpgradeCardConfig(
      enabled: json['enabled'] == true,
      title: (json['title'] ?? '').toString().trim(),
      description: (json['description'] ?? '').toString().trim(),
      ctaLabel: (json['cta_label'] ?? '').toString().trim(),
      startsAt: _parseDate(json['starts_at']),
      endsAt: _parseDate(json['ends_at']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  bool get isWithinCampaignWindow {
    final now = DateTime.now();

    if (startsAt != null && now.isBefore(startsAt!)) {
      return false;
    }

    if (endsAt != null && !now.isBefore(endsAt!)) {
      return false;
    }

    return true;
  }

  bool get shouldShow => enabled && isWithinCampaignWindow;

  String get displayTitle =>
      title.isEmpty ? 'ديوانيتكم تستاهل أكثر' : title;

  String get displayDescription => description.isEmpty
      ? 'الباقة الماسية تعطيكم مساحة أكبر ومزايا أكثر'
      : description;

  String get displayCtaLabel =>
      ctaLabel.isEmpty ? 'استفيدوا من العرض' : ctaLabel;
}
