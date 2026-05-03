import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../storage/hive_storage.dart';

class SessionService {
  SessionService._();

  static Box get _box => Hive.box(HiveBoxes.session);
  static final ValueNotifier<int> stateVersion = ValueNotifier<int>(0);

  static bool get hasSession => _box.get('active', defaultValue: false) == true;

  static Future<void> activate() async {
    await _box.put('active', true);
    bump();
  }

  static Future<void> deactivate() async {
    await _box.put('active', false);
    bump();
  }

  static Future<void> clear() async {
    await _box.clear();
    bump();
  }

  static Future<void> put(String key, dynamic value) async {
    await _box.put(key, value);
    bump();
  }

  static T? get<T>(String key, {T? defaultValue}) {
    return _box.get(key, defaultValue: defaultValue) as T?;
  }

  static List<String> getStringList(String key) {
    final raw = _box.get(key);
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    if (raw is String && raw.isNotEmpty) {
      return List<String>.from(jsonDecode(raw) as List);
    }
    return <String>[];
  }

  static Future<void> putStringList(String key, List<String> values) async {
    await _box.put(key, values);
    bump();
  }

  static void bump() {
    stateVersion.value++;
  }
}
