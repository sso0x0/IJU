import 'package:material_ui/material_ui.dart';

/// ‘이렇게’ 따옴표로 감싼 부분을 굵게 만든 TextSpan 목록. 문장 조립·음성 연습 조언에서 씁니다.
List<TextSpan> boldQuoted(String text) {
  const bold = TextStyle(fontWeight: FontWeight.w700);
  final spans = <TextSpan>[];
  var last = 0;
  for (final m in RegExp('[‘\'"“][^’\'"”]+[’\'"”]').allMatches(text)) {
    spans
      ..add(TextSpan(text: text.substring(last, m.start)))
      ..add(TextSpan(text: m.group(0), style: bold));
    last = m.end;
  }
  spans.add(TextSpan(text: text.substring(last)));
  return spans;
}
