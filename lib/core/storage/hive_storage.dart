import 'package:hive_flutter/hive_flutter.dart';

/// Box names for all app data.
class HiveBoxes {
  HiveBoxes._();
  static const session = 'session';
  static const users = 'users';
  static const diwaniyas = 'diwaniyas';
  static const members = 'members';
  static const expenses = 'expenses';
  static const settlements = 'settlements';
  static const shoppingItems = 'shopping_items';
  static const notifications = 'notifications';
  static const activities = 'activities';
  static const polls = 'polls';
  static const chat = 'chat';
  static const album = 'album';
  static const roleChangeRequests = 'role_change_requests';
  static const customCategories = 'custom_categories';
  static const auth = 'auth';
}

/// Initialize Hive and open all required boxes.
Future<void> initStorage() async {
  await Hive.initFlutter();
  await Hive.openBox(HiveBoxes.session);
  await Hive.openBox(HiveBoxes.users);
  await Hive.openBox(HiveBoxes.diwaniyas);
  await Hive.openBox(HiveBoxes.members);
  await Hive.openBox(HiveBoxes.expenses);
  await Hive.openBox(HiveBoxes.settlements);
  await Hive.openBox(HiveBoxes.shoppingItems);
  await Hive.openBox(HiveBoxes.notifications);
  await Hive.openBox(HiveBoxes.activities);
  await Hive.openBox(HiveBoxes.polls);
  await Hive.openBox(HiveBoxes.chat);
  await Hive.openBox(HiveBoxes.album);
  await Hive.openBox(HiveBoxes.roleChangeRequests);
  await Hive.openBox(HiveBoxes.customCategories);
  await Hive.openBox(HiveBoxes.auth);
}
