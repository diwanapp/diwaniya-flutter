import '../models/mock_data.dart';
import '../models/subscription_status.dart';
import 'album_service.dart';
import 'subscription_service.dart';

enum LimitStatus { ok, nearLimit, atLimit }

typedef EntitlementResolver = bool Function(String diwaniyaId);

/// Per-diwaniya free vs premium gating.
///
/// A diwaniya is "premium" when its local `SubscriptionStatus` is active
/// and the plan is `monthly` or `yearly`. Everything else (including the
/// new `free` plan and `joined` members) is treated as non-premium and
/// subject to the free-tier limits below.
///
/// Subscription data is still resolved through [SubscriptionService] in
/// this phase. This file is intentionally kept as a narrow entitlement
/// facade so the production migration can switch the resolver to a
/// backend-authoritative source without touching UI call sites.
class EntitlementService {
  EntitlementService._();

  static EntitlementResolver? _overrideResolver;

  static void configureResolver(EntitlementResolver? resolver) {
    _overrideResolver = resolver;
    _premiumCache.clear();
    _premiumCacheVersion = -1;
  }

  // ── Free-tier limits (product-approved) ──
  static const int freeMaxMembers = 6;
  static const int freeMaxPhotos = 10;
  static const int freeMaxDiwaniyas = 1;
  static const int freeMaxActivePolls = 1;

  // ── Premium limits (effectively unlimited) ──
  static const int premiumMaxMembers = 999;
  static const int premiumMaxPhotos = 999;
  static const int premiumMaxDiwaniyas = 999;
  static const int premiumMaxActivePolls = 999;

  // ── Premium check ──

  /// Whether the currently selected diwaniya is on a paid plan.
  static bool get isPremium => _isPremiumFor(currentDiwaniyaId);

  /// Per-frame memoization cache for [_isPremiumFor]. Cleared whenever
  /// [dataVersion] changes (any state mutation), so checks within a
  /// single build pass reuse the same answer instead of re-walking
  /// `SubscriptionService.forDiwaniya` once per limit check per widget.
  /// Safe because all subscription mutations bump `dataVersion`.
  static int _premiumCacheVersion = -1;
  static final Map<String, bool> _premiumCache = {};

  static bool _isPremiumFor(String diwaniyaId) {
    if (diwaniyaId.isEmpty) return false;
    final v = dataVersion.value;
    if (v != _premiumCacheVersion) {
      _premiumCache.clear();
      _premiumCacheVersion = v;
    }
    final cached = _premiumCache[diwaniyaId];
    if (cached != null) return cached;
    final override = _overrideResolver;
    if (override != null) {
      final result = override(diwaniyaId);
      _premiumCache[diwaniyaId] = result;
      return result;
    }
    final sub = SubscriptionService.forDiwaniya(diwaniyaId);
    final result = sub != null &&
        sub.active &&
        (sub.plan == SubscriptionPlan.monthly ||
            sub.plan == SubscriptionPlan.yearly);
    _premiumCache[diwaniyaId] = result;
    return result;
  }

  // ── Limit getters (for UI display) ──

  static int get maxMembers =>
      isPremium ? premiumMaxMembers : freeMaxMembers;
  static int get maxPhotos => isPremium ? premiumMaxPhotos : freeMaxPhotos;
  static int get maxDiwaniyas =>
      isPremium ? premiumMaxDiwaniyas : freeMaxDiwaniyas;
  static int get maxActivePolls =>
      isPremium ? premiumMaxActivePolls : freeMaxActivePolls;

  // ── Capability flags ──
  // No feature gating in this phase — differentiation is numeric only.
  // These remain true for all tiers so existing UI paths compile.
  static bool get canAccessDashboard => true;
  static bool get canManageAdvancedRoles => true;
  static bool get canExportData => true;

  // ── Limit check methods ──

  /// How many diwaniyas the current user has locally. Free tier limits
  /// creation to `freeMaxDiwaniyas`. Premium (any existing paid diwaniya)
  /// lifts the limit for all new ones. This is a device-local view.
  static LimitStatus checkDiwaniyaLimit() {
    // If ANY owned diwaniya is premium, allow unlimited creation.
    final hasAnyPremium = allDiwaniyas.any((d) => _isPremiumFor(d.id));
    if (hasAnyPremium) return LimitStatus.ok;
    return _status(allDiwaniyas.length, freeMaxDiwaniyas);
  }

  /// Member count for the given diwaniya vs its tier's limit.
  static LimitStatus checkMemberLimit(String diwaniyaId) {
    if (_isPremiumFor(diwaniyaId)) return LimitStatus.ok;
    final count = (diwaniyaMembers[diwaniyaId] ?? const []).length;
    return _status(count, freeMaxMembers);
  }

  /// Active photo count for the given diwaniya vs its tier's limit.
  static LimitStatus checkPhotoLimit(String diwaniyaId) {
    if (_isPremiumFor(diwaniyaId)) return LimitStatus.ok;
    final count = AlbumService.activePhotos(diwaniyaId).length;
    return _status(count, freeMaxPhotos);
  }

  /// Active poll count for the given diwaniya vs its tier's limit.
  static LimitStatus checkPollLimit(String diwaniyaId) {
    if (_isPremiumFor(diwaniyaId)) return LimitStatus.ok;
    final polls = diwaniyaPolls[diwaniyaId] ?? const <DiwaniyaPoll>[];
    final activeCount = polls.where((p) => p.isActive).length;
    return _status(activeCount, freeMaxActivePolls);
  }

  // ── Helper ──

  static LimitStatus _status(int count, int limit) {
    if (count >= limit) return LimitStatus.atLimit;
    if (count >= (limit * 0.8).ceil()) return LimitStatus.nearLimit;
    return LimitStatus.ok;
  }
}
