import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../app/colors.dart';
import '../app/router.dart';
import 'iju_icon.dart';

/// 하단 탭 4개 (홈 · 미션 · 복습 · 내 정보). 탭 순서는 [IjuTabBar.routes]와 같습니다.
enum IjuTab { home, missions, review, profile }

/// 하단 탭 (Figma 'TabBar').
class IjuTabBar extends StatelessWidget {
  const IjuTabBar({super.key, required this.current});

  final IjuTab current;

  static const routes = {
    IjuTab.home: AppRoutes.home,
    IjuTab.missions: AppRoutes.missions,
    IjuTab.review: AppRoutes.review,
    IjuTab.profile: AppRoutes.profile,
  };

  static const _tabs = [
    (IjuTab.home, IjuIcons.tabHome, '홈'),
    (IjuTab.missions, IjuIcons.tabMission, '미션'),
    (IjuTab.review, IjuIcons.tabReview, '복습'),
    (IjuTab.profile, IjuIcons.tabProfile, '내 정보'),
  ];

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
          height: 64,
          child: Row(
            children: [
              for (final (tab, icon, label) in _tabs)
                Expanded(
                  child: Semantics(
                    selected: tab == current,
                    button: true,
                    child: InkWell(
                      onTap: tab == current
                          ? null
                          : () => context.go(routes[tab]!),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IjuIcon(
                            icon,
                            size: 22,
                            color: tab == current
                                ? AppColors.primary
                                : AppColors.textSub,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: tab == current
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: tab == current
                                  ? AppColors.primary
                                  : AppColors.textSub,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
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
      backgroundColor: AppColors.background,
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
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        if (sub != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            sub!,
                            style: const TextStyle(
                              fontSize: 14,
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
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        count == null ? text : '$text $count',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
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
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const IjuIcon(IjuIcons.points, size: 16),
          const SizedBox(width: 6),
          Text(
            '$points P',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.pointText,
            ),
          ),
        ],
      ),
    );
  }
}
