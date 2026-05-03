enum SubscriptionPlan {
  free,
  monthly,
  yearly,
  joined,
}

extension SubscriptionPlanX on SubscriptionPlan {
  String get storageValue {
    switch (this) {
      case SubscriptionPlan.free:
        return 'free';
      case SubscriptionPlan.monthly:
        return 'monthly';
      case SubscriptionPlan.yearly:
        return 'yearly';
      case SubscriptionPlan.joined:
        return 'joined';
    }
  }

  static SubscriptionPlan fromStorageValue(String? value) {
    switch (value) {
      case 'free':
        return SubscriptionPlan.free;
      case 'monthly':
        return SubscriptionPlan.monthly;
      case 'yearly':
        return SubscriptionPlan.yearly;
      case 'joined':
      default:
        return SubscriptionPlan.joined;
    }
  }
}

class SubscriptionStatus {
  final SubscriptionPlan plan;
  final bool isCreator;
  final DateTime? billingStartsAt;
  final int amountSar;
  final bool active;
  final String? diwaniyaId;

  const SubscriptionStatus({
    required this.plan,
    required this.isCreator,
    required this.amountSar,
    required this.active,
    this.billingStartsAt,
    this.diwaniyaId,
  });

  Map<String, dynamic> toJson() {
    return {
      'plan': plan.storageValue,
      'isCreator': isCreator,
      'billingStartsAt': billingStartsAt?.toIso8601String(),
      'amountSar': amountSar,
      'active': active,
      if (diwaniyaId != null) 'diwaniyaId': diwaniyaId,
    };
  }

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      plan: SubscriptionPlanX.fromStorageValue(json['plan'] as String?),
      isCreator: json['isCreator'] == true,
      billingStartsAt: json['billingStartsAt'] != null
          ? DateTime.parse(json['billingStartsAt'] as String)
          : null,
      amountSar: (json['amountSar'] as num?)?.toInt() ?? 0,
      active: json['active'] != false,
      diwaniyaId: json['diwaniyaId'] as String?,
    );
  }
}
