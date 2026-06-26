import 'dart:io';

import 'package:diwaniya/core/models/mock_data.dart';
import 'package:diwaniya/core/repositories/app_repository.dart';
import 'package:diwaniya/core/storage/hive_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('diwaniya_hive_test_');
    Hive.init(tempDir.path);
    await Hive.openBox(HiveBoxes.session);
    currentDiwaniyaId = '';
  });

  tearDown(() async {
    currentDiwaniyaId = '';
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('saveSelectedDiwaniya persists even when memory already has new id',
      () async {
    final session = Hive.box(HiveBoxes.session);
    await session.put('selectedDiwaniya', 'old-diwaniya');
    currentDiwaniyaId = 'new-diwaniya';

    await AppRepository.saveSelectedDiwaniya('new-diwaniya');

    expect(currentDiwaniyaId, 'new-diwaniya');
    expect(session.get('selectedDiwaniya'), 'new-diwaniya');
  });

  test('restoreSessionSelectionOnly restores the persisted selected diwaniya',
      () async {
    await AppRepository.saveSelectedDiwaniya('persisted-diwaniya');
    currentDiwaniyaId = '';

    await AppRepository.restoreSessionSelectionOnly();

    expect(currentDiwaniyaId, 'persisted-diwaniya');
  });
}
