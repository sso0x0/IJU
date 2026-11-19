import 'package:material_ui/material_ui.dart';

import '../app/colors.dart';

/// 디자인 시스템 '선택 칩 (필터·조건)'. 높이 40(터치 44), 반경 999.
///
/// [dot]이 있으면 글자 앞에 색 점(재료 주의 표시)을, [onInfo]가 있으면 글자 뒤에
/// ⓘ 버튼을 붙입니다. ⓘ는 칩 선택과 따로 눌립니다.
class IjuChip extends StatelessWidget {
  const IjuChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.dot,
    this.onInfo,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? dot;
  final VoidCallback? onInfo;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.text;
    return SizedBox(
      height: 44,
      child: Center(
        widthFactor: 1,
        child: SizedBox(
          height: 40,
          child: Material(
            color: selected ? AppColors.primary : AppColors.surface,
            shape: StadiumBorder(
              side: selected
                  ? const BorderSide(color: AppColors.primary, width: 1.5)
                  : const BorderSide(color: AppColors.border, width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: onInfo == null ? 16 : 4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (dot case final color?) ...[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: selected
                              ? Border.all(color: Colors.white, width: 1.5)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                    ),
                    if (onInfo != null)
                      Semantics(
                        button: true,
                        label: '$label 안내',
                        child: InkResponse(
                          onTap: onInfo,
                          radius: 18,
                          child: SizedBox.square(
                            dimension: 36,
                            child: Icon(
                              Icons.info_outline,
                              size: 18,
                              color: selected
                                  ? Colors.white
                                  : AppColors.textSub,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
