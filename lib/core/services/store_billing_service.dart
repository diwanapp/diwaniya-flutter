import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class StorePurchasePayload {
  final String provider;
  final String productId;
  final String? purchaseToken;
  final String? transactionId;
  final String? originalTransactionId;
  final String? signedTransaction;
  final String environment;

  const StorePurchasePayload({
    required this.provider,
    required this.productId,
    required this.purchaseToken,
    required this.transactionId,
    required this.originalTransactionId,
    required this.signedTransaction,
    required this.environment,
  });
}

class StoreBillingQueryResult {
  final bool available;
  final Map<String, ProductDetails> productsById;
  final Set<String> notFoundIds;
  final String? messageAr;

  const StoreBillingQueryResult({
    required this.available,
    required this.productsById,
    required this.notFoundIds,
    required this.messageAr,
  });
}

class StoreBillingService {
  StoreBillingService._();

  static final InAppPurchase _iap = InAppPurchase.instance;

  static Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  static Future<StoreBillingQueryResult> queryProducts(Set<String> ids) async {
    if (ids.isEmpty) {
      return const StoreBillingQueryResult(
        available: false,
        productsById: <String, ProductDetails>{},
        notFoundIds: <String>{},
        messageAr: 'الاشتراكات غير متاحة مؤقتا. حاول لاحقا.',
      );
    }
    final available = await _iap.isAvailable();
    if (!available) {
      return const StoreBillingQueryResult(
        available: false,
        productsById: <String, ProductDetails>{},
        notFoundIds: <String>{},
        messageAr: 'الاشتراكات غير متاحة مؤقتا. حاول لاحقا.',
      );
    }
    final response = await _iap.queryProductDetails(ids);
    if (response.error != null) {
      return const StoreBillingQueryResult(
        available: false,
        productsById: <String, ProductDetails>{},
        notFoundIds: <String>{},
        messageAr: 'تعذر تحميل منتجات الاشتراك من المتجر.',
      );
    }
    return StoreBillingQueryResult(
      available: true,
      productsById: {
        for (final product in response.productDetails) product.id: product,
      },
      notFoundIds: response.notFoundIDs.toSet(),
      messageAr: response.notFoundIDs.isEmpty
          ? null
          : 'بعض منتجات الاشتراك غير مفعلة في المتجر.',
    );
  }

  static Future<void> buySubscription(ProductDetails product) async {
    final param = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  static Future<void> restorePurchases() {
    return _iap.restorePurchases();
  }

  static Future<void> completeIfNeeded(PurchaseDetails purchase) async {
    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }
  }

  static StorePurchasePayload payloadFor(PurchaseDetails purchase) {
    final verification = purchase.verificationData;
    final provider = providerForCurrentPlatform();
    final token = verification.serverVerificationData.trim();
    final purchaseId = purchase.purchaseID?.trim();
    return StorePurchasePayload(
      provider: provider,
      productId: purchase.productID,
      purchaseToken: token.isEmpty ? null : token,
      transactionId: purchaseId == null || purchaseId.isEmpty ? null : purchaseId,
      originalTransactionId:
          purchaseId == null || purchaseId.isEmpty ? null : purchaseId,
      signedTransaction: provider == 'apple' && token.isNotEmpty ? token : null,
      environment: 'unknown',
    );
  }

  static String providerForCurrentPlatform() {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return 'apple';
    }
    return 'google';
  }
}
