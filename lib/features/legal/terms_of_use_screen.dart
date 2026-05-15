import 'package:flutter/material.dart';

import 'legal_document_screen.dart';

class TermsOfUseScreen extends StatelessWidget {
  const TermsOfUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentScreen(
      title: 'شروط الاستخدام',
      assetPath: 'assets/legal/terms_of_use_ar.md',
    );
  }
}
