import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../config/theme/app_colors.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/subscription_api.dart';
import '../../core/models/mock_data.dart';
import '../../core/services/store_billing_service.dart';
import '../../l10n/ar.dart';

class PlanSelectionScreen extends StatefulWidget {
  final String? trigger;
  final String? resumableActionToken;

  const PlanSelectionScreen({
    super.key,
    this.trigger,
    this.resumableActionToken,
  });

  @override
  State<PlanSelectionScreen> createState() => _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends State<PlanSelectionScreen> {
  SubscriptionCatalog? _catalog;
  DiwaniyaSubscriptionServerStatus? _status;
  SubscriptionPriceQuote? _quote;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  Map<String, ProductDetails> _storeProductsById =
      const <String, ProductDetails>{};

  var _selectedMemberLimit = 10;
  var _selectedDuration = SubscriptionDurationChoice.threeMonths;
  var _loading = true;
  var _quoteLoading = false;
  var _submitting = false;
  var _verifyingPurchase = false;
  var _storeAvailable = false;
  String? _error;
  String? _storeMessage;

  String get _paymentLabel {
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'App Store';
    return 'Google Play';
  }

  @override
  void initState() {
    super.initState();
    _purchaseSubscription = StoreBillingService.purchaseStream.listen(
      (purchases) => unawaited(_handlePurchaseUpdates(purchases)),
      onError: (_) {
        if (!mounted) return;
        _showSnack('تعذر متابعة عملية الدفع من المتجر. حاول مرة أخرى.');
      },
    );
    _load();
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = await SubscriptionApi.fetchCatalog();
      if (catalog.tiers.isEmpty) {
        throw StateError('empty_subscription_catalog');
      }

      DiwaniyaSubscriptionServerStatus? status;
      if (currentDiwaniyaId.trim().isNotEmpty) {
        status = await SubscriptionApi.fetchStatus(currentDiwaniyaId);
      }

      final memberCount = status?.memberCount ?? _localMemberCount(_currentDiwaniya());
      final minimum = _minimumTierForTrigger(
        catalog.tiers,
        status: status,
        memberCount: memberCount,
        trigger: widget.trigger,
      );
      final recommended = _recommendedTier(
        catalog.tiers,
        memberCount,
      );
      final selectedTier = _higherTier(recommended, minimum);

      setState(() {
        _catalog = catalog;
        _status = status;
        _selectedMemberLimit =
            selectedTier?.memberLimit ?? catalog.defaultMemberLimit;
        _selectedDuration = catalog.defaultDuration;
      });
      await _loadStoreProducts(catalog);
      await _loadQuote();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _messageForError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadStoreProducts(SubscriptionCatalog catalog) async {
    final provider = StoreBillingService.providerForCurrentPlatform();
    final productIds = catalog.storeProducts
        .where((product) => product.provider == provider && product.active)
        .map((product) => product.productId)
        .where((id) => id.trim().isNotEmpty)
        .toSet();
    final result = await StoreBillingService.queryProducts(productIds);
    if (!mounted) return;
    setState(() {
      _storeAvailable = result.available && result.productsById.isNotEmpty;
      _storeProductsById = result.productsById;
      _storeMessage = result.messageAr;
    });
  }

  Future<void> _loadQuote() async {
    setState(() {
      _quoteLoading = true;
      _error = null;
    });
    try {
      final quote = await SubscriptionApi.previewPrice(
        memberLimit: _selectedMemberLimit,
        duration: _selectedDuration,
      );
      if (!mounted) return;
      setState(() => _quote = quote);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _messageForError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _quoteLoading = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_submitting ||
        _verifyingPurchase ||
        currentDiwaniyaId.trim().isEmpty) {
      return;
    }
    final product = _selectedProductDetails();
    if (!_storeAvailable || product == null) {
      _showSnack(
        _storeMessage ??
            'الاشتراكات غير متاحة مؤقتًا. حاول لاحقًا.',
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await SubscriptionApi.createPurchaseIntent(
        diwaniyaId: currentDiwaniyaId,
        memberLimit: _selectedMemberLimit,
        duration: _selectedDuration,
        originAction: _originActionForTrigger(widget.trigger),
        resumableActionToken: widget.resumableActionToken,
        recordAsSharedExpense: false,
        autoRecordRenewalsAsSharedExpense: false,
      );
      if (!mounted) return;
      await StoreBillingService.buySubscription(product);
    } catch (error) {
      if (!mounted) return;
      _showSnack(_messageForError(error));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _restorePurchases() async {
    if (_submitting || _verifyingPurchase) return;
    setState(() => _submitting = true);
    try {
      await StoreBillingService.restorePurchases();
      if (!mounted) return;
      _showSnack('جاري البحث عن عمليات شراء قابلة للاستعادة.');
    } catch (_) {
      if (!mounted) return;
      _showSnack('تعذر بدء استعادة الاشتراك. حاول لاحقا.');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (!_productKnownToCatalog(purchase.productID)) continue;
      if (purchase.status == PurchaseStatus.pending) {
        _showSnack('عملية الدفع قيد المعالجة.');
        continue;
      }
      if (purchase.status == PurchaseStatus.error) {
        _showSnack('تعذر إتمام الدفع من المتجر.');
        await StoreBillingService.completeIfNeeded(purchase);
        continue;
      }
      if (purchase.status == PurchaseStatus.canceled) {
        _showSnack('تم إلغاء عملية الدفع.');
        await StoreBillingService.completeIfNeeded(purchase);
        continue;
      }
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _verifyPurchase(
          purchase,
          restore: purchase.status == PurchaseStatus.restored,
        );
      }
    }
  }

  Future<void> _verifyPurchase(
    PurchaseDetails purchase, {
    required bool restore,
  }) async {
    if (_verifyingPurchase || currentDiwaniyaId.trim().isEmpty) return;
    setState(() => _verifyingPurchase = true);
    try {
      final payload = StoreBillingService.payloadFor(purchase);
      final result = restore
          ? await SubscriptionApi.restorePurchase(
              diwaniyaId: currentDiwaniyaId,
              provider: payload.provider,
              productId: payload.productId,
              purchaseToken: payload.purchaseToken,
              transactionId: payload.transactionId,
              originalTransactionId: payload.originalTransactionId,
              signedTransaction: payload.signedTransaction,
              environment: payload.environment,
            )
          : await SubscriptionApi.verifyStorePurchase(
              diwaniyaId: currentDiwaniyaId,
              provider: payload.provider,
              productId: payload.productId,
              purchaseToken: payload.purchaseToken,
              transactionId: payload.transactionId,
              originalTransactionId: payload.originalTransactionId,
              signedTransaction: payload.signedTransaction,
              environment: payload.environment,
              pendingActionToken: widget.resumableActionToken,
              recordAsSharedExpense: false,
              autoRecordRenewalsAsSharedExpense: false,
            );
      if (!mounted) return;
      setState(() => _status = result.subscription);
      _showSnack(
        result.messageAr.isEmpty
            ? 'تم التحقق من الاشتراك.'
            : result.messageAr,
      );
      if (!restore && _isVerifiedStorePayment(result)) {
        await StoreBillingService.completeIfNeeded(purchase);
        if (!mounted) return;
        await _showSharedExpensePrompt(payload);
      }
    } catch (error) {
      if (!mounted) return;
      _showSnack(_messageForError(error));
    } finally {
      await StoreBillingService.completeIfNeeded(purchase);
      if (mounted) {
        setState(() => _verifyingPurchase = false);
      }
    }
  }

  bool _isVerifiedStorePayment(StoreVerificationResult result) {
    return result.status == 'verified' ||
        result.transactionStatus == 'active' ||
        result.transactionStatus == 'grace_period' ||
        result.transactionStatus == 'billing_retry';
  }

  Future<void> _showSharedExpensePrompt(StorePurchasePayload payload) async {
    if (!mounted) return;
    var autoRecordRenewals = false;
    var recording = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final c = sheetContext.cl;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return SafeArea(
                top: false,
                child: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: c.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: c.successM,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.verified_rounded,
                              color: c.success,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'تم تفعيل الاشتراك',
                              style: TextStyle(
                                color: c.t1,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'هل ترغب بتسجيل الاشتراك كمصروف مشترك على الأعضاء؟',
                        style: TextStyle(
                          color: c.t2,
                          height: 1.65,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 10),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: autoRecordRenewals,
                        onChanged: recording
                            ? null
                            : (value) {
                                setSheetState(() {
                                  autoRecordRenewals = value ?? false;
                                });
                              },
                        activeColor: c.accent,
                        title: Text(
                          'اجعلها تلقائية للتجديدات القادمة',
                          style: TextStyle(
                            color: c.t1,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: recording
                              ? null
                              : () async {
                                  setSheetState(() => recording = true);
                                  final ok =
                                      await _recordSharedExpenseFromPurchase(
                                    payload,
                                    autoRecordRenewals: autoRecordRenewals,
                                  );
                                  if (!sheetContext.mounted) return;
                                  Navigator.of(sheetContext).pop();
                                  _showSnack(
                                    ok
                                        ? 'تم تسجيل الاشتراك كمصروف مشترك.'
                                        : 'تعذر تسجيل المصروف الآن. الاشتراك مفعل ويمكنك المحاولة لاحقًا.',
                                  );
                                },
                          child: Text(
                            recording
                                ? Ar.loading
                                : 'قسّم المصروف على الأعضاء',
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: recording
                            ? null
                            : () => Navigator.of(sheetContext).pop(),
                        child: const Text('لاحقًا'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<bool> _recordSharedExpenseFromPurchase(
    StorePurchasePayload payload, {
    required bool autoRecordRenewals,
  }) async {
    try {
      final result = await SubscriptionApi.verifyStorePurchase(
        diwaniyaId: currentDiwaniyaId,
        provider: payload.provider,
        productId: payload.productId,
        purchaseToken: payload.purchaseToken,
        transactionId: payload.transactionId,
        originalTransactionId: payload.originalTransactionId,
        signedTransaction: payload.signedTransaction,
        environment: payload.environment,
        pendingActionToken: null,
        recordAsSharedExpense: true,
        autoRecordRenewalsAsSharedExpense: autoRecordRenewals,
      );
      if (mounted) {
        setState(() => _status = result.subscription);
      }
      return _isVerifiedStorePayment(result);
    } catch (_) {
      return false;
    }
  }

  StoreProductMapping? _selectedStoreProduct() {
    final catalog = _catalog;
    if (catalog == null) return null;
    final provider = StoreBillingService.providerForCurrentPlatform();
    for (final product in catalog.storeProducts) {
      if (product.provider == provider &&
          product.active &&
          product.memberLimit == _selectedMemberLimit &&
          product.duration == _selectedDuration) {
        return product;
      }
    }
    return null;
  }

  ProductDetails? _selectedProductDetails() {
    final mapping = _selectedStoreProduct();
    if (mapping == null) return null;
    return _storeProductsById[mapping.productId];
  }

  bool _productKnownToCatalog(String productId) {
    final catalog = _catalog;
    if (catalog == null) return false;
    final provider = StoreBillingService.providerForCurrentPlatform();
    return catalog.storeProducts.any(
      (product) =>
          product.provider == provider &&
          product.productId == productId &&
          product.active,
    );
  }

  bool get _canStartStorePurchase {
    return _quote != null &&
        !_quoteLoading &&
        !_submitting &&
        !_verifyingPurchase &&
        currentDiwaniyaId.trim().isNotEmpty &&
        _storeAvailable &&
        _selectedProductDetails() != null;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final catalog = _catalog;
    final quote = _quote;
    final diwaniya = _currentDiwaniya();
    final minimumTier = catalog == null
        ? null
        : _minimumTierForTrigger(
            catalog.tiers,
            status: _status,
            memberCount: _status?.memberCount ?? _localMemberCount(diwaniya),
            trigger: widget.trigger,
          );
    final minimumMemberLimit = minimumTier?.memberLimit;
    final storeUnavailable =
        !_storeAvailable || _selectedProductDetails() == null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.bg,
          elevation: 0,
          leading: BackButton(color: c.t1),
          title: Text(
            'اشتراك الديوانية',
            style: TextStyle(
              color: c.t1,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: SafeArea(
          child: _loading && catalog == null
              ? Center(
                  child: CircularProgressIndicator(color: c.accent),
                )
              : catalog == null
                  ? _ErrorState(message: _error, onRetry: _load)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        _HeroCard(
                          contextLine: _contextualLineForTrigger(widget.trigger),
                        ),
                        const SizedBox(height: 14),
                        _SelectedTierLine(
                          memberLimit: _selectedMemberLimit,
                          monthlyAmountSar: _monthlyAmountForTier(
                            _selectedMemberLimit,
                            catalog.pricePerMemberMonthSar,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _PlanPickerCard(
                          tiers: catalog.tiers,
                          selectedMemberLimit: _selectedMemberLimit,
                          selectedDuration: _selectedDuration,
                          minimumMemberLimit: minimumMemberLimit,
                          yearlyDiscountPercent:
                              catalog.yearlyDiscountPercent,
                          onTierChanged: (value) {
                            setState(() => _selectedMemberLimit = value);
                            _loadQuote();
                          },
                          onDurationChanged: (value) {
                            setState(() => _selectedDuration = value);
                            _loadQuote();
                          },
                        ),
                        const SizedBox(height: 12),
                        _PriceSummaryCard(
                          quote: quote,
                          loading: _quoteLoading,
                          yearlyDiscountPercent:
                              catalog.yearlyDiscountPercent,
                        ),
                        const SizedBox(height: 12),
                        const _BenefitRow(),
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          _InlineNotice(message: _error!, color: c.error),
                        ],
                        if (storeUnavailable) ...[
                          const SizedBox(height: 10),
                          _StoreUnavailableNotice(
                            message: _storeUnavailableMessage(_storeMessage),
                          ),
                        ],
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _canStartStorePurchase ? _submit : null,
                            child: Text(
                              _submitting || _verifyingPurchase
                                  ? Ar.loading
                                  : _ctaLabelForTrigger(
                                      widget.trigger,
                                      _paymentLabel,
                                    ),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _submitting || _verifyingPurchase
                              ? null
                              : _restorePurchases,
                          child: const Text('استعادة الاشتراك'),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'يتجدد تلقائيًا ما لم يتم إيقاف التجديد من المتجر.\nلن يتم تفعيل الاشتراك إلا بعد التحقق من الدفع.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: c.t3.withValues(alpha: 0.76),
                            height: 1.75,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String? contextLine;

  const _HeroCard({
    required this.contextLine,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.majlisBlue,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.sandTaupeLight.withValues(alpha: 0.24),
        ),
        boxShadow: [
          BoxShadow(
            color: c.isDark
                ? Colors.transparent
                : AppColors.majlisBlue.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.sandTaupeLight.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: AppColors.sandGold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'وسّع مزايا ديوانيتكم',
                  style: TextStyle(
                    color: AppColors.warmIvory.withValues(alpha: 0.86),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'بس بـ 1 ر.س للعضو شهريًا',
            style: TextStyle(
              color: AppColors.warmIvory,
              fontSize: 27,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'كلكم باشتراك واحد للديوانية',
            style: TextStyle(
              color: AppColors.ivoryMuted.withValues(alpha: 0.82),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          if (contextLine != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Text(
                contextLine!,
                style: TextStyle(
                  color: AppColors.ivoryMuted.withValues(alpha: 0.84),
                  fontSize: 12.5,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectedTierLine extends StatelessWidget {
  final int memberLimit;
  final double monthlyAmountSar;

  const _SelectedTierLine({
    required this.memberLimit,
    required this.monthlyAmountSar,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.accentSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.groups_rounded, color: c.accent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_membersLabel(memberLimit)} = ${_formatSar(monthlyAmountSar)} ر.س / شهر',
              style: TextStyle(
                color: c.t1,
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanPickerCard extends StatelessWidget {
  final List<SubscriptionTierOption> tiers;
  final int selectedMemberLimit;
  final SubscriptionDurationChoice selectedDuration;
  final int? minimumMemberLimit;
  final int yearlyDiscountPercent;
  final ValueChanged<int> onTierChanged;
  final ValueChanged<SubscriptionDurationChoice> onDurationChanged;

  const _PlanPickerCard({
    required this.tiers,
    required this.selectedMemberLimit,
    required this.selectedDuration,
    required this.minimumMemberLimit,
    required this.yearlyDiscountPercent,
    required this.onTierChanged,
    required this.onDurationChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'اختر عدد الأعضاء',
            subtitle: 'كل خيار يحدد حد الأعضاء للديوانية كلها.',
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 6.0;
              final chipWidth =
                  ((constraints.maxWidth - (gap * 4)) / 5).clamp(48.0, 54.0);
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final tier in tiers) ...[
                    _MemberTierChip(
                      label: _tierChipLabel(tier.memberLimit),
                      width: chipWidth,
                      selected: tier.memberLimit == selectedMemberLimit,
                      disabled: minimumMemberLimit != null &&
                          tier.memberLimit < minimumMemberLimit!,
                      onTap: () => onTierChanged(tier.memberLimit),
                    ),
                    if (tier != tiers.last) const SizedBox(width: gap),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _DurationButton(
                  label: '3 أشهر',
                  selected:
                      selectedDuration == SubscriptionDurationChoice.threeMonths,
                  onTap: () => onDurationChanged(
                    SubscriptionDurationChoice.threeMonths,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DurationButton(
                  label: 'سنة — وفر $yearlyDiscountPercent%',
                  badge: 'الأفضل',
                  selected: selectedDuration == SubscriptionDurationChoice.annual,
                  onTap: () => onDurationChanged(
                    SubscriptionDurationChoice.annual,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriceSummaryCard extends StatelessWidget {
  final SubscriptionPriceQuote? quote;
  final bool loading;
  final int yearlyDiscountPercent;

  const _PriceSummaryCard({
    required this.quote,
    required this.loading,
    required this.yearlyDiscountPercent,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final currentQuote = quote;
    final isAnnual = currentQuote?.duration == SubscriptionDurationChoice.annual;
    final monthlyEquivalent = currentQuote == null
        ? 0.0
        : currentQuote.durationMonths <= 0
            ? currentQuote.amountSar
            : currentQuote.amountSar / currentQuote.durationMonths;
    return _Surface(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: currentQuote == null
            ? Row(
                key: const ValueKey('price-loading'),
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: loading
                        ? CircularProgressIndicator(
                            strokeWidth: 2,
                            color: c.accent,
                          )
                        : Icon(Icons.payments_rounded, color: c.accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'اختر الباقة لعرض السعر.',
                      style: TextStyle(color: c.t2, height: 1.6),
                    ),
                  ),
                ],
              )
            : Column(
                key: ValueKey(
                  '${currentQuote.memberLimit}-${currentQuote.duration.backendKey}',
                ),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAnnual
                        ? '${_formatSar(currentQuote.amountSar)} ر.س سنويًا'
                        : '${_formatSar(currentQuote.amountSar)} ر.س',
                    style: TextStyle(
                      color: c.t1,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      height: 1.08,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAnnual
                        ? 'بدل ${_formatSar(currentQuote.subtotalSar)} ر.س'
                        : 'كل ${currentQuote.durationMonths} أشهر',
                    style: TextStyle(
                      color: c.t2,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAnnual
                        ? 'توفير $yearlyDiscountPercent%'
                        : 'يعادل ${_formatSar(monthlyEquivalent)} ر.س شهريًا',
                    style: TextStyle(
                      color: isAnnual ? c.success : c.t3,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _BenefitChip(label: 'أعضاء أكثر'),
        _BenefitChip(label: 'صور أكثر', icon: Icons.image_rounded),
        _BenefitChip(label: 'تصويتات أكثر', icon: Icons.how_to_vote_rounded),
        _BenefitChip(label: 'ملفات أكبر', icon: Icons.attach_file_rounded),
      ],
    );
  }
}

class _BenefitChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _BenefitChip({
    required this.label,
    this.icon = Icons.groups_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: c.inputBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c.t3),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: c.t2,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreUnavailableNotice extends StatelessWidget {
  final String message;

  const _StoreUnavailableNotice({required this.message});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Text(
      message,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: c.t3,
        height: 1.5,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _MemberTierChip extends StatelessWidget {
  final String label;
  final double width;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  const _MemberTierChip({
    required this.label,
    required this.width,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final bg = selected
        ? c.accent
        : disabled
            ? c.inputBg.withValues(alpha: 0.55)
            : AppColors.majlisBlue;
    final fg = selected
        ? c.tInverse
        : disabled
            ? c.t3
            : AppColors.warmIvory;
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: width,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? c.accent
                : disabled
                    ? c.border
                    : AppColors.sandTaupeLight.withValues(alpha: 0.16),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w900,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}

class _DurationButton extends StatelessWidget {
  final String label;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  const _DurationButton({
    required this.label,
    this.badge,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.accent : c.inputBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? c.accent : c.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? c.tInverse : c.t1,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(height: 1),
              Text(
                badge!,
                style: TextStyle(
                  color: selected
                      ? c.tInverse.withValues(alpha: 0.78)
                      : c.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  final Widget child;

  const _Surface({required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.border),
        boxShadow: [BoxShadow(color: c.shadow, blurRadius: 12)],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: c.t1,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: c.t3, height: 1.45, fontSize: 12.5),
        ),
      ],
    );
  }
}

class _InlineNotice extends StatelessWidget {
  final String message;
  final Color color;

  const _InlineNotice({
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: c.isDark ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: TextStyle(color: c.t2, height: 1.55, fontSize: 12.5),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, color: c.warning, size: 44),
          const SizedBox(height: 12),
          Text(
            'تعذر تحميل الاشتراكات',
            style: TextStyle(
              color: c.t1,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message ?? 'تحقق من الاتصال ثم حاول مرة أخرى.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.t2, height: 1.6),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRetry,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}

DiwaniyaInfo? _currentDiwaniya() {
  for (final diwaniya in allDiwaniyas) {
    if (diwaniya.id == currentDiwaniyaId) return diwaniya;
  }
  return null;
}

int? _localMemberCount(DiwaniyaInfo? diwaniya) {
  if (diwaniya == null) return null;
  final count = diwaniya.memberCount;
  if (count != null && count > 0) return count;
  final members = diwaniyaMembers[diwaniya.id];
  if (members != null && members.isNotEmpty) return members.length;
  return null;
}

SubscriptionTierOption? _recommendedTier(
  List<SubscriptionTierOption> tiers,
  int? memberCount,
) {
  if (tiers.isEmpty) return null;
  final requiredCount = memberCount == null ? 1 : memberCount.clamp(1, 999);
  for (final tier in tiers) {
    if (requiredCount <= tier.memberLimit) return tier;
  }
  return tiers.last;
}

SubscriptionTierOption? _minimumTierForTrigger(
  List<SubscriptionTierOption> tiers, {
  required DiwaniyaSubscriptionServerStatus? status,
  required int? memberCount,
  required String? trigger,
}) {
  if (tiers.isEmpty) return null;
  switch (trigger) {
    case 'memberLimit':
      final requiredCount = ((status?.memberCount ?? memberCount ?? 0) + 1)
          .clamp(1, 999);
      return _recommendedTier(tiers, requiredCount);
    case 'photoLimit':
    case 'pollLimit':
      final currentLimit = status?.memberLimit;
      if (currentLimit == null || currentLimit <= 0) {
        return _recommendedTier(tiers, memberCount);
      }
      for (final tier in tiers) {
        if (tier.memberLimit > currentLimit) return tier;
      }
      return tiers.last;
    default:
      return _recommendedTier(tiers, memberCount);
  }
}

SubscriptionTierOption? _higherTier(
  SubscriptionTierOption? first,
  SubscriptionTierOption? second,
) {
  if (first == null) return second;
  if (second == null) return first;
  return first.memberLimit >= second.memberLimit ? first : second;
}

double _monthlyAmountForTier(int memberLimit, double pricePerMemberMonthSar) {
  final unitPrice = pricePerMemberMonthSar <= 0 ? 1.0 : pricePerMemberMonthSar;
  return memberLimit * unitPrice;
}

String _membersLabel(int memberLimit) {
  if (memberLimit == 10) return '10 أعضاء';
  if (memberLimit >= 50) return '50+ عضوًا';
  return '$memberLimit عضوًا';
}

String _tierChipLabel(int memberLimit) {
  return memberLimit >= 50 ? '50+' : '$memberLimit';
}

String? _contextualLineForTrigger(String? trigger) {
  switch (trigger) {
    case 'memberLimit':
    case 'photoLimit':
    case 'pollLimit':
    case 'secondDiwaniya':
      return 'تحتاج الديوانية إلى ترقية لإكمال هذا الإجراء.';
    default:
      return null;
  }
}

String _ctaLabelForTrigger(String? trigger, String paymentLabel) {
  switch (trigger) {
    case 'memberLimit':
      return 'ترقية وقبول العضو';
    case 'photoLimit':
      return 'ترقية ورفع الصور';
    case 'pollLimit':
      return 'ترقية وإنشاء التصويت';
    case 'secondDiwaniya':
      return 'ترقية وإنشاء الديوانية';
    default:
      return 'المتابعة عبر $paymentLabel';
  }
}

String _storeUnavailableMessage(String? message) {
  const fallback = 'الاشتراكات غير متاحة مؤقتًا. حاول لاحقًا.';
  final clean = message?.trim();
  return clean == null || clean.isEmpty ? fallback : fallback;
}

String? _originActionForTrigger(String? trigger) {
  switch (trigger) {
    case 'memberLimit':
      return 'add_member';
    case 'photoLimit':
      return 'upload_photo';
    case 'pollLimit':
      return 'create_poll';
    case 'secondDiwaniya':
      return 'create_diwaniya';
    default:
      return null;
  }
}

String _messageForError(Object error) {
  if (error is ApiException && error.message.trim().isNotEmpty) {
    return error.message;
  }
  return 'تعذر إتمام الطلب. حاول مرة أخرى.';
}

String _formatSar(double amount) {
  if (amount == amount.roundToDouble()) {
    return amount.toStringAsFixed(0);
  }
  return amount.toStringAsFixed(2);
}
