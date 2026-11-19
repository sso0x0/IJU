import 'package:material_ui/material_ui.dart';

import '../app/languages.dart';

import '../app/colors.dart';
import '../app/theme.dart';
import '../features/scenario/menu_ingredients.dart' show ingredientsFor;
import '../features/scenario/scenarios.dart' show Ingredient;
import '../app/diet.dart';

/// 메뉴 판정 3단계. 색만으로 구분하지 않고 아이콘 + 글자 + 색을 함께 씁니다.
enum Verdict {
  safe('먹어도 돼요', 'Ăn được', Icons.check_circle_outline),
  ask('물어보세요', 'Hãy hỏi', Icons.help_outline),
  avoid('피하세요', 'Nên tránh', Icons.block);

  const Verdict(this.label, this._native, this.icon);

  final String label;
  final String _native;

  /// 사용자 언어로 된 판정 이름
  String get native => nt(_native);
  final IconData icon;

  Color get fg => switch (this) {
    safe => AppColors.safe,
    ask => AppColors.cautionText,
    avoid => AppColors.dangerText,
  };

  Color get bg => switch (this) {
    safe => AppColors.safeBg,
    ask => AppColors.cautionBg,
    avoid => AppColors.dangerBg,
  };

  /// 어두운 칠판 메뉴판 위에 그리는 판정 테두리 색.
  Color get onBoard => switch (this) {
    safe => AppColors.boardSafe,
    ask => AppColors.caution,
    avoid => AppColors.boardDanger,
  };
}

/// 한 메뉴의 판정 + 이유 한 줄 + 걸리는 재료.
class MenuVerdict {
  const MenuVerdict(this.verdict, this.reason, this.hits);

  final Verdict verdict;
  final String reason;

  /// 내 조건에 걸리는 재료 (숨어 있을 수 있는 재료는 [Ingredient.hidden]).
  final List<Ingredient> hits;

  /// 고른 식단이 없으면 null (판정하지 않음).
  ///
  /// 주재료가 걸리면 '피하세요', 국물·양념에 숨어 있거나 빼 달라고 할 수 있는
  /// 재료가 걸리면 '물어보세요'. 모르면 추측하지 않고 '물어보세요'.
  static MenuVerdict? of(String menu, Set<Diet> diets) {
    if (diets.isEmpty) return null;
    final ingredients = ingredientsFor(menu);
    final hits = [
      for (final i in ingredients)
        // 고기가 안 보이는 요리마다 붙는 막연한 '고기?'는 판정에 쓰지 않아요
        // (문장 만들기에서 '고기 들어가요?'로 따로 물어볼 수 있어요).
        if (!(i.hidden && i.label == '고기') && i.conflictsWith(diets).isNotEmpty)
          i,
    ];
    if (ingredients.isEmpty) {
      return const MenuVerdict(Verdict.ask, '재료를 확인하지 못했어요', []);
    }
    if (hits.isEmpty) {
      return const MenuVerdict(Verdict.safe, '내 조건에 걸리는 재료가 없어요', []);
    }
    final names = hits.map((i) => i.label).take(2).join('·');
    if (hits.any((i) => i.main)) {
      return MenuVerdict(Verdict.avoid, '$names${_eun(names)} 들어가요', hits);
    }
    if (hits.every((i) => i.hidden)) {
      return MenuVerdict(Verdict.ask, '$names${_eun(names)} 들어갈 수 있어요', hits);
    }
    return MenuVerdict(
      Verdict.ask,
      '$names${_eun(names)} 들어가요 · 빼 달라고 해 보세요',
      hits,
    );
  }

  /// 받침에 따라 '이'/'가'.
  static String _eun(String word) {
    if (word.isEmpty) return '이';
    final c = word.codeUnitAt(word.length - 1);
    if (c < 0xAC00 || c > 0xD7A3) return '이';
    return (c - 0xAC00) % 28 == 0 ? '가' : '이';
  }
}

/// 판정 배지. [large]는 상세·판정 요약용 (48 높이 + 모국어).
/// [native]면 작은 배지에도 모국어를 작게 붙입니다 (메뉴 카드).
class VerdictBadge extends StatelessWidget {
  const VerdictBadge(
    this.verdict, {
    super.key,
    this.large = false,
    this.native = false,
  });

  final Verdict verdict;
  final bool large;
  final bool native;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: large ? 48 : 32,
      padding: EdgeInsets.fromLTRB(large ? 14 : 9, 0, large ? 18 : 12, 0),
      decoration: BoxDecoration(
        color: verdict.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(verdict.icon, size: large ? 24 : 18, color: verdict.fg),
          SizedBox(width: large ? 8 : 6),
          Text(
            verdict.label,
            style: TextStyle(
              fontSize: large ? 20 : 15,
              fontWeight: FontWeight.w700,
              color: verdict.fg,
            ),
          ),
          if (large || native) ...[
            SizedBox(width: large ? 8 : 5),
            Text(
              '· ${verdict.native}',
              style: AppText.native.copyWith(
                fontSize: large ? 15 : 12,
                fontWeight: large ? FontWeight.w500 : FontWeight.w400,
                color: verdict.fg.withValues(alpha: 0.9),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 인식 신뢰도 낮음: 회색 점선 + "확인해 주세요".
class CheckPill extends StatelessWidget {
  const CheckPill({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.warnBorder, width: 1.5),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.visibility_outlined, size: 15, color: AppColors.warnText),
          SizedBox(width: 5),
          Text(
            '확인해 주세요',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.warnText,
            ),
          ),
        ],
      ),
    );
  }
}
