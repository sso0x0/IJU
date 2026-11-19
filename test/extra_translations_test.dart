import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iju/app/diet.dart';
import 'package:iju/app/extra_translations.dart';
import 'package:iju/app/session.dart';
import 'package:iju/features/scenario/scenarios.dart';

void main() {
  tearDown(() => AppSession.language = 'vi');

  test('고정 문구(Tr 맵)의 영어 원문은 모두 새 7개 언어 번역이 있어요', () {
    const langs = ['lo', 'th', 'id', 'uz', 'mn', 'ne', 'zh'];
    final en = RegExp(r"'en':\s*'((?:[^'\\]|\\.)*)'");
    final missing = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.contains('translations') ||
          f.path.contains('native_strings')) {
        continue;
      }
      for (final m in en.allMatches(f.readAsStringSync())) {
        final text = m.group(1)!.replaceAll(r"\'", "'");
        if (text == 'Hello' || text.contains(r'$')) continue; // 홈 인사는 맵에 직접 있어요
        final row = extraTranslations[text];
        if (row == null || !langs.every(row.containsKey)) missing.add(text);
      }
    }
    expect(missing, isEmpty);
  });

  test('새 언어에서도 식단 설명과 재료 뜻이 그 언어로 나와요', () {
    AppSession.language = 'th';
    expect(dietAbout(Diet.islam), 'อิสลาม (ฮาลาล): ไม่ทานหมู เหล้า');
    expect(tr(const {'vi': 'trứng', 'en': 'egg'}), 'ไข่');
    AppSession.language = 'fil';
    expect(tr(const {'vi': 'trứng', 'en': 'egg', 'fil': 'itlog'}), 'itlog');
  });
}
