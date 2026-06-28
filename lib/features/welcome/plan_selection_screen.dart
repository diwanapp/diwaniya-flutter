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
  var _recordAsSharedExpense = false;
  var _recordRenewalsAsSharedExpense = false;
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

      final recommended = _recommendedTier(
        catalog.tiers,
        status?.memberCount ?? _localMemberCount(_currentDiwaniya()),
      );

      setState(() {
        _catalog = catalog;
        _status = status;
        _selectedMemberLimit =
            recommended?.memberLimit ?? catalog.defaultMemberLimit;
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
            'الاشتراكات غير متاحة مؤقتا. حاول لاحقا.',
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
        recordAsSharedExpense: _recordAsSharedExpense,
        autoRecordRenewalsAsSharedExpense: _recordRenewalsAsSharedExpense,
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
              recordAsSharedExpense: _recordAsSharedExpense,
              autoRecordRenewalsAsSharedExpense:
                  _recordRenewalsAsSharedExpense,
            );
      if (!mounted) return;
      setState(() => _status = result.subscription);
      _showSnack(
        result.messageAr.isEmpty
            ? 'تم التحقق من الاشتراك.'
            : result.messageAr,
      );
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
    final storeProduct = _selectedProductDetails();
    final diwaniya = _currentDiwaniya();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.bg,
          elevation: 0,
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
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                      children: [
                        _HeroCard(
                          title: _headlineForTrigger(widget.trigger),
                          subtitle:
                              'اشتراك واحد على مستوى الديوانية. السعر من الخادم حسب عدد الأعضاء والمدة، والتفعيل لا يتم إلا بعد تحقق المتجر.',
                        ),
                        const SizedBox(height: 12),
                        _CurrentStateCard(
                          diwaniyaName: diwaniya?.name ?? 'الديوانية الحالية',
                          city: diwaniya?.city,
                          status: _status,
                          localMemberCount: _localMemberCount(diwaniya),
                        ),
                        const SizedBox(height: 12),
                        _PlanPickerCard(
                          tiers: catalog.tiers,
                          selectedMemberLimit: _selectedMemberLimit,
                          selectedDuration: _selectedDuration,
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
                        _SharedExpenseCard(
                          recordAsSharedExpense: _recordAsSharedExpense,
                          recordRenewalsAsSharedExpense:
                              _recordRenewalsAsSharedExpense,
                          onRecordChanged: (value) {
                            setState(() {
                              _recordAsSharedExpense = value;
                              if (!value) {
                                _recordRenewalsAsSharedExpense = false;
                              }
                            });
                          },
                          onRenewalsChanged: _recordAsSharedExpense
                              ? (value) {
                                  setState(() {
                                    _recordRenewalsAsSharedExpense = value;
                                  });
                                }
                              : null,
                        ),
                        const SizedBox(height: 12),
                        _PriceSummaryCard(
                          quote: quote,
                          loading: _quoteLoading,
                          paymentLabel: _paymentLabel,
                          localizedStorePrice: storeProduct?.price,
                          storeMessage: _storeMessage,
                          storeAvailable: _storeAvailable,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          _InlineNotice(message: _error!, color: c.error),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _canStartStorePurchase ? _submit : null,
                            child: Text(
                              _submitting || _verifyingPurchase
                                  ? Ar.loading
                                  : 'المتابعة عبر $_paymentLabel',
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
                          'التجديد التلقائي مفعّل افتراضيا بعد تفعيل الاشتراك ويمكن إيقافه من إدارة الاشتراك. لن يمنح هذا الجهاز أي صلاحية مدفوعة قبل تأكيد الخادم للدفع.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: c.t3,
                            height: 1.7,
                            fontSize: 12,
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
  final String title;
  final String subtitle;

  const _HeroCard({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.accent.withValues(alpha: 0.18)),
        boxShadow: [BoxShadow(color: c.shadow, blurRadius: 16)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: c.accentMuted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.workspace_premium_rounded,
              color: c.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: c.t1,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: c.t2,
                    fontSize: 13.5,
                    height: 1.65,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentStateCard extends StatelessWidget {
  final String diwaniyaName;
  final String? city;
  final DiwaniyaSubscriptionServerStatus? status;
  final int? localMemberCount;

  const _CurrentStateCard({
    required this.diwaniyaName,
    required this.city,
    required this.status,
    required this.localMemberCount,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final serverStatus = status;
    final memberCount = serverStatus?.memberCount ?? localMemberCount;
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      diwaniyaName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.t1,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (city != null && city!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        city!,
                        style: TextStyle(color: c.t3, fontSize: 12.5),
                      ),
                    ],
                  ],
                ),
              ),
              _SoftPill(
                label: _statusLabel(serverStatus?.effectiveStatus),
                color: _statusColor(c, serverStatus?.effectiveStatus),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricPill(
                icon: Icons.group_rounded,
                label: memberCount == null
                    ? 'الأعضاء غير متاح'
                    : '$memberCount عضو',
              ),
              if (serverStatus != null)
                _MetricPill(
                  icon: Icons.photo_library_rounded,
                  label: '${serverStatus.photoCount}/${serverStatus.photoLimit} صور',
                ),
              if (serverStatus != null)
                _MetricPill(
                  icon: Icons.how_to_vote_rounded,
                  label:
                      '${serverStatus.activePollCount}/${serverStatus.activePollLimit} تصويت',
                ),
            ],
          ),
          if (serverStatus?.noticeAr?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            _InlineNotice(
              message: serverStatus!.noticeAr!,
              color: c.warning,
            ),
          ],
          if (serverStatus?.pendingMemberLimit != null) ...[
            const SizedBox(height: 10),
            _InlineNotice(
              message:
                  'يوجد تغيير مجدول عند التجديد القادم إلى ${serverStatus!.pendingMemberLimit} عضو.',
              color: c.info,
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanPickerCard extends StatelessWidget {
  final List<SubscriptionTierOption> tiers;
  final int selectedMemberLimit;
  final SubscriptionDurationChoice selectedDuration;
  final int yearlyDiscountPercent;
  final ValueChanged<int> onTierChanged;
  final ValueChanged<SubscriptionDurationChoice> onDurationChanged;

  const _PlanPickerCard({
    required this.tiers,
    required this.selectedMemberLimit,
    required this.selectedDuration,
    required this.yearlyDiscountPercent,
    required this.onTierChanged,
    required this.onDurationChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'اختر السعة والمدة',
            subtitle: 'يمكن الترقية لاحقا، أما التخفيض فيُجدول عند التجديد.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tier in tiers)
                ChoiceChip(
                  label: Text(tier.label),
                  selected: tier.memberLimit == selectedMemberLimit,
                  onSelected: (_) => onTierChanged(tier.memberLimit),
                  selectedColor: c.accent,
                  backgroundColor: c.inputBg,
                  labelStyle: TextStyle(
                    color: tier.memberLimit == selectedMemberLimit
                        ? c.tInverse
                        : c.t1,
                    fontWeight: FontWeight.w900,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: tier.memberLimit == selectedMemberLimit
                          ? c.accent
                          : c.border,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
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
                  label: 'سنة - وفر $yearlyDiscountPercent%',
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

class _SharedExpenseCard extends StatelessWidget {
  final bool recordAsSharedExpense;
  final bool recordRenewalsAsSharedExpense;
  final ValueChanged<bool> onRecordChanged;
  final ValueChanged<bool>? onRenewalsChanged;

  const _SharedExpenseCard({
    required this.recordAsSharedExpense,
    required this.recordRenewalsAsSharedExpense,
    required this.onRecordChanged,
    required this.onRenewalsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'المصروف المشترك',
            subtitle: 'اختياري، ولا يُنشأ المصروف إلا بعد تأكيد الدفع من الخادم.',
          ),
          const SizedBox(height: 6),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: recordAsSharedExpense,
            onChanged: (value) => onRecordChanged(value ?? false),
            activeColor: c.accent,
            title: Text(
              'تسجيل الاشتراك كمصروف على الأعضاء',
              style: TextStyle(color: c.t1, fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              'يحفظ إثبات الدفع بعد التأكيد بدلا من إنشاء مصروف وهمي.',
              style: TextStyle(color: c.t3, height: 1.45),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: recordAsSharedExpense
                ? CheckboxListTile(
                    key: const ValueKey('record-renewals'),
                    contentPadding: EdgeInsets.zero,
                    value: recordRenewalsAsSharedExpense,
                    onChanged: onRenewalsChanged == null
                        ? null
                        : (value) => onRenewalsChanged!(value ?? false),
                    activeColor: c.accent,
                    title: Text(
                      'تطبيق ذلك على التجديدات القادمة',
                      style: TextStyle(
                        color: c.t1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('no-renewals')),
          ),
        ],
      ),
    );
  }
}

class _PriceSummaryCard extends StatelessWidget {
  final SubscriptionPriceQuote? quote;
  final bool loading;
  final String paymentLabel;
  final String? localizedStorePrice;
  final String? storeMessage;
  final bool storeAvailable;

  const _PriceSummaryCard({
    required this.quote,
    required this.loading,
    required this.paymentLabel,
    required this.localizedStorePrice,
    required this.storeMessage,
    required this.storeAvailable,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final currentQuote = quote;
    return _Surface(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: c.accentMuted,
              borderRadius: BorderRadius.circular(15),
            ),
            child: loading
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: c.accent,
                    ),
                  )
                : Icon(Icons.payments_rounded, color: c.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: currentQuote == null
                ? Text(
                    'اختر الباقة لعرض السعر من الخادم.',
                    style: TextStyle(color: c.t2, height: 1.6),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentQuote.label.isNotEmpty
                            ? currentQuote.label
                            : '${_formatSar(currentQuote.amountSar)} ${Ar.sarCurrency}',
                        style: TextStyle(
                          color: c.t1,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'السعة ${currentQuote.memberLimit} عضو، والمدة ${currentQuote.durationMonths} أشهر. الدفع عبر $paymentLabel بعد التحقق.',
                        style: TextStyle(color: c.t2, height: 1.55),
                      ),
                      const SizedBox(height: 8),
                      _SoftPill(
                        label: storeAvailable && localizedStorePrice != null
                            ? 'سعر المتجر $localizedStorePrice'
                            : storeMessage ??
                                'الاشتراكات غير متاحة مؤقتا. حاول لاحقا.',
                        color: storeAvailable ? c.info : c.warning,
                      ),
                      if (currentQuote.savingsSar > 0) ...[
                        const SizedBox(height: 8),
                        _SoftPill(
                          label:
                              'توفير ${_formatSar(currentQuote.savingsSar)} ${Ar.sarCurrency}',
                          color: c.success,
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _DurationButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DurationButton({
    required this.label,
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
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.accent : c.inputBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? c.accent : c.border),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? c.tInverse : c.t1,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
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

class _SoftPill extends StatelessWidget {
  final String label;
  final Color color;

  const _SoftPill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: c.isDark ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetricPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.inputBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: c.t2),
          const SizedBox(width: 6),
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

String _headlineForTrigger(String? trigger) {
  switch (trigger) {
    case 'memberLimit':
      return 'وسّع الديوانية';
    case 'photoLimit':
      return 'افتح مساحة الصور';
    case 'pollLimit':
      return 'فعّل التصويتات الإضافية';
    case 'secondDiwaniya':
      return 'أنشئ ديوانية إضافية';
    default:
      return 'اختر باقة الديوانية';
  }
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

String _statusLabel(String? status) {
  switch (status) {
    case 'active_paid':
      return 'مدفوع';
    case 'cancel_scheduled':
      return 'ينتهي لاحقا';
    case 'billing_retry':
      return 'قيد التحقق';
    case 'grace_period':
      return 'مهلة دفع';
    case 'expired_free_fallback':
    default:
      return 'مجاني';
  }
}

Color _statusColor(CL c, String? status) {
  switch (status) {
    case 'active_paid':
      return c.success;
    case 'cancel_scheduled':
    case 'billing_retry':
    case 'grace_period':
      return c.warning;
    default:
      return c.info;
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
