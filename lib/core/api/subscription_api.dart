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
  final String billingMode;
  final List<StoreProductMapping> storeProducts;
  final List<String> notes;

  const SubscriptionCatalog({
    required this.tiers,
    required this.defaultMemberLimit,
    required this.defaultDuration,
    required this.pricePerMemberMonthSar,
    required this.yearlyDiscountPercent,
    required this.autoRenewDefault,
    required this.billingMode,
    required this.storeProducts,
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
    final rawProducts = json['store_products'];
    return SubscriptionCatalog(
      tiers: tiers,
      defaultMemberLimit: _asInt(json['default_member_limit'], fallback: 10),
      defaultDuration: _durationFromBackend(json['default_duration']),
      pricePerMemberMonthSar: _asDouble(json['price_per_member_month_sar']),
      yearlyDiscountPercent: _asInt(json['yearly_discount_percent']),
      autoRenewDefault: json['auto_renew_default'] != false,
      billingMode: (json['billing_mode'] ?? 'disabled').toString(),
      storeProducts: rawProducts is List
          ? rawProducts
              .whereType<Map>()
              .map((item) => StoreProductMapping.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList(growable: false)
          : const <StoreProductMapping>[],
      notes: rawNotes is List
          ? rawNotes.map((item) => item.toString()).toList(growable: false)
          : const <String>[],
    );
  }
}

class StoreProductMapping {
  final String provider;
  final String productId;
  final int memberLimit;
  final SubscriptionDurationChoice duration;
  final int durationMonths;
  final String displayLabel;
  final bool active;

  const StoreProductMapping({
    required this.provider,
    required this.productId,
    required this.memberLimit,
    required this.duration,
    required this.durationMonths,
    required this.displayLabel,
    required this.active,
  });

  factory StoreProductMapping.fromJson(Map<String, dynamic> json) {
    return StoreProductMapping(
      provider: (json['provider'] ?? '').toString(),
      productId: (json['product_id'] ?? '').toString(),
      memberLimit: _asInt(json['member_limit']),
      duration: _durationFromBackend(json['duration']),
      durationMonths: _asInt(json['duration_months']),
      displayLabel: (json['display_label'] ?? '').toString(),
      active: json['active'] == true,
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
  final String? storeProvider;
  final String? storeProductId;
  final String? storeVerificationStatus;
  final DateTime? storeExpiresAt;
  final DateTime? storeLastVerifiedAt;
  final String? storeLastNotificationType;

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
    required this.storeProvider,
    required this.storeProductId,
    required this.storeVerificationStatus,
    required this.storeExpiresAt,
    required this.storeLastVerifiedAt,
    required this.storeLastNotificationType,
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
      storeProvider: json['store_provider']?.toString(),
      storeProductId: json['store_product_id']?.toString(),
      storeVerificationStatus: json['store_verification_status']?.toString(),
      storeExpiresAt: _asDateTime(json['store_expires_at']),
      storeLastVerifiedAt: _asDateTime(json['store_last_verified_at']),
      storeLastNotificationType:
          json['store_last_notification_type']?.toString(),
    );
  }
}

class SubscriptionPurchaseIntentResult {
  final String status;
  final String provider;
  final String messageAr;
  final SubscriptionPriceQuote preview;
  final List<StoreProductMapping> storeProducts;

  const SubscriptionPurchaseIntentResult({
    required this.status,
    required this.provider,
    required this.messageAr,
    required this.preview,
    required this.storeProducts,
  });

  factory SubscriptionPurchaseIntentResult.fromJson(Map<String, dynamic> json) {
    return SubscriptionPurchaseIntentResult(
      status: (json['status'] ?? '').toString(),
      provider: (json['provider'] ?? '').toString(),
      messageAr: (json['message_ar'] ?? '').toString(),
      preview: SubscriptionPriceQuote.fromJson(
        Map<String, dynamic>.from(json['preview'] as Map),
      ),
      storeProducts: json['store_products'] is List
          ? (json['store_products'] as List)
              .whereType<Map>()
              .map((item) => StoreProductMapping.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList(growable: false)
          : const <StoreProductMapping>[],
    );
  }
}

class StoreVerificationResult {
  final String status;
  final String messageAr;
  final DiwaniyaSubscriptionServerStatus subscription;
  final String? transactionStatus;
  final String? resumableActionStatus;

  const StoreVerificationResult({
    required this.status,
    required this.messageAr,
    required this.subscription,
    required this.transactionStatus,
    required this.resumableActionStatus,
  });

  factory StoreVerificationResult.fromJson(Map<String, dynamic> json) {
    return StoreVerificationResult(
      status: (json['status'] ?? '').toString(),
      messageAr: (json['message_ar'] ?? '').toString(),
      subscription: DiwaniyaSubscriptionServerStatus.fromJson(
        Map<String, dynamic>.from(json['subscription'] as Map),
      ),
      transactionStatus: json['transaction_status']?.toString(),
      resumableActionStatus: json['resumable_action_status']?.toString(),
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

  static Future<StoreVerificationResult> verifyStorePurchase({
    required String diwaniyaId,
    required String provider,
    required String productId,
    required String? purchaseToken,
    required String? transactionId,
    required String? originalTransactionId,
    required String? signedTransaction,
    required String environment,
    required String? pendingActionToken,
    required bool recordAsSharedExpense,
    required bool autoRecordRenewalsAsSharedExpense,
  }) async {
    final raw = await ApiClient.post(
      Endpoints.diwaniyaSubscriptionVerifyStorePurchase(diwaniyaId),
      body: {
        'provider': provider,
        'product_id': productId,
        'environment': environment,
        if (purchaseToken != null) 'purchase_token': purchaseToken,
        if (transactionId != null) 'transaction_id': transactionId,
        if (originalTransactionId != null)
          'original_transaction_id': originalTransactionId,
        if (signedTransaction != null) 'signed_transaction': signedTransaction,
        if (pendingActionToken != null)
          'pending_action_token': pendingActionToken,
        'record_as_shared_expense': recordAsSharedExpense,
        'auto_record_renewals_as_shared_expense':
            autoRecordRenewalsAsSharedExpense,
      },
    ) as Map;
    return StoreVerificationResult.fromJson(Map<String, dynamic>.from(raw));
  }

  static Future<StoreVerificationResult> restorePurchase({
    required String diwaniyaId,
    required String provider,
    required String productId,
    required String? purchaseToken,
    required String? transactionId,
    required String? originalTransactionId,
    required String? signedTransaction,
    required String environment,
  }) async {
    final raw = await ApiClient.post(
      Endpoints.diwaniyaSubscriptionRestore(diwaniyaId),
      body: {
        'provider': provider,
        'product_id': productId,
        'environment': environment,
        if (purchaseToken != null) 'purchase_token': purchaseToken,
        if (transactionId != null) 'transaction_id': transactionId,
        if (originalTransactionId != null)
          'original_transaction_id': originalTransactionId,
        if (signedTransaction != null) 'signed_transaction': signedTransaction,
      },
    ) as Map;
    return StoreVerificationResult.fromJson(Map<String, dynamic>.from(raw));
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

DateTime? _asDateTime(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
