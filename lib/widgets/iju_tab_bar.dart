import 'package:go_router/go_router.dart';

import '../app/languages.dart';

import 'package:material_ui/material_ui.dart';

import '../app/colors.dart';
import '../app/theme.dart';
import '../app/router.dart';
import '../features/missions/missions_api.dart' show menuScanPath;
import 'iju_icon.dart';

/// 하단 탭 4개 (홈 · 커뮤니티 · 복습 · 마이페이지). 탭 순서는 [IjuTabBar.routes]와 같습니다.
enum IjuTab { home, community, review, profile }

/// 하단 탭 (01 공통 컴포넌트 '하단 탭').
/// 홈 / 커뮤니티 / 복습 / 마이페이지 + 가운데 떠 있는 "메뉴판 찍기" (64pt).
/// 선택 탭은 굵은 아이콘·글자 + 초록.
class IjuTabBar extends StatelessWidget {
  const IjuTabBar({super.key, required this.current});

  final IjuTab current;

  static const routes = {
    IjuTab.home: AppRoutes.home,
    IjuTab.community: AppRoutes.community,
    IjuTab.review: AppRoutes.review,
    IjuTab.profile: AppRoutes.profile,
  };

  static const _left = [
    (IjuTab.home, IjuIcons.tabHome, '홈'),
    (IjuTab.community, Icons.forum_outlined, '커뮤니티'),
  ];
  static const _right = [
    (IjuTab.review, IjuIcons.tabReview, '복습'),
    (IjuTab.profile, IjuIcons.tabProfile, '마이페이지'),
  ];

  /// [icon]은 Figma SVG 이름(String) 또는 Material 아이콘(IconData).
  Widget _tab(BuildContext context, (IjuTab, Object, String) t) {
    final (tab, icon, label) = t;
    final selected = tab == current;
    final color = selected ? AppColors.primaryDark : AppColors.textSub;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: selected ? null : () => context.go(routes[tab]!),
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              children: [
                if (icon is IconData)
                  Icon(icon, size: 24, color: color)
                else
                  IjuIcon(icon as String, size: 24, color: color),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final t in _left) _tab(context, t),
                const Expanded(child: _ScanTab()),
                for (final t in _right) _tab(context, t),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 가운데 떠 있는 "메뉴판 찍기" 버튼.
class _ScanTab extends StatelessWidget {
  const _ScanTab();

  @override
  Widget build(BuildContext context) {
    // 떠 있는 위쪽 20pt는 탭 바 밖이라 눌리지 않으므로 가운데 칸 전체를 누를 수 있게 합니다.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push(menuScanPath('restaurant')),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: -20,
            child: Semantics(
              button: true,
              label: '메뉴판 찍기 · ${nt('Chụp menu')}',
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 4),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40003F2E),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.photo_camera_outlined,
                  size: 26,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const Positioned(
            top: 47,
            child: ExcludeSemantics(
              child: Text(
                '메뉴판 찍기',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 미션 · 복습 · 내 정보 탭의 공통 틀: 큰 제목(+ 모국어 보조) + 내용 + 하단 탭.
class IjuTabScaffold extends StatelessWidget {
  const IjuTabScaffold({
    super.key,
    required this.tab,
    required this.title,
    this.sub,
    this.trailing,
    required this.children,
  });

  final IjuTab tab;
  final String title;
  final String? sub;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppText.title.copyWith(fontSize: 26),
                        ),
                        if (sub != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            sub!,
                            style: AppText.native.copyWith(
                              color: AppColors.textSub,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: children,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: IjuTabBar(current: tab),
    );
  }
}

/// 목록 위의 작은 굵은 제목 (Figma '추천 미션').
class IjuListTitle extends StatelessWidget {
  const IjuListTitle(this.text, {super.key, this.count});

  final String text;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        count == null ? text : '$text $count',
        style: AppText.subtitle.copyWith(fontSize: 18),
      ),
    );
  }
}

/// 포인트 배지 (Figma 'Points').
class PointsBadge extends StatelessWidget {
  const PointsBadge({super.key, required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.pointBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const IjuIcon(IjuIcons.points, size: 16),
          const SizedBox(width: 6),
          Text(
            '${points}P',
            style: AppText.number.copyWith(
              fontSize: 15,
              color: AppColors.pointText,
            ),
          ),
        ],
      ),
    );
  }
}
