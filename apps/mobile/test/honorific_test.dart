// ﷺ in Bengali text reads as "(সা.)"; Arabic keeps the ligature; the
// content packs and their fallbacks all pass through it.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sunnah_life/core/honorific.dart';
import 'package:sunnah_life/models/content_models.dart';

void main() {
  test('Bengali sentences get (সা.), with or without a space before the mark', () {
    expect(honorificText('নবীজি ﷺ বলেছেন'), 'নবীজি (সা.) বলেছেন');
    expect(honorificText('নবীজি ﷺ-এর সুন্নাহ'), 'নবীজি (সা.)-এর সুন্নাহ');
    expect(honorificText('রাসূলুল্লাহﷺ বলেন'), 'রাসূলুল্লাহ (সা.) বলেন');
  });

  test('Arabic text and text without the mark stay as they are', () {
    expect(honorificText('اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ ﷺ'), 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ ﷺ');
    expect(honorificText('সাধারণ লেখা'), 'সাধারণ লেখা');
  });

  test('applied twice changes nothing more (a kept copy is safe to re-read)', () {
    final once = honorificText('নবীজি ﷺ বলেছেন');
    expect(honorificText(once), once);
  });

  test('a whole pack document, keys untouched', () {
    final doc = withHonorific({
      'items': [
        {'id': 'x', 'detailBn': 'নবীজি ﷺ ভালোবাসতেন', 'arabic': 'صَلَّى اللهُ عَلَيْهِ وَسَلَّمَ ﷺ'},
      ],
    }) as Map<String, dynamic>;
    final item = (doc['items'] as List).single as Map<String, dynamic>;
    expect(item['detailBn'], 'নবীজি (সা.) ভালোবাসতেন');
    expect(item['arabic'], contains('ﷺ'));
  });

  test('the sunnah pack as the app reads it', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ContentPack.resetForTesting();
    ContentPack.assetLoaderForTesting = (path) async =>
        '{"items":[{"id":"a","category":"daily","titleBn":"ডান দিক","detailBn":"নবীজি ﷺ ডান দিক ভালোবাসতেন","reference":"বুখারী"}]}';
    addTearDown(ContentPack.resetForTesting);
    final items = await ContentPack.sunnahs();
    expect(items.single.detailBn, 'নবীজি (সা.) ডান দিক ভালোবাসতেন');
  });
}
