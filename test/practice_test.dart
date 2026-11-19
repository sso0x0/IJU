import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:iju/features/practice/practice_api.dart';
import 'package:iju/features/practice/practice_screen.dart';

void main() {
  group('PracticeApi.localScore (서버 없을 때 채점)', () {
    test('띄어쓰기·문장부호만 다르면 100점', () {
      final r = PracticeApi.localScore(
        transcript: '삼겹살 600그램 구이용으로주세요',
        target: '삼겹살 600그램 구이용으로 주세요.',
      );
      expect(r.score, 100);
      expect(r.wrongWords, isEmpty);
    });

    test('틀린 어절을 골라낸다', () {
      final r = PracticeApi.localScore(
        transcript: '삼겹살 600그램 구이요으로 주세요',
        target: '삼겹살 600그램 구이용으로 주세요.',
      );
      expect(r.score, inInclusiveRange(80, 99));
      expect(r.wrongWords, ['구이요으로']);
    });
  });

  testWidgets('연습 화면은 넘겨받은 문장을 말할 문장으로 보여 준다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PracticeScreen(
          args: PracticeArgs(
            sentence: '목살 300그램 찌개용으로 주세요.',
            meaning: 'Cho tôi 300g thịt nạc vai để nấu canh.',
          ),
        ),
      ),
    );

    expect(find.text('어서 오세요. 뭐 드릴까요?'), findsOneWidget);
    expect(find.text('이렇게 말해 보세요'), findsOneWidget);
    expect(find.text('목살 300그램 찌개용으로 주세요.'), findsOneWidget);
    expect(find.text('정육점 상황 · 1/2 턴'), findsOneWidget);
    expect(find.text('눌러서 말하기'), findsOneWidget);
  });
}
