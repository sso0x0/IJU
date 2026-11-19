import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/languages.dart';
import '../../app/theme.dart';
import '../../widgets/hand_drawn_frame.dart';
import '../../widgets/iju_button.dart';
import '../practice/practice_api.dart';
import '../practice/speech.dart';
import 'review_store.dart';

/// 복습 화면으로 넘기는 값.
class ReviewStepsArgs {
  const ReviewStepsArgs({
    required this.sentence,
    required this.meaning,
    this.reviewId,
    this.stage,
  });

  final String sentence;
  final String meaning;

  /// 복습 목록의 문장이면 그 id와 단계 (끝내면 그 단계를 기록해요).
  final String? reviewId;
  final ReviewStage? stage;
}

/// 복습: E1~E4처럼 도움을 단계적으로 줄여 가며 말해요. 담당: 개발자1
///
/// 1단계 보여주기 → 2단계 따라 말하기 → 3단계 빈칸 말하기 → 4단계 혼자 말하기.
/// 2~4단계는 마이크로 말하면 채점하고, 잘 말하면(80점 이상) 다음 단계가 열려요.
/// 4단계를 끝내면 복습 목록에 이 단계를 끝낸 것으로 기록합니다 (복습 목록에 없던 문장은 넣어요).
class ReviewStepsScreen extends StatefulWidget {
  const ReviewStepsScreen({super.key, required this.args});

  final ReviewStepsArgs args;

  @override
  State<ReviewStepsScreen> createState() => _ReviewStepsScreenState();
}

const _passScore = 80;

/// 단계 이름 (한국어, 베트남어 원문)
const _stepNames = [
  ('보여주기', 'Cho xem'),
  ('따라 말하기', 'Nói theo'),
  ('빈칸 말하기', 'Điền chỗ trống'),
  ('혼자 말하기', 'Tự nói'),
];

enum _Mic { idle, listening, scoring }

class _ReviewStepsScreenState extends State<ReviewStepsScreen> {
  final _speech = Speech();
  int _step = 0;

  /// 지금까지 열린 단계 (0~3)
  int _unlocked = 0;
  bool _done = false;
  bool _showAll = false;
  _Mic _mic = _Mic.idle;
  String _heard = '';
  PronunciationResult? _result;
  final List<int> _scores = [];

  late final List<String> _words = widget.args.sentence.trim().split(
    RegExp(r'\s+'),
  );

  /// 3단계에서 가리는 어절: 처음 어절은 남기고 가운데를 가려요 (마지막 '주세요'류도 남김).
  late final Set<int> _blanks = {
    if (_words.length <= 2)
      _words.length - 1
    else
      for (var i = 1; i < _words.length - 1; i++) i,
  };

  @override
  void dispose() {
    _speech.dispose();
    super.dispose();
  }

  void _toast(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _speak({bool slow = false}) async {
    try {
      await _speech.speak(widget.args.sentence, slow: slow);
    } catch (_) {
      _toast('이 기기에서는 소리를 낼 수 없어요');
    }
  }

  void _go(int step) => setState(() {
    _step = step;
    _unlocked = step > _unlocked ? step : _unlocked;
    _showAll = false;
    _heard = '';
    _result = null;
  });

  Future<void> _onMic() async {
    switch (_mic) {
      case _Mic.listening:
        await _speech.stop();
      case _Mic.scoring:
        return;
      case _Mic.idle:
        setState(() {
          _mic = _Mic.listening;
          _heard = '';
          _result = null;
        });
        bool started;
        try {
          started = await _speech.listen(
            onWords: (w) => setState(() => _heard = w),
            onDone: _onHeard,
          );
        } catch (_) {
          started = false;
        }
        if (!started && mounted) {
          setState(() => _mic = _Mic.idle);
          _toast('마이크를 쓸 수 없어요. 마이크 권한을 허용해 주세요.');
        }
    }
  }

  Future<void> _onHeard(String words) async {
    if (!mounted) return;
    if (words.trim().isEmpty) {
      setState(() => _mic = _Mic.idle);
      _toast('잘 들리지 않았어요. 다시 말해 볼까요?');
      return;
    }
    setState(() => _mic = _Mic.scoring);
    final result = await PracticeApi.score(
      transcript: words,
      target: widget.args.sentence,
    );
    if (!mounted) return;
    setState(() {
      _mic = _Mic.idle;
      _result = result;
      _heard = result.transcript;
    });
    if (result.score >= _passScore) {
      _scores.add(result.score);
      if (_step == 3) _finish();
    }
  }

  void _finish() {
    final args = widget.args;
    final score = _scores.isEmpty
        ? null
        : _scores.reduce((a, b) => a < b ? a : b);
    if (args.reviewId case final id?) {
      ReviewStore.complete(id, args.stage ?? ReviewStage.same, score: score);
    } else {
      ReviewStore.add(
        sentence: args.sentence,
        meaning: args.meaning,
        score: score,
      );
    }
    setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    final (ko, vi) = _stepNames[_step];
    final passed = (_result?.score ?? 0) >= _passScore;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              title: '${_step + 1}단계 · $ko',
              sub: '${nt('Bước {n}', {'n': _step + 1})} · ${nt(vi)}',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  if (_done)
                    _DoneCard(stage: widget.args.stage)
                  else
                    ...switch (_step) {
                      0 => _showStep(),
                      1 => _repeatStep(),
                      2 => _blankStep(),
                      _ => _aloneStep(),
                    },
                  if (_step > 0 && !_done && _heard.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _Heard(text: _heard, result: _result),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_step > 0 && !_done) ...[
                    Center(
                      child: _MicButton(state: _mic, onTap: _onMic),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      switch (_mic) {
                        _Mic.listening => '듣고 있어요 · 다 말하면 눌러요',
                        _Mic.scoring => '채점하고 있어요…',
                        _Mic.idle => '누르고 말하기 · ${nt('Nhấn để nói')}',
                      },
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textBody,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _StepTabs(
                    current: _step,
                    unlocked: _done ? 3 : _unlocked,
                    onTap: _go,
                  ),
                  const SizedBox(height: 12),
                  if (_done)
                    IjuButton(
                      label: '복습 끝내기',
                      sub: nt('Xong'),
                      onPressed: () => context.pop(),
                    )
                  else if (_step == 0 || (passed && _step < 3))
                    IjuButton(
                      label: '다음 단계',
                      sub: nt('Bước tiếp theo'),
                      icon: Icons.chevron_right,
                      onPressed: () => _go(_step + 1),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- 1단계

  List<Widget> _showStep() => [
    HandDrawnFrame(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '이 문장을 다시 볼게요 · ${nt('Xem lại câu này')}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.args.sentence,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              height: 1.3,
              letterSpacing: -0.6,
              color: AppColors.text,
            ),
          ),
          if (widget.args.meaning.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(widget.args.meaning, style: AppText.native),
          ],
        ],
      ),
    ),
    const SizedBox(height: 16),
    _ListenRow(onListen: _speak, onSlow: () => _speak(slow: true)),
  ];

  // ---------------------------------------------------------------- 2단계

  List<Widget> _repeatStep() => [
    _Guide('들은 대로 따라 말해 보세요', nt('Nghe rồi nói theo')),
    const SizedBox(height: 12),
    Text(
      widget.args.sentence,
      style: const TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        height: 1.35,
        letterSpacing: -0.5,
        color: AppColors.text,
      ),
    ),
    if (widget.args.meaning.isNotEmpty) ...[
      const SizedBox(height: 8),
      Text(widget.args.meaning, style: AppText.native),
    ],
    const SizedBox(height: 16),
    _ListenRow(onListen: _speak, onSlow: () => _speak(slow: true)),
  ];

  // ---------------------------------------------------------------- 3단계

  List<Widget> _blankStep() => [
    _Guide('빈칸까지 채워서 말해 보세요', nt('Nói cả phần còn trống')),
    const SizedBox(height: 14),
    Wrap(
      spacing: 8,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        for (var i = 0; i < _words.length; i++)
          if (_blanks.contains(i) && !_showAll)
            Container(
              width: (_words[i].length * 26 + 16).clamp(56, 200).toDouble(),
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.pointBg,
                border: Border(
                  bottom: BorderSide(color: AppColors.accent, width: 3),
                ),
              ),
            )
          else
            Text(
              _words[i],
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                height: 1.35,
                color: _blanks.contains(i)
                    ? AppColors.pointText
                    : AppColors.text,
              ),
            ),
      ],
    ),
    if (widget.args.meaning.isNotEmpty) ...[
      const SizedBox(height: 12),
      Text(widget.args.meaning, style: AppText.native),
    ],
    const SizedBox(height: 14),
    Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => setState(() => _showAll = !_showAll),
        icon: Icon(
          _showAll ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        ),
        label: Text(_showAll ? '빈칸 다시 가리기' : '막히면 전체 보기 · ${nt('Xem cả câu')}'),
      ),
    ),
  ];

  // ---------------------------------------------------------------- 4단계

  List<Widget> _aloneStep() => [
    _Guide('뜻만 보고 한국어로 말해 보세요', nt('Chỉ xem nghĩa rồi nói bằng tiếng Hàn')),
    const SizedBox(height: 14),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final w in _words)
          Container(
            width: (w.length * 22 + 20).clamp(52, 160).toDouble(),
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.skeleton,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
      ],
    ),
    const SizedBox(height: 14),
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('뜻 · ${nt('Nghĩa')}', style: AppText.caption),
          const SizedBox(height: 6),
          Text(
            widget.args.meaning.isEmpty
                ? '(뜻이 없어요. 문장을 떠올려 말해 보세요)'
                : widget.args.meaning,
            style: AppText.native.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 10),
    Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => _go(2),
        icon: const Icon(Icons.chevron_left),
        label: Text('막히면 3단계로 · ${nt('Quay lại bước 3')}'),
      ),
    ),
  ];
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.sub, required this.onBack});

  final String title;
  final String sub;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            tooltip: '뒤로',
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  sub,
                  style: AppText.native.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSub,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _Guide extends StatelessWidget {
  const _Guide(this.ko, this.native);

  final String ko;
  final String native;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ko,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryDark,
          ),
        ),
        Text(
          native,
          style: AppText.native.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppColors.textSub,
          ),
        ),
      ],
    );
  }
}

class _ListenRow extends StatelessWidget {
  const _ListenRow({required this.onListen, required this.onSlow});

  final VoidCallback onListen;
  final VoidCallback onSlow;

  @override
  Widget build(BuildContext context) {
    Widget pill(String label, String sub, VoidCallback onTap) => Material(
      color: AppColors.primary50,
      shape: const StadiumBorder(
        side: BorderSide(color: AppColors.primarySoft, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.volume_up_outlined,
                size: 18,
                color: AppColors.primaryDark,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
              Text(
                ' · $sub',
                style: AppText.native.copyWith(
                  fontSize: 12,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        pill('듣기', nt('Nghe'), onListen),
        pill('천천히', nt('Chậm'), onSlow),
      ],
    );
  }
}

/// 내가 말한 문장과 점수.
class _Heard extends StatelessWidget {
  const _Heard({required this.text, required this.result});

  final String text;
  final PronunciationResult? result;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final passed = (r?.score ?? 0) >= _passScore;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: r == null
            ? AppColors.background
            : passed
            ? AppColors.safeBg
            : AppColors.pointBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            r == null
                ? '듣는 중…'
                : (passed ? '잘했어요! ${r.score}점' : '${r.score}점 · 한 번 더!'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: r == null
                  ? AppColors.textSub
                  : passed
                  ? AppColors.safe
                  : AppColors.pointText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 18, color: AppColors.text),
          ),
          if (r != null && !passed && r.feedback.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(r.feedback, style: AppText.caption),
          ],
        ],
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.state, required this.onTap});

  final _Mic state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final listening = state == _Mic.listening;
    return Semantics(
      button: true,
      label: '말하기',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: listening ? AppColors.danger : AppColors.primary,
            boxShadow: const [
              BoxShadow(
                color: Color(0x40003F2E),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: state == _Mic.scoring
              ? const Padding(
                  padding: EdgeInsets.all(22),
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  listening ? Icons.stop : Icons.mic_none,
                  color: Colors.white,
                  size: 32,
                ),
        ),
      ),
    );
  }
}

/// 아래 4단계 칸. 열린 단계만 누를 수 있어요.
class _StepTabs extends StatelessWidget {
  const _StepTabs({
    required this.current,
    required this.unlocked,
    required this.onTap,
  });

  final int current;
  final int unlocked;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _stepNames.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: _tab(i)),
        ],
      ],
    );
  }

  Widget _tab(int i) {
    final (ko, vi) = _stepNames[i];
    final on = i == current;
    final done = i < current || (i <= unlocked && i != current && i < unlocked);
    final open = i <= unlocked;
    final fg = on
        ? Colors.white
        : (open ? AppColors.primaryDark : AppColors.textSub);
    return Material(
      color: on
          ? AppColors.primary
          : done
          ? AppColors.primarySoft
          : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: on || done ? Colors.transparent : AppColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: open ? () => onTap(i) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${done ? '✓ ' : ''}${i + 1}단계',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
              Text(
                ko,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
              Text(
                nt(vi),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.native.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoneCard extends StatelessWidget {
  const _DoneCard({required this.stage});

  final ReviewStage? stage;

  @override
  Widget build(BuildContext context) {
    final days = (stage ?? ReviewStage.same).waitDays;
    return HandDrawnFrame(
      child: Column(
        children: [
          const Icon(
            Icons.emoji_events_outlined,
            size: 48,
            color: AppColors.accent,
          ),
          const SizedBox(height: 10),
          const Text('혼자 말하기까지 끝냈어요!', style: AppText.subtitle),
          const SizedBox(height: 4),
          Text(
            nt('Bạn đã tự nói được rồi!'),
            style: AppText.native.copyWith(color: AppColors.textSub),
          ),
          const SizedBox(height: 10),
          Text(
            '$days일 뒤에 다시 복습해요',
            style: const TextStyle(fontSize: 15, color: AppColors.textBody),
          ),
        ],
      ),
    );
  }
}
