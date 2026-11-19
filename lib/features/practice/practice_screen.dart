import 'dart:async';
import 'dart:math' as math;

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/router.dart';
import '../../widgets/bold_quoted.dart';
import '../../widgets/iju_button.dart';
import '../../widgets/iju_header.dart';
import '../../widgets/iju_icon.dart';
import '../scenario/scenarios.dart';
import 'practice_api.dart';
import 'speech.dart';

/// 문장 조립 화면에서 넘겨받는 연습 문장과 시나리오.
class PracticeArgs {
  const PracticeArgs({
    required this.sentence,
    required this.meaning,
    this.scenario = butcher,
  });

  final String sentence;
  final String meaning;
  final Scenario scenario;

  /// 바로 이 화면으로 들어왔을 때(주소 직접 입력, 테스트) 쓰는 시연 문장.
  static const demo = PracticeArgs(
    sentence: '삼겹살 600그램 구이용으로 주세요.',
    meaning: 'Cho tôi 600g thịt ba chỉ để nướng.',
  );
}

/// 사장님 대사 한 턴과 그에 맞는 손님 대답.
class _Turn {
  const _Turn({
    required this.ai,
    required this.aiMeaning,
    required this.target,
    required this.targetMeaning,
  });

  final String ai;
  final String aiMeaning;
  final String target;
  final String targetMeaning;
}

/// 한 번 말한 결과.
class _Attempt {
  const _Attempt(this.result);
  final PronunciationResult result;
}

enum _MicState { idle, listening, scoring }

/// Figma '5 음성 연습'. AI 사장님과 주고받고 발음 점수를 받습니다. 담당: 개발자2
///
/// 마이크 → 기기 음성인식(speech_to_text) → POST /ai/pronunciation 채점·조언.
/// 듣기·정답 듣기는 기기 TTS(flutter_tts)로 재생합니다.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key, this.args = PracticeArgs.demo});

  final PracticeArgs args;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  /// 이만큼 맞히면 다음 턴으로 넘어갑니다.
  static const _passScore = 80;

  /// 시나리오 대사. 대답이 정해지지 않은 턴은 문장 조립에서 만든 문장을 씁니다.
  late final List<_Turn> _turns = [
    for (final t in widget.args.scenario.turns)
      _Turn(
        ai: t.ai,
        aiMeaning: tr(t.aiMeaning),
        target: t.target ?? widget.args.sentence,
        targetMeaning: t.targetMeaning != null
            ? tr(t.targetMeaning!)
            : widget.args.meaning,
      ),
  ];

  final _speech = Speech();
  final _scroll = ScrollController();

  /// 지금 진행 중인 턴 번호.
  int _turn = 0;

  /// 턴별 마지막 시도. 다시 말하면 덮어씁니다.
  final Map<int, _Attempt> _attempts = {};

  _MicState _mic = _MicState.idle;
  String _partial = '';
  double _level = 0;

  bool get _finished =>
      _turn == _turns.length - 1 &&
      (_attempts[_turn]?.result.score ?? 0) >= _passScore;

  @override
  void dispose() {
    _speech.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _speak(String text, {bool slow = false}) async {
    try {
      await _speech.speak(text, slow: slow);
    } on Exception {
      if (mounted) _toast('이 기기에서는 소리를 재생할 수 없어요.');
    }
  }

  Future<void> _onMic() async {
    switch (_mic) {
      case _MicState.listening:
        await _speech.stop(); // 결과는 listen의 onDone으로 옵니다.
      case _MicState.scoring:
        return;
      case _MicState.idle:
        await _startListening();
    }
  }

  Future<void> _startListening() async {
    setState(() {
      _mic = _MicState.listening;
      _partial = '';
      _level = 0;
    });
    bool started;
    try {
      started = await _speech.listen(
        onWords: (w) => setState(() => _partial = w),
        onLevel: (l) => _level = l,
        onDone: _onHeard,
      );
    } on Exception {
      started = false;
    }
    if (!started && mounted) {
      setState(() => _mic = _MicState.idle);
      _toast('마이크를 쓸 수 없어요. 마이크 권한을 허용해 주세요.');
    }
  }

  Future<void> _onHeard(String words) async {
    if (!mounted) return;
    if (words.trim().isEmpty) {
      setState(() => _mic = _MicState.idle);
      _toast('잘 들리지 않았어요. 마이크를 누르고 다시 말해 볼까요?');
      return;
    }
    setState(() => _mic = _MicState.scoring);
    final turn = _turn;
    final result = await PracticeApi.score(
      transcript: words,
      target: _turns[turn].target,
    );
    if (!mounted) return;
    setState(() {
      _attempts[turn] = _Attempt(result);
      _mic = _MicState.idle;
      _partial = '';
    });
    _scrollToEnd();

    if (result.score >= _passScore && turn < _turns.length - 1) {
      // 잘 말했으면 잠깐 점수를 보여 준 뒤 사장님이 다음 말을 합니다.
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (!mounted || _turn != turn) return;
      setState(() => _turn = turn + 1);
      _scrollToEnd();
      unawaited(_speak(_turns[_turn].ai));
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  String get _micHint => switch (_mic) {
    _MicState.listening => '듣고 있어요 · 다 말하면 눌러요',
    _MicState.scoring => '채점하고 있어요…',
    _MicState.idle when _attempts.containsKey(_turn) => '눌러서 다시 말하기',
    _MicState.idle => '눌러서 말하기',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IjuHeader(
              title: 'AI 사장님과 연습',
              subtitle: _finished
                  ? '${widget.args.scenario.place} 상황 · 연습 완료'
                  : '${widget.args.scenario.place} 상황 · ${_turn + 1}/${_turns.length} 턴',
              backgroundColor: AppColors.surface,
            ),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                children: [for (var t = 0; t <= _turn; t++) ..._turnWidgets(t)],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                children: [
                  _Waveform(
                    active: _mic == _MicState.listening,
                    level: () => _level,
                  ),
                  const SizedBox(height: 10),
                  _MicButton(state: _mic, onTap: _onMic),
                  const SizedBox(height: 10),
                  Text(
                    _micHint,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textBody,
                    ),
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

  List<Widget> _turnWidgets(int t) {
    final turn = _turns[t];
    final attempt = _attempts[t];
    final current = t == _turn;
    return [
      if (t > 0) const SizedBox(height: 14),
      _AiBubble(
        text: turn.ai,
        translation: turn.aiMeaning,
        onListen: () => _speak(turn.ai),
      ),
      const SizedBox(height: 14),
      if (current && _mic != _MicState.idle && _partial.isNotEmpty)
        _UserBubble(words: _partial, wrongWords: const [], partial: true)
      else if (attempt != null)
        _UserBubble(
          words: attempt.result.transcript,
          wrongWords: attempt.result.wrongWords,
        )
      else
        _TargetHint(
          sentence: turn.target,
          meaning: turn.targetMeaning,
          onListen: () => _speak(turn.target),
        ),
      if (attempt != null) ...[
        const SizedBox(height: 14),
        _ScoreCard(
          result: attempt.result,
          onListen: () => _speak(turn.target),
          onListenSlow: () => _speak(turn.target, slow: true),
        ),
      ],
    ];
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
                  if (translation.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      translation,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSub,
                      ),
                    ),
                  ],
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
  const _ListenButton({required this.onTap, this.label = '듣기'});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const StadiumBorder(side: BorderSide(color: AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 32,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const IjuIcon(IjuIcons.speaker, size: 14),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(fontSize: 13, color: AppColors.text),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 아직 말하기 전: 이렇게 말해 보라는 안내 (오른쪽, 점선 대신 연한 초록).
class _TargetHint extends StatelessWidget {
  const _TargetHint({
    required this.sentence,
    required this.meaning,
    required this.onListen,
  });

  final String sentence;
  final String meaning;
  final VoidCallback onListen;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 270),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.primary),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '이렇게 말해 보세요',
                style: TextStyle(fontSize: 13, color: AppColors.primaryDark),
              ),
              const SizedBox(height: 6),
              Text(
                sentence,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              if (meaning.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  meaning,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSub,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              _ListenButton(onTap: onListen, label: '먼저 듣기'),
            ],
          ),
        ),
      ),
    );
  }
}

/// 내가 말한 문장. 틀린 어절은 주황 배경으로 표시합니다.
class _UserBubble extends StatelessWidget {
  const _UserBubble({
    required this.words,
    required this.wrongWords,
    this.partial = false,
  });

  final String words;
  final List<String> wrongWords;

  /// 말하는 중(중간 인식 결과)
  final bool partial;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w500,
      color: Colors.white,
    );
    final wrong = wrongWords.toSet();

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
                  for (final w in words.split(RegExp(r'\s+')))
                    if (wrong.contains(w))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: AppColors.pointBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          w,
                          style: style.copyWith(color: AppColors.pointText),
                        ),
                      )
                    else
                      Text(w, style: style),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                partial ? '듣는 중…' : '내가 말한 문장',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.onPrimaryMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.result,
    required this.onListen,
    required this.onListenSlow,
  });

  final PronunciationResult result;
  final VoidCallback onListen;
  final VoidCallback onListenSlow;

  String get _title => switch (result.score) {
    >= 95 => '완벽해요!',
    >= 80 => '아주 좋아요!',
    >= 60 => '거의 다 왔어요!',
    _ => '한 번 더 해 볼까요?',
  };

  @override
  Widget build(BuildContext context) {
    const body = TextStyle(
      fontSize: 14,
      height: 1.5,
      color: AppColors.textBody,
    );

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
                  border: Border.all(
                    color: result.score >= 60
                        ? AppColors.primary
                        : AppColors.accent,
                    width: 6,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${result.score}',
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        style: body,
                        children: boldQuoted(result.feedback),
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
                  onPressed: onListen,
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
                  onPressed: onListenSlow,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 녹음 중임을 보여주는 막대 7개 (Figma 'Waveform'). 듣는 동안만 움직입니다.
class _Waveform extends StatefulWidget {
  const _Waveform({required this.active, required this.level});

  final bool active;

  /// 기기가 알려 주는 소리 크기(dB 비슷한 값, 대략 -2~10). 웹에서는 0.
  final double Function() level;

  @override
  State<_Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<_Waveform>
    with SingleTickerProviderStateMixin {
  static const _heights = <double>[10, 20, 28, 16, 24, 12, 20];

  late final _ticker = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _ticker.repeat();
  }

  @override
  void didUpdateWidget(_Waveform old) {
    super.didUpdateWidget(old);
    if (widget.active && !_ticker.isAnimating) {
      _ticker.repeat();
    } else if (!widget.active && _ticker.isAnimating) {
      _ticker.stop();
      _ticker.value = 0;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: AnimatedBuilder(
        animation: _ticker,
        builder: (context, _) {
          // 소리 크기를 0.5~1로 바꿔 막대 높이에 곱합니다.
          final loud = 0.5 + (widget.level().clamp(0, 10) / 20);
          return Opacity(
            opacity: widget.active ? 1 : 0.35,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _heights.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Container(
                    width: 4,
                    height: widget.active
                        ? math.max(
                            4,
                            _heights[i] *
                                loud *
                                (0.55 +
                                    0.45 *
                                        math
                                            .sin(
                                              (_ticker.value + i / 7) *
                                                  2 *
                                                  math.pi,
                                            )
                                            .abs()),
                          )
                        : _heights[i],
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.state, required this.onTap});

  final _MicState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final listening = state == _MicState.listening;
    return Material(
      color: listening ? AppColors.primaryDark : AppColors.primary,
      shape: CircleBorder(
        side: listening
            ? const BorderSide(color: AppColors.onPrimaryMuted, width: 4)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: state == _MicState.scoring ? null : onTap,
        child: SizedBox(
          width: 80,
          height: 80,
          child: Center(
            child: state == _MicState.scoring
                ? const SizedBox.square(
                    dimension: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                    ),
                  )
                : const IjuIcon(IjuIcons.mic, size: 32),
          ),
        ),
      ),
    );
  }
}
