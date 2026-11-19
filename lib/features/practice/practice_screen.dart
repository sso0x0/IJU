import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/router.dart';
import '../../widgets/iju_button.dart';
import '../../widgets/iju_header.dart';
import '../../widgets/iju_icon.dart';

/// Figma '5 음성 연습'. AI 사장님과 주고받고 발음 점수를 받습니다. 담당: 개발자2
/// TODO(개발자2): 녹음 → POST /ai/pronunciation, 듣기 → POST /ai/tts 연결. 지금은 시연용 고정 데이터입니다.
class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const IjuHeader(
              title: 'AI 사장님과 연습',
              subtitle: '정육점 상황 · 1/2 턴',
              backgroundColor: AppColors.surface,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                children: [
                  _AiBubble(
                    text: '어서 오세요. 뭐 드릴까요?',
                    translation: 'Xin mời. Anh cần gì ạ?',
                    onListen: () {
                      // TODO(개발자2): TTS 재생
                    },
                  ),
                  const SizedBox(height: 14),
                  const _UserBubble(
                    before: '삼겹살 600그램',
                    wrong: '구이요으로',
                    after: '주세요.',
                  ),
                  const SizedBox(height: 14),
                  const _ScoreCard(score: 82),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                children: [
                  const _Waveform(),
                  const SizedBox(height: 10),
                  _MicButton(
                    onTap: () {
                      // TODO(개발자2): 녹음 시작/종료
                    },
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '눌러서 다시 말하기',
                    style: TextStyle(fontSize: 14, color: AppColors.textBody),
                  ),
                  const SizedBox(height: 10),
                  IjuTextLink(
                    label: '실전으로 가기',
                    fontSize: 15,
                    bold: true,
                    onTap: () => context.push(AppRoutes.realOrder),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiBubble extends StatelessWidget {
  const _AiBubble({
    required this.text,
    required this.translation,
    required this.onListen,
  });

  final String text;
  final String translation;
  final VoidCallback onListen;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.dark,
            shape: BoxShape.circle,
          ),
          child: const Text(
            '사장',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 250),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    translation,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSub,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _ListenButton(onTap: onListen),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ListenButton extends StatelessWidget {
  const _ListenButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const StadiumBorder(side: BorderSide(color: AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const SizedBox(
          height: 32,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IjuIcon(IjuIcons.speaker, size: 14),
                SizedBox(width: 4),
                Text(
                  '듣기',
                  style: TextStyle(fontSize: 13, color: AppColors.text),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 내가 말한 문장. 틀린 단어는 주황 배경으로 표시합니다.
class _UserBubble extends StatelessWidget {
  const _UserBubble({
    required this.before,
    required this.wrong,
    required this.after,
  });

  final String before;
  final String wrong;
  final String after;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w500,
      color: Colors.white,
    );

    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 270),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(before, style: style),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: AppColors.pointBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      wrong,
                      style: style.copyWith(color: AppColors.pointText),
                    ),
                  ),
                  Text(after, style: style),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                '내가 말한 문장',
                style: TextStyle(fontSize: 13, color: AppColors.onPrimaryMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    const body = TextStyle(
      fontSize: 14,
      height: 1.5,
      color: AppColors.textBody,
    );
    const bold = TextStyle(fontWeight: FontWeight.w700);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 6),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$score',
                      style: const TextStyle(
                        fontSize: 22,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const Text(
                      '점',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.2,
                        color: AppColors.textBody,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '거의 다 왔어요!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        style: body,
                        children: [
                          TextSpan(text: '‘구이'),
                          TextSpan(text: '용', style: bold),
                          TextSpan(text: '으로’의 '),
                          TextSpan(text: 'ㅇ 받침', style: bold),
                          TextSpan(text: '을 또렷하게 말해 보세요.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: IjuButton(
                  label: '정답 듣기',
                  type: IjuButtonType.secondary,
                  height: 44,
                  radius: 12,
                  fontSize: 14,
                  onPressed: () {
                    // TODO(개발자2): 정답 문장 TTS
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: IjuButton(
                  label: '천천히 듣기',
                  type: IjuButtonType.secondary,
                  height: 44,
                  radius: 12,
                  fontSize: 14,
                  onPressed: () {
                    // TODO(개발자2): 느린 속도 TTS
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 녹음 중임을 보여주는 막대 7개 (Figma 'Waveform').
class _Waveform extends StatelessWidget {
  const _Waveform();

  static const _heights = <double>[10, 20, 28, 16, 24, 12, 20];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _heights.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Container(
              width: 4,
              height: _heights[i],
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const SizedBox(
          width: 80,
          height: 80,
          child: Center(child: IjuIcon(IjuIcons.mic, size: 32)),
        ),
      ),
    );
  }
}
