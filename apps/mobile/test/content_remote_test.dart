// Admin CMS edits reach the app: the editable packs load from the server
// first, then the copy kept from last time (offline), then the bundle.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sunnah_life/models/content_models.dart';

void main() {
  setUp(() {
    ContentPack.resetForTesting();
    ContentPack.assetLoaderForTesting = (path) async => '{"items":[{"q":"বান্ডেলের প্রশ্ন","a":"বান্ডেল"}]}';
  });
  tearDown(ContentPack.resetForTesting);

  test('the server copy wins and is kept for offline', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ContentPack.remote = (key) async => {
      'items': [
        {'q': 'সার্ভারের প্রশ্ন ($key)', 'a': 'নতুন'},
      ],
    };
    final faq = await ContentPack.faq();
    expect(faq.first.q, 'সার্ভারের প্রশ্ন (faq)');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('content_pack_cache_faq.json'), contains('সার্ভারের প্রশ্ন'));
  });

  test('offline: the copy from last time; nothing kept: the bundle', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'content_pack_cache_faq.json': '{"items":[{"q":"আগের কপি","a":"x"}]}',
    });
    ContentPack.remote = (key) async => throw Exception('offline');
    expect((await ContentPack.faq()).first.q, 'আগের কপি');

    ContentPack.resetForTesting();
    ContentPack.assetLoaderForTesting = (path) async => '{"items":[{"q":"বান্ডেলের প্রশ্ন","a":"বান্ডেল"}]}';
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ContentPack.remote = (key) async => throw Exception('offline');
    expect((await ContentPack.faq()).first.q, 'বান্ডেলের প্রশ্ন');
  });
}
