import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'config/theme/app_theme.dart';
import 'core/storage/hive_storage.dart';
import 'core/repositories/app_repository.dart';
import 'core/services/auth_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await loadThemePreference();
  await initStorage();
  await AppRepository.restoreSessionSelectionOnly();
  await AuthService.bootstrapSession();
  runApp(const DiwaniyaApp());
}
