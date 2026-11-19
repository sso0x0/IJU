import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:iju/features/practice/practice_api.dart';
import 'package:iju/features/practice/practice_screen.dart';

void main() {
  group('PracticeApi.localScore (서버 없을 때 채점)', () {
    test('띄어쓰기·문장부호만 다르면 100점', () {
      final r = PracticeApi.localScore(
        transcript: '김치찌개 2인분 덜 맵게 해주세요',
        target: '김치찌개 2인분 덜 맵게 해 주세요.',
      );
      expect(r.score, 100);
      expect(r.wrongWords, isEmpty);
    });

    test('틀린 어절을 골라낸다', () {
      final r = PracticeApi.localScore(
        transcript: '김치찌개 2인분 덜 맵께 해 주세요',
        target: '김치찌개 2인분 덜 맵게 해 주세요.',
      );
      expect(r.score, inInclusiveRange(80, 99));
      expect(r.wrongWords, ['맵께']);
    });
  });

  testWidgets('연습 화면은 넘겨받은 문장을 말할 문장으로 보여 준다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PracticeScreen(
          args: PracticeArgs(
            sentence: '삼겹살 2인분 주세요.',
            meaning: 'Cho tôi 2 phần thịt ba chỉ.',
          ),
        ),
      ),
    );

    // 사장님 대사 없이 내가 말할 문장만 보여 줘요.
    expect(find.text('어서 오세요. 주문하시겠어요?'), findsNothing);
    expect(find.text('이렇게 말해 보세요'), findsOneWidget);
    expect(find.text('삼겹살 2인분 주세요.'), findsOneWidget);
    expect(find.text('식당 상황'), findsOneWidget);
    expect(find.text('눌러서 말하기'), findsOneWidget);
  });
}
