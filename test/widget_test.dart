import 'package:flutter_test/flutter_test.dart';
import 'package:diwaniya/core/models/album_models.dart';

void main() {
  test('AlbumPhoto supports backward-compatible localPath alias', () {
    final photo = AlbumPhoto(
      id: 'p1',
      diwaniyaId: 'd1',
      capturedByUserId: 'u1',
      capturedByName: 'User',
      capturedAt: DateTime.parse('2026-04-19T00:00:00Z'),
      localPath: '/tmp/photo.jpg',
    );

    expect(photo.fileUrl, '/tmp/photo.jpg');
    expect(photo.localPath, '/tmp/photo.jpg');

    final restored = AlbumPhoto.fromJson(photo.toJson());
    expect(restored.fileUrl, '/tmp/photo.jpg');
    expect(restored.localPath, '/tmp/photo.jpg');
  });
}
