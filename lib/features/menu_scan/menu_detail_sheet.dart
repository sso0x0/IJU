import 'package:material_ui/material_ui.dart';

import '../../app/languages.dart';

import '../../app/colors.dart';
import '../../app/session.dart';
import '../../app/theme.dart';
import '../../widgets/iju_button.dart';
import '../../widgets/verdict_badge.dart';
import '../practice/speech.dart';
import '../scenario/menu_ingredients.dart' show ingredientsFor;
import '../scenario/scenarios.dart' show Ingredient;
import 'menu_scan_api.dart';

/// C5 메뉴 상세 시트.
///
/// 판정 · 재료(확실히 들어가요 / 숨어 있을 수 있어요) · 사장님께 물어볼 말을 보여 줍니다.
/// 재료와 판정은 재료 사전([ingredientsFor])으로 계산합니다.
Future<void> showMenuDetailSheet(BuildContext context, MenuCardData menu) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _MenuDetailSheet(menu: menu),
  );
}

/// 숨은 재료를 사장님께 물어보는 말. 없으면 무엇이 들어가는지 묻습니다.
String askOwnerSentence(List<Ingredient> ingredients) {
  final maybe = ingredients.where((i) => i.hidden).toList();
  if (maybe.isEmpty) return '이거 뭐 들어가요?';
  final first = maybe.first.label;
  if (first.endsWith('육수')) {
    return '국물에 ${first.replaceAll(' 육수', '')} 들어가요?';
  }
  return '$first 들어가요?';
}

class _MenuDetailSheet extends StatefulWidget {
  const _MenuDetailSheet({required this.menu});

  final MenuCardData menu;

  @override
  State<_MenuDetailSheet> createState() => _MenuDetailSheetState();
}

class _MenuDetailSheetState extends State<_MenuDetailSheet> {
  final _speech = Speech();

  @override
  void dispose() {
    _speech.dispose();
    super.dispose();
  }

  Future<void> _speak(String text, {bool slow = false}) async {
    try {
      await _speech.speak(text, slow: slow);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('이 기기에서는 소리를 낼 수 없어요')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final menu = widget.menu;
    final verdict = MenuVerdict.of(menu.name, AppSession.diets.value);
    final ingredients = ingredientsFor(menu.name);
    final sure = [
      for (final i in ingredients)
        if (!i.hidden) i,
    ];
    final maybe = [
      for (final i in ingredients)
        if (i.hidden) i,
    ];
    final hits = <String, bool>{
      for (final h in verdict?.hits ?? const <Ingredient>[]) h.label: h.main,
    };
    final ask = askOwnerSentence(ingredients);

    Widget chips(List<Ingredient> list) => Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final i in list)
          IngredientChip.of(
            i,
            verdict: switch (hits[i.label]) {
              true => Verdict.avoid,
              false => Verdict.ask,
              null => null,
            },
          ),
      ],
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          if (verdict != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: VerdictBadge(verdict.verdict, large: true),
            ),
            const SizedBox(height: 10),
            Text(
              verdict.reason,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: verdict.verdict.fg,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      menu.name,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        height: 1.25,
                        color: AppColors.text,
                      ),
                    ),
                    if (menu.romanization != null)
                      Text(menu.romanization!, style: AppText.romanization),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ListenPill(onTap: () => _speak(menu.name)),
            ],
          ),
          if (menu.meaning != null) ...[
            const SizedBox(height: 10),
            Text(
              menu.meaning!,
              style: AppText.native.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
          if (menu.description != null) ...[
            const SizedBox(height: 2),
            Text(menu.description!, style: AppText.native),
          ],
          if (sure.isNotEmpty) ...[
            const SizedBox(height: 18),
            _Label('확실히 들어가요', nt('Chắc chắn có')),
            const SizedBox(height: 8),
            chips(sure),
          ],
          if (maybe.isNotEmpty) ...[
            const SizedBox(height: 16),
            _Label('숨어 있을 수 있어요', nt('Có thể có')),
            const SizedBox(height: 8),
            chips(maybe),
          ],
          const SizedBox(height: 20),
          Material(
            color: AppColors.primary50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
              side: const BorderSide(color: AppColors.primarySoft),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _speak(ask, slow: true),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: '사장님께 물어볼 말',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                        children: [
                          TextSpan(
                            text: ' · Hỏi chủ quán',
                            style: AppText.native.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ask,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.3,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Icon(
                          Icons.volume_up_outlined,
                          size: 16,
                          color: AppColors.textSub,
                        ),
                        SizedBox(width: 4),
                        Text('누르면 천천히 들려줘요', style: AppText.caption),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          IjuButton(
            label: '이 말 연습하기',
            sub: nt('Luyện câu này'),
            icon: Icons.mic_none,
            onPressed: () => ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(content: Text('이 말 연습하기 · 아직 준비 중이에요')),
              ),
          ),
        ],
      ),
    );
  }
}

/// '듣기 · Nghe' 알약 버튼 (초록 옅은 바탕).
class _ListenPill extends StatelessWidget {
  const _ListenPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary50,
      shape: const StadiumBorder(
        side: BorderSide(color: AppColors.primarySoft, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: SizedBox(
            height: 44,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.volume_up_outlined,
                  size: 20,
                  color: AppColors.primaryDark,
                ),
                const SizedBox(width: 6),
                const Text(
                  '듣기',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                Text(
                  ' · ${nt('Nghe')}',
                  style: AppText.native.copyWith(
                    fontSize: 13,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.ko, this.native);

  final String ko;
  final String native;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: ko,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: AppColors.text,
        ),
        children: [
          TextSpan(
            text: ' · $native',
            style: AppText.native.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.textSub,
            ),
          ),
        ],
      ),
    );
  }
}
