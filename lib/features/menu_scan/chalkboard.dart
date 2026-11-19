import 'package:material_ui/material_ui.dart';

import '../../app/languages.dart';

import '../../app/colors.dart';
import '../../app/theme.dart';
import '../../widgets/dashed_border.dart';
import '../../widgets/verdict_badge.dart';

/// 칠판 메뉴판 그림 (C1 촬영 안내 · C3 사진 보기 · C6 찍은 글씨).
///
/// 나무 틀 + 초록 칠판 + 분필 글씨. 메뉴 줄은 [ChalkRow]를 넣습니다.
class Chalkboard extends StatelessWidget {
  const Chalkboard({
    super.key,
    required this.title,
    required this.rows,
    this.gap = 4,
    this.width,
  });

  final String title;
  final List<Widget> rows;
  final double gap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
      decoration: BoxDecoration(
        color: AppColors.board,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.boardFrame, width: 9),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 30,
              height: 1.2,
              color: AppColors.chalkTitle,
            ),
          ),
          for (final r in rows) ...[SizedBox(height: gap), r],
        ],
      ),
    );
  }
}

/// 칠판 메뉴판 한 줄: 메뉴 이름 ······ 가격.
class ChalkRow extends StatelessWidget {
  const ChalkRow({
    super.key,
    required this.name,
    this.price,
    this.faded = false,
    this.fontSize = 24,
  });

  final String name;
  final String? price;

  /// 흐린 글씨 (인식 신뢰도 낮음)
  final bool faded;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: fontSize,
      height: 1.2,
      color: AppColors.chalk.withValues(alpha: faded ? 0.6 : 1),
    );
    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        // 이름은 줄의 65%, 가격은 35%까지. 남는 자리는 점선이 채우고,
        // 그래도 넘치면 줄임표로 자릅니다.
        child: LayoutBuilder(
          builder: (context, box) => Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: box.maxWidth * 0.65),
                child: Text(
                  name,
                  style: style,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(6, 0, 6, 8),
                  child: SizedBox(
                    height: 2,
                    child: CustomPaint(painter: _DottedLine()),
                  ),
                ),
              ),
              if (price != null)
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: box.maxWidth * 0.35),
                  child: Text(
                    price!,
                    style: style,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DottedLine extends CustomPainter {
  const _DottedLine();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.chalk.withValues(alpha: 0.35);
    for (var x = 0.0; x < size.width; x += 5) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 2, 2), paint);
    }
  }

  @override
  bool shouldRepaint(_DottedLine oldDelegate) => false;
}

/// C3 사진 보기: 판정 색 테두리 + 오른쪽 위 판정 배지를 붙인 메뉴 줄.
/// 판정이 없고 [needsCheck]면 흰 점선 + '확인해 주세요'.
class VerdictChalkRow extends StatelessWidget {
  const VerdictChalkRow({
    super.key,
    required this.name,
    required this.verdict,
    required this.needsCheck,
    required this.onTap,
    this.price,
  });

  final String name;
  final String? price;
  final Verdict? verdict;
  final bool needsCheck;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final v = verdict;
    final check = needsCheck;
    Widget row = Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: v == null || check
            ? null
            : Border.all(color: v.onBoard, width: 2.5),
      ),
      child: ChalkRow(name: name, price: price, faded: check),
    );
    if (check) {
      row = DashedBorder(
        color: Colors.white.withValues(alpha: 0.8),
        radius: 10,
        dash: 6,
        gap: 4,
        child: row,
      );
    }
    final badge = check
        ? _BoardPill(
            icon: Icons.visibility_outlined,
            label: '확인해 주세요',
            native: nt('Kiểm tra'),
            fg: AppColors.warnText,
            bg: AppColors.surface,
            dashed: true,
          )
        : v == null
        ? null
        : _BoardPill(
            icon: v.icon,
            label: v.label,
            native: v.native,
            fg: v.fg,
            bg: v.bg,
          );
    return Semantics(
      button: true,
      label: '$name 자세히 보기',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            row,
            if (badge != null) Positioned(right: -8, top: -13, child: badge),
          ],
        ),
      ),
    );
  }
}

class _BoardPill extends StatelessWidget {
  const _BoardPill({
    required this.icon,
    required this.label,
    required this.native,
    required this.fg,
    required this.bg,
    this.dashed = false,
  });

  final IconData icon;
  final String label;
  final String native;
  final Color fg;
  final Color bg;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      height: 24,
      padding: const EdgeInsets.fromLTRB(6, 0, 8, 0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            '· $native',
            style: AppText.native.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: fg,
            ),
          ),
        ],
      ),
    );
    if (!dashed) return pill;
    return DashedBorder(
      color: AppColors.warnBorder,
      radius: 999,
      dash: 3,
      gap: 2,
      child: pill,
    );
  }
}
