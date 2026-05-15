import 'package:flutter/material.dart';

import 'legal_document_screen.dart';

class LegalCenterScreen extends StatelessWidget {
  const LegalCenterScreen({super.key});

  static const _documents = <_LegalDocument>[
    _LegalDocument(
      title: 'سياسة الخصوصية',
      subtitle: 'كيف نحمي بياناتك ونستخدمها ونشاركها وفق الأنظمة.',
      icon: Icons.privacy_tip_outlined,
      assetPath: 'assets/legal/privacy_policy_ar.md',
    ),
    _LegalDocument(
      title: 'شروط الاستخدام',
      subtitle: 'قواعد استخدام ديوانية وصلاحيات المؤسس والمدير والعضو.',
      icon: Icons.description_outlined,
      assetPath: 'assets/legal/terms_of_use_ar.md',
    ),
    _LegalDocument(
      title: 'سياسة الاستخدام والمحتوى',
      subtitle: 'السلوك والمحتوى المسموح والممنوع داخل التطبيق.',
      icon: Icons.shield_outlined,
      assetPath: 'assets/legal/community_guidelines_ar.md',
    ),
    _LegalDocument(
      title: 'الاحتفاظ بالبيانات وحذفها',
      subtitle: 'متى نحفظ البيانات ومتى نحذفها أو نقيدها.',
      icon: Icons.manage_history_rounded,
      assetPath: 'assets/legal/data_retention_deletion_policy_ar.md',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: c.surface,
        appBar: AppBar(
          backgroundColor: c.surface,
          title: Text(
            'الخصوصية والشروط',
            style: TextStyle(
              color: c.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: c.shadow, blurRadius: 8)],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: c.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.verified_user_outlined,
                        color: c.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مستندات الثقة والامتثال',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: c.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'هنا تجد السياسات التي توضّح طريقة استخدام ديوانية، وحماية البيانات، وتنظيم المحتوى داخل التطبيق.',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: c.onSurfaceVariant,
                              height: 1.65,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              ..._documents.map(
                (doc) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _LegalCard(document: doc),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'للاستفسارات أو طلبات الخصوصية: info@diwaniya.online',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: c.onSurfaceVariant, fontSize: 12.5, height: 1.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalCard extends StatelessWidget {
  final _LegalDocument document;

  const _LegalCard({required this.document});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Material(
      color: c.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LegalDocumentScreen(
                title: document.title,
                assetPath: document.assetPath,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.outlineVariant.withValues(alpha: 0.65)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(document.icon, color: c.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.title,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: c.onSurface,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      document.subtitle,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: c.onSurfaceVariant,
                        height: 1.55,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_left_rounded, color: c.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalDocument {
  final String title;
  final String subtitle;
  final IconData icon;
  final String assetPath;

  const _LegalDocument({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.assetPath,
  });
}
