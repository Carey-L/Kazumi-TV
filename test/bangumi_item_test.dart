import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';

void main() {
  test('parses Bangumi episode progress fields', () {
    final item = BangumiItem.fromJson({
      'id': 1,
      'type': 2,
      'name': 'Test anime',
      'images': const <String, String>{},
      'rating': {
        'rank': 0,
        'score': 0,
        'total': 0,
        'count': List<int>.filled(10, 0),
      },
      'eps': 24,
    });

    expect(item.eps, 24);
    expect(item.updatedEpisodes, 0);
  });

  test('defaults missing Bangumi episode progress fields to zero', () {
    final item = BangumiItem.fromJson({
      'id': 1,
      'type': 2,
      'name': 'Test anime',
      'images': const <String, String>{},
      'rating': {
        'rank': 0,
        'score': 0,
        'total': 0,
        'count': List<int>.filled(10, 0),
      },
    });

    expect(item.eps, 0);
    expect(item.updatedEpisodes, 0);
  });
}
