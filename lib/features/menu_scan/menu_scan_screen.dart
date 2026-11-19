import 'dart:math' as math;

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/router.dart';
import '../../widgets/dashed_border.dart';
import '../../widgets/iju_button.dart';
import '../../widgets/iju_header.dart';
import '../../widgets/iju_icon.dart';
import '../../widgets/option_tile.dart';

/// Figma '3 메뉴판 촬영 · 인식'. 담당: 개발자1
/// TODO(개발자1): 카메라 촬영 → POST /ai/menu-scan 결과로 교체. 지금은 시연용 고정 데이터입니다.
class MenuScanScreen extends StatefulWidget {
  const MenuScanScreen({super.key});

  @override
  State<MenuScanScreen> createState() => _MenuScanScreenState();
}

class _ScannedMenu {
  const _ScannedMenu(
    this.name,
    this.meaning,
    this.unit, {
    this.lowConfidence = false,
  });

  final String name;
  final String meaning;
  final String unit;
  final bool lowConfidence;
}

class _MenuScanScreenState extends State<MenuScanScreen> {
  static const _menus = [
    _ScannedMenu('삼겹살', 'Thịt ba chỉ', '100g'),
    _ScannedMenu('목살', 'Thịt nạc vai', '100g'),
    _ScannedMenu('앞다리', '', '100g', lowConfidence: true),
  ];

  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const IjuHeader(title: '메뉴판 인식'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _MenuPhoto(found: _menus.length),
                  const SizedBox(height: 16),
                  const Text(
                    '이렇게 읽었어요. 맞나요?',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tôi đã đọc như thế này. Đúng không?',
                    style: TextStyle(fontSize: 14, color: AppColors.textSub),
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < _menus.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _menus[i].lowConfidence
                        ? _LowConfidenceTile(
                            menu: _menus[i],
                            onTap: () {
                              // TODO(개발자1): 메뉴 이름 직접 수정 화면
                            },
                          )
                        : _MenuTile(
                            menu: _menus[i],
                            selected: _selected == i,
                            onTap: () => setState(() => _selected = i),
                          ),
                  ],
                  const SizedBox(height: 16),
                  Center(
                    child: IjuTextLink(
                      label: '인식이 안 되나요? 업종 템플릿으로 고르기',
                      onTap: () {
                        // TODO(개발자1): 업종 템플릿(정육점·식당·반찬가게) 선택
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Row(
                children: [
                  SizedBox(
                    width: 112,
                    child: IjuButton(
                      label: '다시 찍기',
                      type: IjuButtonType.secondary,
                      onPressed: () {
                        // TODO(개발자1): 카메라 다시 열기
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: IjuButton(
                      label: '이 메뉴로 문장 만들기',
                      onPressed: () => context.push(AppRoutes.compose),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 찍은 메뉴판 사진 영역. 실제 사진이 들어오기 전까지 시연용 메뉴판 그림을 보여줍니다.
class _MenuPhoto extends StatelessWidget {
  const _MenuPhoto({required this.found});

  final int found;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.dark,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Center(
            child: Transform.rotate(
              angle: -3 * math.pi / 180,
              child: const _MenuBoard(),
            ),
          ),
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const IjuIcon(IjuIcons.checkSmall, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    '메뉴 $found개 찾음',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuBoard extends StatelessWidget {
  const _MenuBoard();

  static const _ink = Color(0xFF3B2A16);
  static const _paper = Color(0xFFF2EADB);
  static const _dash = Color(0xFFB8A688);

  @override
  Widget build(BuildContext context) {
    Widget row(String name, {bool last = false}) => Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(fontSize: 14, color: _ink)),
              const Text(
                '100g [가격]',
                style: TextStyle(fontSize: 14, color: _ink),
              ),
            ],
          ),
        ),
        if (!last) const DashedLine(color: _dash),
      ],
    );

    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '오늘의 고기',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 8),
          row('삼겹살'),
          const SizedBox(height: 8),
          row('목살'),
          const SizedBox(height: 8),
          row('앞다리', last: true),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.menu,
    required this.selected,
    required this.onTap,
  });

  final _ScannedMenu menu;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OptionTile(
      selected: selected,
      onTap: onTap,
      height: 64,
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  menu.name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${menu.meaning} · ${menu.unit} 단위',
                  style: TextStyle(
                    fontSize: 13,
                    color: selected ? Colors.white : AppColors.textBody,
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            const Text(
              '선택됨',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
        ],
      ),
    );
  }
}

/// 인식 신뢰도가 낮은 메뉴: 주황 점선 + 수정 아이콘.
class _LowConfidenceTile extends StatelessWidget {
  const _LowConfidenceTile({required this.menu, required this.onTap});

  final _ScannedMenu menu;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DashedBorder(
      color: AppColors.warnBorder,
      child: SizedBox(
        height: 64,
        child: Material(
          color: AppColors.warnBg,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          menu.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          '글씨가 흐려요. 눌러서 고쳐 주세요',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.warnText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const IjuIcon(IjuIcons.edit, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
