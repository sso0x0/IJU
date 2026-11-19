import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../widgets/dashed_border.dart';
import 'menu_scan_api.dart';

/// 메뉴판에서 읽은 메뉴 한 개를 보여주는 카드.
///
/// 한국어 이름(크게) · 발음 · 모국어 뜻 · 한 줄 설명. 누르면 선택, 연필 버튼으로 이름 수정.
/// 손글씨라 확신이 낮은 메뉴는 주황 점선으로 "확인해 주세요"를 표시합니다.
class MenuCard extends StatelessWidget {
  const MenuCard({
    super.key,
    required this.menu,
    required this.selected,
    required this.onTap,
    required this.onEdit,
  });

  final MenuCardData menu;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final warn = menu.needsCheck && !selected;
    final card = Material(
      color: selected
          ? AppColors.primarySoft
          : warn
          ? AppColors.warnBg
          : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
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
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _Texts(menu: menu, warn: warn)),
              Column(
                children: [
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    color: warn ? AppColors.warnText : AppColors.textSub,
                    tooltip: '이름 고치기',
                  ),
                  if (selected)
                    const Icon(
                      Icons.check_circle,
                      color: AppColors.primary,
                      size: 22,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (!warn) return card;
    return DashedBorder(color: AppColors.warnBorder, child: card);
  }
}

class _Texts extends StatelessWidget {
  const _Texts({required this.menu, required this.warn});

  final MenuCardData menu;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          menu.name,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        if (menu.romanization != null) ...[
          const SizedBox(height: 2),
          Text(
            menu.romanization!,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.primaryDark,
              letterSpacing: 0.2,
            ),
          ),
        ],
        if (menu.meaning != null) ...[
          const SizedBox(height: 6),
          Text(
            menu.meaning!,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textBody,
            ),
          ),
        ],
        if (menu.description != null) ...[
          const SizedBox(height: 2),
          Text(
            menu.description!,
            style: const TextStyle(fontSize: 13, color: AppColors.textSub),
          ),
        ],
        if (warn) ...[
          const SizedBox(height: 6),
          const Text(
            '글씨가 흐려요. 맞는지 확인해 주세요',
            style: TextStyle(fontSize: 13, color: AppColors.warnText),
          ),
        ],
      ],
    );
  }
}
