import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import 'review_steps_screen.dart';
import 'review_store.dart';

/// 복습 목록에서 이 문장을 찾습니다 (없으면 null).
ReviewItem? reviewFor(String sentence) {
  final s = sentence.trim();
  return ReviewStore.items.value
      .where((i) => i.sentence.trim() == s)
      .firstOrNull;
}

/// 이 문장을 단계별로 복습합니다 (보여주기 → 따라 말하기 → 빈칸 말하기 → 혼자 말하기).
///
/// 복습 목록에 있는 문장이면 그 복습 단계로 기록하고, 없으면 끝냈을 때 복습 목록에 넣어요.
void practiceSentence(
  BuildContext context, {
  required String sentence,
  String? meaning,
}) {
  final item = reviewFor(sentence);
  if (item != null) {
    final stage = item.stage;
    final (s, m) = item.textFor(stage);
    context.push(
      AppRoutes.reviewSteps,
      extra: ReviewStepsArgs(
        sentence: s,
        meaning: m,
        reviewId: item.id,
        stage: stage,
      ),
    );
    return;
  }
  context.push(
    AppRoutes.reviewSteps,
    extra: ReviewStepsArgs(sentence: sentence, meaning: meaning ?? ''),
  );
}
