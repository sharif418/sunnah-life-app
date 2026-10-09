// Admin CMS edits reach the app without the app ever waiting on the network:
// a pack opens on the phone's copy (or the bundle) at once, the server's copy
// is fetched in the background and shown from the next open on.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sunnah_life/models/content_models.dart';

const _bundle = '{"items":[{"q":"বান্ডেলের প্রশ্ন","a":"বান্ডেল"}]}';

void main() {
  setUp(() {
    ContentPack.resetForTesting();
    ContentPack.assetLoaderForTesting = (path) async => _bundle;
  });
  tearDown(ContentPack.resetForTesting);

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  test('opens on the bundle at once; the server copy shows from the next open, and is kept', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final server = Completer<Map<String, dynamic>?>();
    final asked = <String>[];
    ContentPack.remote = (key) {
      asked.add(key);
      return server.future;
    };
    // the server has not answered — the screen does not wait for it
    expect((await ContentPack.faq()).first.q, 'বান্ডেলের প্রশ্ন');
    expect(asked, ['faq']);

    server.complete({
      'items': [
        {'q': 'সার্ভারের প্রশ্ন', 'a': 'নতুন'},
      ],
    });
    await settle();
    expect((await ContentPack.faq()).first.q, 'সার্ভারের প্রশ্ন');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('content_pack_cache_faq.json'), contains('সার্ভারের প্রশ্ন'));
    // once a session
    expect(asked, ['faq']);
  });

  test('the phone copy from last time opens first (offline too)', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'content_pack_cache_faq.json': '{"items":[{"q":"আগের কপি","a":"x"}]}',
    });
    ContentPack.remote = (key) async => throw Exception('offline');
    expect((await ContentPack.faq()).first.q, 'আগের কপি');
  });

  test('offline and nothing kept: the bundle; the refresh is tried again next open', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    var calls = 0;
    ContentPack.remote = (key) async {
      calls++;
      throw Exception('offline');
    };
    expect((await ContentPack.faq()).first.q, 'বান্ডেলের প্রশ্ন');
    await settle();
    await ContentPack.faq();
    await settle();
    expect(calls, 2);
  });

  test('the newly managed packs come from the server too (adhkar, sunnahs, 99 names…)', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final asked = <String>[];
    ContentPack.remote = (key) async {
      asked.add(key);
      return null;
    };
    ContentPack.assetLoaderForTesting = (path) async => '{}';
    await ContentPack.adhkar();
    await ContentPack.sunnahs();
    await ContentPack.names99();
    await ContentPack.islamicNames();
    await ContentPack.imanBranches();
    expect(asked, ['adhkar', 'sunnahs', 'names99', 'islamic-names', 'iman-branches']);
  });
}
