import 'api_client.dart';
import 'endpoints.dart';

enum SubscriptionDurationChoice {
  threeMonths,
  annual;

  String get backendKey {
    switch (this) {
      case SubscriptionDurationChoice.threeMonths:
        return 'three_months';
      case SubscriptionDurationChoice.annual:
        return 'annual';
    }
  }

  int get months => this == annual ? 12 : 3;
}

class SubscriptionTierOption {
  final int memberLimit;
  final String label;

  const SubscriptionTierOption({
    required this.memberLimit,
    required this.label,
  });

  factory SubscriptionTierOption.fromJson(Map<String, dynamic> json) {
    final limit = _asInt(json['member_limit']);
    return SubscriptionTierOption(
      memberLimit: limit,
      label: (json['display_label'] ?? json['label'] ?? '$limit').toString(),
    );
  }
}

class SubscriptionCatalog {
  final List<SubscriptionTierOption> tiers;
  final int defaultMemberLimit;
  final SubscriptionDurationChoice defaultDuration;
  final double pricePerMemberMonthSar;
  final int yearlyDiscountPercent;
  final bool autoRenewDefault;
  final List<String> notes;

  const SubscriptionCatalog({
    required this.tiers,
    required this.defaultMemberLimit,
    required this.defaultDuration,
    required this.pricePerMemberMonthSar,
    required this.yearlyDiscountPercent,
    required this.autoRenewDefault,
    required this.notes,
  });

  factory SubscriptionCatalog.fromJson(Map<String, dynamic> json) {
    final rawTiers = json['tiers'];
    final tiers = rawTiers is List
        ? rawTiers
            .whereType<Map>()
            .map((item) => SubscriptionTierOption.fromJson(
                  Map<String, dynamic>.from(item),
                ))
            .toList(growable: false)
        : const <SubscriptionTierOption>[];
    final rawNotes = json['notes'];
    return SubscriptionCatalog(
      tiers: tiers,
      defaultMemberLimit: _asInt(json['default_member_limit'], fallback: 10),
      defaultDuration: _durationFromBackend(json['default_duration']),
      pricePerMemberMonthSar: _asDouble(json['price_per_member_month_sar']),
      yearlyDiscountPercent: _asInt(json['yearly_discount_percent']),
      autoRenewDefault: json['auto_renew_default'] != false,
      notes: rawNotes is List
          ? rawNotes.map((item) => item.toString()).toList(growable: false)
          : const <String>[],
    );
  }
}

class SubscriptionPriceQuote {
  final int memberLimit;
  final SubscriptionDurationChoice duration;
  final int durationMonths;
  final double subtotalSar;
  final double amountSar;
  final double savingsSar;
  final String currency;
  final String label;

  const SubscriptionPriceQuote({
    required this.memberLimit,
    required this.duration,
    required this.durationMonths,
    required this.subtotalSar,
    required this.amountSar,
    required this.savingsSar,
    required this.currency,
    required this.label,
  });

  factory SubscriptionPriceQuote.fromJson(Map<String, dynamic> json) {
    return SubscriptionPriceQuote(
      memberLimit: _asInt(json['member_limit']),
      duration: _durationFromBackend(json['duration']),
      durationMonths: _asInt(json['duration_months']),
      subtotalSar: _asDouble(json['subtotal_sar']),
      amountSar: _asDouble(json['amount_sar']),
      savingsSar: _asDouble(json['savings_sar']),
      currency: (json['currency'] ?? 'SAR').toString(),
      label: (json['label'] ?? '').toString(),
    );
  }
}

class DiwaniyaSubscriptionServerStatus {
  final String effectiveStatus;
  final int memberCount;
  final int memberLimit;
  final int photoCount;
  final int photoLimit;
  final int activePollCount;
  final int activePollLimit;
  final bool autoRenew;
  final bool cancelAtPeriodEnd;
  final int? pendingMemberLimit;
  final int? pendingDurationMonths;
  final String? noticeAr;

  const DiwaniyaSubscriptionServerStatus({
    required this.effectiveStatus,
    required this.memberCount,
    required this.memberLimit,
    required this.photoCount,
    required this.photoLimit,
    required this.activePollCount,
    required this.activePollLimit,
    required this.autoRenew,
    required this.cancelAtPeriodEnd,
    required this.pendingMemberLimit,
    required this.pendingDurationMonths,
    required this.noticeAr,
  });

  factory DiwaniyaSubscriptionServerStatus.fromJson(Map<String, dynamic> json) {
    return DiwaniyaSubscriptionServerStatus(
      effectiveStatus: (json['effective_status'] ?? '').toString(),
      memberCount: _asInt(json['member_count']),
      memberLimit: _asInt(json['member_limit']),
      photoCount: _asInt(json['photo_count']),
      photoLimit: _asInt(json['photo_limit']),
      activePollCount: _asInt(json['active_poll_count']),
      activePollLimit: _asInt(json['active_poll_limit']),
      autoRenew: json['auto_renew'] == true,
      cancelAtPeriodEnd: json['cancel_at_period_end'] == true,
      pendingMemberLimit: _asNullableInt(json['pending_member_limit']),
      pendingDurationMonths: _asNullableInt(json['pending_duration_months']),
      noticeAr: json['notice_ar']?.toString(),
    );
  }
}

class SubscriptionPurchaseIntentResult {
  final String status;
  final String provider;
  final String messageAr;
  final SubscriptionPriceQuote preview;

  const SubscriptionPurchaseIntentResult({
    required this.status,
    required this.provider,
    required this.messageAr,
    required this.preview,
  });

  factory SubscriptionPurchaseIntentResult.fromJson(Map<String, dynamic> json) {
    return SubscriptionPurchaseIntentResult(
      status: (json['status'] ?? '').toString(),
      provider: (json['provider'] ?? '').toString(),
      messageAr: (json['message_ar'] ?? '').toString(),
      preview: SubscriptionPriceQuote.fromJson(
        Map<String, dynamic>.from(json['preview'] as Map),
      ),
    );
  }
}

class SubscriptionApi {
  SubscriptionApi._();

  static Future<SubscriptionCatalog> fetchCatalog() async {
    final raw = await ApiClient.get(Endpoints.subscriptionCatalog) as Map;
    return SubscriptionCatalog.fromJson(Map<String, dynamic>.from(raw));
  }

  static Future<SubscriptionPriceQuote> previewPrice({
    required int memberLimit,
    required SubscriptionDurationChoice duration,
  }) async {
    final raw = await ApiClient.post(
      Endpoints.subscriptionPreview,
      body: {
        'member_limit': memberLimit,
        'duration': duration.backendKey,
      },
    ) as Map;
    return SubscriptionPriceQuote.fromJson(Map<String, dynamic>.from(raw));
  }

  static Future<DiwaniyaSubscriptionServerStatus> fetchStatus(
    String diwaniyaId,
  ) async {
    final raw = await ApiClient.get(
      Endpoints.diwaniyaSubscriptionStatus(diwaniyaId),
    ) as Map;
    return DiwaniyaSubscriptionServerStatus.fromJson(
      Map<String, dynamic>.from(raw),
    );
  }

  static Future<SubscriptionPurchaseIntentResult> createPurchaseIntent({
    required String diwaniyaId,
    required int memberLimit,
    required SubscriptionDurationChoice duration,
    required bool recordAsSharedExpense,
    required bool autoRecordRenewalsAsSharedExpense,
    String? originAction,
    String? resumableActionToken,
  }) async {
    final raw = await ApiClient.post(
      Endpoints.diwaniyaSubscriptionPurchaseIntents(diwaniyaId),
      body: {
        'member_limit': memberLimit,
        'duration': duration.backendKey,
        'record_as_shared_expense': recordAsSharedExpense,
        'auto_record_renewals_as_shared_expense':
            autoRecordRenewalsAsSharedExpense,
        if (originAction != null) 'origin_action': originAction,
        if (resumableActionToken != null)
          'resumable_action_token': resumableActionToken,
      },
    ) as Map;
    return SubscriptionPurchaseIntentResult.fromJson(
      Map<String, dynamic>.from(raw),
    );
  }
}

SubscriptionDurationChoice _durationFromBackend(Object? value) {
  return value == 'annual'
      ? SubscriptionDurationChoice.annual
      : SubscriptionDurationChoice.threeMonths;
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

int? _asNullableInt(Object? value) {
  if (value == null) return null;
  return _asInt(value);
}

double _asDouble(Object? value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}
