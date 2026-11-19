import 'package:material_ui/material_ui.dart';

import '../../app/languages.dart';

import '../../app/colors.dart';
import '../../app/session.dart';
import '../../app/theme.dart';
import '../../widgets/dashed_border.dart';
import '../../widgets/verdict_badge.dart';
import '../scenario/menu_ingredients.dart' show ingredientsFor;
import 'menu_scan_api.dart';

/// 메뉴판에서 읽은 메뉴 한 개를 보여주는 카드 (C4 '결과 · 목록 보기').
///
/// 순서: 판정 배지 → 이유 한 줄 → 한국어 메뉴명(24) + 이름 고치기 연필 → 발음 →
/// 모국어 뜻 → 설명 → 재료 칩. 오른쪽 위 선택 체크(터치 48).
/// 카드를 누르면 메뉴 상세 시트([onTap]), 체크를 누르면 고르기([onSelect])입니다.
/// 손글씨라 확신이 낮은 메뉴는 회색 점선 + "확인해 주세요"를 표시합니다.
class MenuCard extends StatelessWidget {
  const MenuCard({
    super.key,
    required this.menu,
    required this.selected,
    required this.onTap,
    required this.onSelect,
    required this.onEdit,
  });

  final MenuCardData menu;
  final bool selected;

  /// 카드 누르기: 메뉴 상세 시트 (C5)
  final VoidCallback onTap;

  /// 오른쪽 위 체크: 고르기 / 빼기
  final VoidCallback onSelect;

  /// 연필: 이름 고치기 시트 (C6)
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final warn = menu.needsCheck && !selected;
    final verdict = MenuVerdict.of(menu.name, AppSession.diets.value);
    final check = _SelectCheck(
      selected: selected,
      name: menu.name,
      onTap: onSelect,
    );
    final badges = [
      if (verdict != null) VerdictBadge(verdict.verdict, native: true),
      if (warn) const CheckPill(),
    ];
    final name = _NameRow(name: menu.name, onEdit: onEdit);

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: selected
            ? const [BoxShadow(color: AppColors.primarySoft, spreadRadius: 4)]
            : null,
      ),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: selected
              ? const BorderSide(color: AppColors.primary, width: 2)
              : warn
              ? BorderSide.none
              : const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 10, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: badges.isEmpty
                          ? name
                          : Wrap(spacing: 6, runSpacing: 6, children: badges),
                    ),
                    check,
                  ],
                ),
                if (verdict != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6, bottom: 4),
                    child: Text(
                      verdict.reason,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: verdict.verdict.fg,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _Texts(
                    menu: menu,
                    warn: warn,
                    verdict: verdict,
                    nameRow: badges.isEmpty ? null : name,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!warn) return card;
    return DashedBorder(
      color: AppColors.warnBorder,
      radius: AppRadius.card,
      child: card,
    );
  }
}

class _SelectCheck extends StatelessWidget {
  const _SelectCheck({
    required this.selected,
    required this.name,
    required this.onTap,
  });

  final bool selected;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$name 선택',
      button: true,
      selected: selected,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox.square(
          dimension: 48,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.primary : AppColors.surface,
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.borderStrong,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _NameRow extends StatelessWidget {
  const _NameRow({required this.name, required this.onEdit});

  final String name;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AppColors.text,
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox.square(
          dimension: 40,
          child: IconButton(
            onPressed: onEdit,
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(backgroundColor: AppColors.background),
            icon: const Icon(Icons.edit_outlined, size: 20),
            color: AppColors.textBody,
            tooltip: '이름 고치기 · ${nt('Sửa tên')}',
          ),
        ),
      ],
    );
  }
}

class _Texts extends StatelessWidget {
  const _Texts({
    required this.menu,
    required this.warn,
    required this.verdict,
    required this.nameRow,
  });

  final MenuCardData menu;
  final bool warn;
  final MenuVerdict? verdict;

  /// 배지가 있을 때만 여기서 이름 줄을 그립니다 (없으면 맨 윗줄에 있어요).
  final Widget? nameRow;

  @override
  Widget build(BuildContext context) {
    final hits = <String, bool>{
      for (final h in verdict?.hits ?? const []) h.label: h.main,
    };
    final ingredients = [
      for (final i in ingredientsFor(menu.name))
        // 고기가 안 보이는 요리마다 붙는 막연한 '고기?'는 카드에서 빼요.
        if (!(i.hidden && i.label == '고기')) i,
    ].take(4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ?nameRow,
        if (menu.romanization != null) ...[
          const SizedBox(height: 4),
          Text(menu.romanization!, style: AppText.romanization),
        ],
        if (menu.meaning != null)
          Text(
            menu.meaning!,
            style: AppText.native.copyWith(fontWeight: FontWeight.w700),
          ),
        if (menu.description != null) ...[
          const SizedBox(height: 4),
          Text(
            menu.description!,
            style: AppText.native.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
        if (warn) ...[
          const SizedBox(height: 6),
          const Text(
            '글씨가 흐려요. 맞는지 확인해 주세요',
            style: TextStyle(fontSize: 14, color: AppColors.warnText),
          ),
        ],
        if (ingredients.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final i in ingredients)
                IngredientChip.of(
                  i,
                  verdict: switch (hits[i.label]) {
                    true => Verdict.avoid,
                    false => Verdict.ask,
                    null => null,
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }
}
