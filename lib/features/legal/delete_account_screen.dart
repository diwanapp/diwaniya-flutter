import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/services/auth_service.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  bool _isSubmitting = false;

  Future<void> _deleteAccount() async {
    if (_isSubmitting) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('تأكيد حذف الحساب'),
            content: const Text(
              'سيتم تعطيل حسابك وتسجيل خروجك من التطبيق. قد يتم الاحتفاظ ببعض السجلات لفترة محدودة وفق سياسة الخصوصية والمتطلبات النظامية. هل تريد المتابعة؟',
              textAlign: TextAlign.right,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text(
                  'تأكيد الحذف',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    setState(() => _isSubmitting = true);

    try {
      await ApiClient.delete('/me/delete-account');
      await AuthService.signOutFromApi();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف الحساب وتسجيل الخروج')),
      );

      context.go(AppRoutes.welcome);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر حذف الحساب. تحقق من الاتصال وحاول مرة أخرى.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('حذف الحساب'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 52,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 18),
            Text(
              'طلب حذف الحساب',
              textAlign: TextAlign.right,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'عند تأكيد حذف الحساب سيتم تعطيل حسابك وتسجيل خروجك من التطبيق. لا يتم حذف بيانات الديوانيات بشكل عشوائي حتى لا تتأثر حقوق أو سجلات الأعضاء الآخرين، ويتم التعامل مع البيانات وفق سياسة الخصوصية والمتطلبات النظامية.',
              textAlign: TextAlign.right,
              style: TextStyle(height: 1.7),
            ),
            const SizedBox(height: 16),
            const Text(
              'قبل المتابعة، تأكد من أنك قرأت سياسة الخصوصية وشروط الاستخدام. بعد تنفيذ الطلب قد لا تتمكن من الدخول بنفس الحساب.',
              textAlign: TextAlign.right,
              style: TextStyle(height: 1.7),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                onPressed: _isSubmitting ? null : _deleteAccount,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_forever_rounded),
                label: Text(
                  _isSubmitting ? 'جاري تنفيذ الطلب...' : 'تأكيد حذف الحساب',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}