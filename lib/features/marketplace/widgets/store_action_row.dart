import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme/app_colors.dart';
import '../../../l10n/ar.dart';
import '../models/store_model.dart';
import '../services/marketplace_service.dart';

class StoreActionRow extends StatelessWidget {
  final Store store;
  final String? diwaniyaId;
  final String? cityId;
  final String? districtId;

  const StoreActionRow({
    super.key,
    required this.store,
    this.diwaniyaId,
    this.cityId,
    this.districtId,
  });

  static bool hasActions(Store store) {
    return _phoneUri(store.phone) != null ||
        _whatsAppUri(store.whatsapp ?? store.phone) != null ||
        _webUri(store.directionsUrl ?? store.mapUrl) != null ||
        _webUri(store.website) != null ||
        _mapsSearchUri(store.description) != null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final phoneUri = _phoneUri(store.phone);
    final whatsappUri = _whatsAppUri(store.whatsapp ?? store.phone);
    final mapsUri = _webUri(store.directionsUrl ?? store.mapUrl) ??
        _mapsSearchUri(store.description);
    final websiteUri = _webUri(store.website);
    final actions = <_ActionSpec>[
      if (whatsappUri != null)
        _ActionSpec(
          icon: Icons.chat_rounded,
          label: Ar.whatsappAction,
          color: const Color(0xFF25D366),
          eventType: 'marketplace_whatsapp_click',
          uri: whatsappUri,
        ),
      if (phoneUri != null)
        _ActionSpec(
          icon: Icons.call_rounded,
          label: Ar.callAction,
          color: c.success,
          eventType: 'marketplace_call_click',
          uri: phoneUri,
        ),
      if (mapsUri != null)
        _ActionSpec(
          icon: Icons.map_rounded,
          label: Ar.mapsAction,
          color: c.info,
          eventType: 'marketplace_directions_click',
          uri: mapsUri,
        ),
      if (websiteUri != null)
        _ActionSpec(
          icon: Icons.public_rounded,
          label: 'الموقع',
          color: c.accent,
          eventType: 'marketplace_website_click',
          uri: websiteUri,
        ),
    ];

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          Expanded(
            child: _ActionBtn(
              spec: actions[i],
              onTap: () => _launchAction(context, actions[i]),
            ),
          ),
          if (i != actions.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }

  Future<void> _launchAction(BuildContext context, _ActionSpec spec) async {
    MarketplaceService.recordMarketplaceEventLater(
      eventType: spec.eventType,
      store: store,
      diwaniyaId: diwaniyaId,
      cityId: cityId,
      districtId: districtId,
    );
    final ok = await launchUrl(spec.uri, mode: LaunchMode.externalApplication);
    if (ok || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تعذر فتح الرابط الآن.')),
    );
  }
}

class _ActionSpec {
  final IconData icon;
  final String label;
  final Color color;
  final String eventType;
  final Uri uri;

  const _ActionSpec({
    required this.icon,
    required this.label,
    required this.color,
    required this.eventType,
    required this.uri,
  });
}

class _ActionBtn extends StatelessWidget {
  final _ActionSpec spec;
  final VoidCallback? onTap;

  const _ActionBtn({
    required this.spec,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: spec.color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(spec.icon, size: 22, color: spec.color),
            const SizedBox(height: 4),
            Text(
              spec.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: spec.color,
              ),
            ),
          ]),
        ),
      );
}

Uri? _phoneUri(String? value) {
  final digits = _sanitizedPhone(value);
  if (digits == null) return null;
  return Uri(scheme: 'tel', path: digits);
}

Uri? _whatsAppUri(String? value) {
  final web = _webUri(value);
  if (web != null && web.host.contains('wa.me')) return web;
  final digits = _sanitizedPhone(value);
  if (digits == null) return null;
  return Uri.https(
    'wa.me',
    '/$digits',
    {'text': 'السلام عليكم، وصلت لكم من تطبيق ديوانية.'},
  );
}

Uri? _webUri(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  final uri = Uri.tryParse(text);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
  if (uri.scheme != 'https' && uri.scheme != 'http') return null;
  return uri;
}

Uri? _mapsSearchUri(String address) {
  final query = address.trim();
  if (query.isEmpty) return null;
  return Uri.https(
    'www.google.com',
    '/maps/search/',
    {'api': '1', 'query': query},
  );
}

String? _sanitizedPhone(String? value) {
  final digits = value?.replaceAll(RegExp(r'\D'), '');
  if (digits == null || digits.length < 7 || digits.length > 15) return null;
  return digits;
}
