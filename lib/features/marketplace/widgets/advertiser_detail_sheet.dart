import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme/app_colors.dart';
import '../../../core/navigation/app_routes.dart';
import '../models/marketplace_ad_model.dart';
import '../services/marketplace_service.dart';

Future<void> showAdvertiserDetailSheet(
  BuildContext context,
  MarketplaceAd ad,
) {
  final parentContext = context;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: _AdvertiserDetailSheet(
          ad: ad,
          parentContext: parentContext,
        ),
      );
    },
  );
}

class _AdvertiserDetailSheet extends StatelessWidget {
  const _AdvertiserDetailSheet({
    required this.ad,
    required this.parentContext,
  });

  final MarketplaceAd ad;
  final BuildContext parentContext;

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final title = _displayText(ad.title);
    final storeName = _displayText(ad.storeName);
    final description = _displayText(ad.description);
    final city = _cityLabel(ad);
    final districts = _districtsLabel(ad, city: city);
    final imageUrl = ad.imageUrl?.trim();
    final whatsAppUri = _whatsAppUri(
      ad.contactWhatsapp ?? ad.storeWhatsapp ?? ad.storePhone,
    );
    final contactUri = _webUri(ad.contactUrl);
    final mapUri = _webUri(ad.mapUrl ?? ad.storeGoogleMapsUrl);
    final storeRouteId = _storeRouteId(ad);
    final hasActions =
        whatsAppUri != null || contactUri != null || mapUri != null || storeRouteId != null;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.48,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: c.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.t3.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (imageUrl != null && imageUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: AspectRatio(
                    aspectRatio: 16 / 7,
                    child: Image.network(
                      imageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, __, ___) => _NeutralImageFallback(color: c.inputBg),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              Text(
                'تفاصيل الإعلان',
                style: TextStyle(
                  color: c.t1,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (title != null) ...[
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: c.t1,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ],
              if (description != null) ...[
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    color: c.t2,
                    fontSize: 13.5,
                    height: 1.75,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              _DetailRows(
                rows: [
                  if (storeName != null) ('المعلن', storeName),
                  if (city != null) ('المدينة', city),
                  if (districts != null) ('الأحياء المستهدفة', districts),
                ],
              ),
              if (hasActions) ...[
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (whatsAppUri != null)
                      _SheetActionButton(
                        icon: Icons.chat_rounded,
                        label: 'تواصل عبر واتساب',
                        color: const Color(0xFF25D366),
                        onTap: () => _launchExternal(context, whatsAppUri),
                      ),
                    if (contactUri != null)
                      _SheetActionButton(
                        icon: Icons.open_in_new_rounded,
                        label: 'فتح الموقع',
                        color: c.info,
                        onTap: () => _launchExternal(context, contactUri),
                      ),
                    if (mapUri != null)
                      _SheetActionButton(
                        icon: Icons.map_rounded,
                        label: contactUri == null ? 'فتح الموقع' : 'فتح الخريطة',
                        color: c.accent,
                        onTap: () => _launchExternal(context, mapUri),
                      ),
                    if (storeRouteId != null)
                      _SheetActionButton(
                        icon: Icons.storefront_rounded,
                        label: 'عرض المتجر',
                        color: c.success,
                        onTap: () => _openStore(context, storeRouteId),
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _openStore(BuildContext context, String storeId) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!parentContext.mounted) return;
      parentContext.push(AppRoutes.storeDetails, extra: storeId);
    });
  }

  static String? _cityLabel(MarketplaceAd ad) {
    return _displayText(ad.targetCityNameAr) ??
        _displayText(ad.targetCity) ??
        _displayText(ad.storeCityNameAr);
  }

  static String? _districtsLabel(MarketplaceAd ad, {required String? city}) {
    final canonicalDistricts = (ad.targetDistrictNamesAr ?? const <String>[])
        .map(_displayText)
        .whereType<String>()
        .toList(growable: false);
    if (canonicalDistricts.isNotEmpty) return canonicalDistricts.join('، ');

    final districtList = (ad.targetDistricts ?? const <String>[])
        .map(_displayText)
        .where((value) => value == null || !_looksLikeId(value))
        .whereType<String>()
        .toList(growable: false);
    if (districtList.isNotEmpty) return districtList.join('، ');

    final districtName =
        _displayText(ad.targetDistrictNameAr) ?? _displayText(ad.storeDistrictNameAr);
    if (districtName != null) return districtName;

    return city == null ? null : 'كامل المدينة';
  }

  static String? _storeRouteId(MarketplaceAd ad) {
    final storeId = ad.merchantStoreId?.trim();
    if (storeId == null || storeId.isEmpty) return null;
    return MarketplaceService.getStoreById(storeId) == null ? null : storeId;
  }

  static bool _looksLikeId(String value) {
    return RegExp(r'^[a-z0-9_-]{8,}$', caseSensitive: false).hasMatch(value) &&
        !RegExp(r'[\u0600-\u06FF]').hasMatch(value);
  }
}

class _DetailRows extends StatelessWidget {
  const _DetailRows({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final c = context.cl;

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _DetailRow(label: rows[i].$1, value: rows[i].$2),
            if (i != rows.length - 1)
              Divider(height: 1, thickness: 1, color: c.divider),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: TextStyle(
                color: c.t3,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: c.t1,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetActionButton extends StatelessWidget {
  const _SheetActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Material(
      color: color.withValues(alpha: context.isDark ? 0.16 : 0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: c.t1,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NeutralImageFallback extends StatelessWidget {
  const _NeutralImageFallback({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: color);
  }
}

Future<void> _launchExternal(BuildContext context, Uri uri) async {
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (ok || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('تعذر فتح الرابط الآن.')),
  );
}

Uri? _webUri(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  final uri = Uri.tryParse(text);
  if (uri == null || !uri.hasAbsolutePath && uri.host.isEmpty) return null;
  if (uri.scheme != 'https' && uri.scheme != 'http') return null;
  return uri;
}

Uri? _whatsAppUri(String? value) {
  final phone = _sanitizedPhone(value);
  if (phone == null) return null;
  return Uri.https(
    'wa.me',
    '/$phone',
    {'text': 'السلام عليكم، شاهدت إعلانكم في تطبيق ديوانية.'},
  );
}

String? _sanitizedPhone(String? value) {
  final digits = value?.replaceAll(RegExp(r'\D'), '');
  if (digits == null || digits.length < 7 || digits.length > 15) return null;
  return digits;
}

String? _displayText(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  final lower = text.toLowerCase();
  if (lower.startsWith('geo-')) return null;
  return text;
}
