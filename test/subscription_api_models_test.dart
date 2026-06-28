import 'package:diwaniya/core/api/subscription_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SubscriptionCatalog parses store products without entitlement truth', () {
    final catalog = SubscriptionCatalog.fromJson({
      'tiers': [
        {'member_limit': 10, 'display_label': '10 أعضاء'},
      ],
      'default_member_limit': 10,
      'default_duration': 'three_months',
      'price_per_member_month_sar': 3,
      'yearly_discount_percent': 20,
      'auto_renew_default': true,
      'billing_mode': 'sandbox',
      'store_products': [
        {
          'provider': 'apple',
          'product_id': 'diwaniya_10_3m',
          'member_limit': 10,
          'duration': 'three_months',
          'duration_months': 3,
          'display_label': 'ديوانية 10 أعضاء - 3 أشهر',
          'active': true,
        },
        {
          'provider': 'google',
          'product_id': 'diwaniya_10_yearly',
          'member_limit': 10,
          'duration': 'annual',
          'duration_months': 12,
          'display_label': 'ديوانية 10 أعضاء - سنة',
          'active': false,
        },
      ],
      'notes': ['store verification required'],
    });

    expect(catalog.billingMode, 'sandbox');
    expect(catalog.storeProducts, hasLength(2));
    expect(catalog.storeProducts.first.provider, 'apple');
    expect(catalog.storeProducts.first.productId, 'diwaniya_10_3m');
    expect(
      catalog.storeProducts.first.duration,
      SubscriptionDurationChoice.threeMonths,
    );
    expect(catalog.storeProducts.first.active, isTrue);
    expect(catalog.storeProducts.last.duration, SubscriptionDurationChoice.annual);
    expect(catalog.storeProducts.last.active, isFalse);
  });

  test('StoreVerificationResult keeps backend status authoritative', () {
    final result = StoreVerificationResult.fromJson({
      'status': 'billing_unavailable',
      'message_ar': 'الاشتراكات غير متاحة مؤقتا. حاول لاحقا.',
      'transaction_status': null,
      'resumable_action_status': null,
      'subscription': {
        'diwaniya_id': 'd1',
        'effective_status': 'expired_free_fallback',
        'member_count': 7,
        'member_limit': 10,
        'photo_count': 0,
        'photo_limit': 20,
        'active_poll_count': 0,
        'active_poll_limit': 2,
        'auto_renew': false,
        'cancel_at_period_end': false,
        'shared_expense_auto_record': false,
      },
    });

    expect(result.status, 'billing_unavailable');
    expect(result.subscription.effectiveStatus, 'expired_free_fallback');
    expect(result.subscription.autoRenew, isFalse);
  });
}
