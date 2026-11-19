import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/router.dart';
import '../../widgets/dashed_border.dart';
import '../../widgets/iju_button.dart';
import '../../widgets/iju_header.dart';
import '../missions/missions_api.dart';
import '../reward/receipt_flow.dart';
import 'order_api.dart';

/// Figma '6 실전 주문 (4단계)'. 단계가 올라갈수록 화면에 보이는 글자가 줄어듭니다. 담당: 개발자3
/// 음성 연습에서 만든 문장을 받아 단계별로 가리고, 도달 단계는 POST /attempts로 기록합니다.
class RealOrderScreen extends StatefulWidget {
  const RealOrderScreen({super.key, this.args = RealOrderArgs.demo});

  final RealOrderArgs args;

  @override
  State<RealOrderScreen> createState() => _RealOrderScreenState();
}

class _Step {
  const _Step(this.title, this.guide, this.blanks);
  final String title;
  final String guide;

  /// 빈칸으로 가릴 단어 번호
  final Set<int> blanks;
}

/// 문장 단어. [blankWidth]는 빈칸일 때 밑줄 길이입니다.
class _Word {
  const _Word(this.text, this.blankWidth, {this.hint});
  final String text;
  final double blankWidth;
  final String? hint;
}

class _RealOrderScreenState extends State<RealOrderScreen> {
  /// Figma 시연 문장. 빈칸 길이와 힌트가 디자인에 맞춰져 있습니다.
  static const _demoWords = [
    _Word('삼겹살', 94),
    _Word('600그램', 92, hint: '무게'),
    _Word('구이용으로', 128, hint: '용도'),
    _Word('주세요.', 105),
  ];

  late final List<_Word> _words;
  late final List<_Step> _steps;
  late int _step;
  int _reached = 0; // 서버에 기록한 최고 단계 (1~4, 0이면 아직 없음)
  bool _showAll = false;
  bool _submitting = false;

  bool get _isDemo => widget.args.sentence == RealOrderArgs.demo.sentence;

  @override
  void initState() {
    super.initState();
    _words = _isDemo ? _demoWords : _wordsOf(widget.args.sentence);
    _steps = _stepsFor(_words.length);
    _step = _isDemo ? 2 : 0; // 시연은 Figma처럼 3단계에서 시작
    _record(_step);
  }

  /// 문장을 어절로 나누고, 글자 수에 맞춰 빈칸 길이를 정합니다.
  static List<_Word> _wordsOf(String sentence) => [
    for (final w in sentence.trim().split(RegExp(r'\s+')))
      _Word(w, (w.length * 30 + 12).clamp(60, 220).toDouble()),
  ];

  /// 3단계는 처음·마지막 어절만 남기고 가리고, 4단계는 전부 가립니다.
  static List<_Step> _stepsFor(int n) {
    final middle = n <= 2 ? {n - 1} : {for (var i = 1; i < n - 1; i++) i};
    return [
      const _Step('보여주기', '사장님께 화면을 그대로 보여 드려요.', {}),
      const _Step('따라 말하기', '화면의 문장을 보면서 소리 내어 말해요.', {}),
      _Step('빈칸 말하기', '빈칸은 보지 않고 직접 말해요. 단계가 올라갈수록 화면을 덜 봐요.', middle),
      _Step('혼자 말하기', '화면을 보지 않고 처음부터 끝까지 혼자 말해요.', {
        for (var i = 0; i < n; i++) i,
      }),
    ];
  }

  /// 처음 도달한 단계만 POST /attempts로 기록합니다 (같은 단계 반복 기록 방지).
  void _record(int index) {
    final step = index + 1;
    if (step <= _reached) return;
    _reached = step;
    OrderApi.saveAttempt(
      missionId: widget.args.missionId,
      step: step,
      sentence: widget.args.sentence,
    );
  }

  void _selectStep(int i) {
    setState(() {
      _step = i;
      _showAll = false;
    });
    _record(i);
  }

  Future<void> _verifyReceipt() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final result = await runReceiptFlow(
      context,
      missionId: widget.args.missionId,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result == null) return;
    CurrentMission.id = null; // 이 미션은 끝. 다음 미션 카드를 누르면 다시 채워짐
    context.push(
      AppRoutes.reward,
      extra: RewardArgs(
        result: result,
        sentence: widget.args.sentence,
        step: _reached,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_step];
    final blanks = _showAll ? const <int>{} : step.blanks;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const IjuHeader(title: '실전 주문'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < _steps.length; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: _StepTile(
                            number: i + 1,
                            title: _steps[i].title,
                            state: i < _step
                                ? _StepState.done
                                : i == _step
                                ? _StepState.current
                                : _StepState.locked,
                            onTap: () => _selectStep(i),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    step.guide,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.textBody,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SpeakCard(words: _words, blanks: blanks),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: IjuButton(
                          label: _showAll ? '빈칸 다시 가리기' : '막히면 전체 보기',
                          type: IjuButtonType.secondary,
                          height: 48,
                          radius: 12,
                          fontSize: 15,
                          onPressed: step.blanks.isEmpty
                              ? null
                              : () => setState(() => _showAll = !_showAll),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: IjuButton(
                          label: '사장님께 화면 보여주기',
                          type: IjuButtonType.secondary,
                          height: 48,
                          radius: 12,
                          fontSize: 15,
                          onPressed: () => _selectStep(0),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: IjuButton(
                label: '주문했어요 · 영수증 인증하기',
                onPressed: _submitting ? null : _verifyReceipt,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _StepState { done, current, locked }

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.number,
    required this.title,
    required this.state,
    required this.onTap,
  });

  final int number;
  final String title;
  final _StepState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, numberColor, titleColor) = switch (state) {
      _StepState.done => (
        AppColors.background,
        AppColors.textSub,
        AppColors.textBody,
      ),
      _StepState.current => (AppColors.primary, Colors.white, Colors.white),
      _StepState.locked => (
        AppColors.surface,
        AppColors.textSub,
        AppColors.textSub,
      ),
    };

    final tile = SizedBox(
      height: 64,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: switch (state) {
            _StepState.done => const BorderSide(color: AppColors.border),
            _StepState.current => const BorderSide(
              color: AppColors.primary,
              width: 2,
            ),
            _StepState.locked => BorderSide.none,
          },
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$number단계',
                style: TextStyle(fontSize: 12, color: numberColor),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return state == _StepState.locked
        ? DashedBorder(color: AppColors.borderStrong, radius: 14, child: tile)
        : tile;
  }
}

/// Figma 'SpeakCard'. 검은 카드에 큰 글씨로 문장을 보여주고, 가린 단어는 주황 밑줄로 남깁니다.
class _SpeakCard extends StatelessWidget {
  const _SpeakCard({required this.words, required this.blanks});

  final List<_Word> words;
  final Set<int> blanks;

  @override
  Widget build(BuildContext context) {
    const big = TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    );
    final hints = [for (final i in blanks) ?words[i].hint];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.text,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '사장님께 이렇게 말해 보세요',
            style: TextStyle(fontSize: 13, color: AppColors.borderStrong),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              for (var i = 0; i < words.length; i++)
                blanks.contains(i)
                    ? Container(
                        width: words[i].blankWidth,
                        height: 44,
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: AppColors.accent,
                              width: 4,
                            ),
                          ),
                        ),
                      )
                    : Text(words[i].text, style: big),
            ],
          ),
          if (hints.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final h in hints) _Hint('힌트: $h')],
            ),
          ],
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.darkChip,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          text,
          style: const TextStyle(fontSize: 14, color: AppColors.divider),
        ),
      ),
    );
  }
}
