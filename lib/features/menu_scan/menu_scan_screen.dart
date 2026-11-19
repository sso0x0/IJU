import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/router.dart';
import '../../app/session.dart';
import '../../widgets/dashed_border.dart';
import '../../widgets/iju_button.dart';
import '../../widgets/iju_header.dart';
import '../../widgets/iju_icon.dart';
import '../scenario/scenarios.dart';
import 'example_menus.dart';
import 'menu_card.dart';
import 'menu_scan_api.dart';

/// 메뉴판 촬영 → 서버 인식 → 메뉴 카드 → 고른 메뉴로 문장 만들기. 담당: 개발자1
///
/// 미션의 1·2단계입니다. 사진 전에는 어두운 촬영 안내 화면(1/4),
/// 사진을 찍은 뒤에는 밝은 메뉴 고르기 화면(2/4)을 보여 줍니다.
class MenuScanScreen extends StatefulWidget {
  const MenuScanScreen({
    super.key,
    this.scenario = restaurant,
    this.example = false,
  });

  /// 고른 메뉴로 문장을 만들 가게 시나리오 (양·용도 같은 옵션과 사장님 대사).
  final Scenario scenario;

  /// 가게에 가기 전 연습: 예시 메뉴판 결과부터 보여 줍니다.
  final bool example;

  @override
  State<MenuScanScreen> createState() => _MenuScanScreenState();
}

class _MenuScanScreenState extends State<MenuScanScreen> {
  final _picker = ImagePicker();

  Uint8List? _photo;
  bool _loading = false;
  bool _example = false;
  String? _error;
  List<MenuCardData> _menus = [];
  final Set<int> _selected = {};
  int _elapsedMs = 0;

  /// 카메라는 Android·iOS 앱에서만 씁니다. 웹·PC에서는 파일 올리기만 보여줍니다.
  static bool get _cameraSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    if (widget.example) _loadExample();
  }

  /// 촬영 안내 화면 (사진도 예시도 없을 때)
  bool get _guide => _photo == null && !_example;

  void _loadExample() {
    _photo = null;
    _example = true;
    _error = null;
    _menus = [for (final m in exampleMenusFor(widget.scenario.id)) m.toCard()];
    _selected.clear();
  }

  /// 처음 촬영 안내 화면으로 돌아갑니다.
  void _reset() => setState(() {
    _photo = null;
    _example = false;
    _error = null;
    _menus = [];
    _selected.clear();
  });

  Future<void> _pick(ImageSource source) async {
    XFile? file;
    try {
      file = await _picker.pickImage(source: source);
    } catch (_) {
      setState(
        () => _error = source == ImageSource.camera
            ? '카메라를 열 수 없어요. 사진첩에서 메뉴판 사진을 골라 주세요.'
            : '사진을 불러올 수 없어요. 다른 사진으로 다시 해 주세요.',
      );
      return;
    }
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _photo = bytes;
      _example = false;
      _loading = true;
      _error = null;
      _menus = [];
      _selected.clear();
    });
    try {
      final result = await scanMenu(
        bytes,
        filename: file.name,
        language: AppSession.language,
        placeId: AppSession.placeId,
      );
      if (!mounted) return;
      setState(() {
        _menus = result.items;
        _elapsedMs = result.elapsedMs;
        _error = result.items.isEmpty
            ? '메뉴를 찾지 못했어요. 메뉴판이 화면에 꽉 차게 다시 찍어 주세요.'
            : null;
      });
    } on MenuScanException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit(int index) async {
    final controller = TextEditingController(text: _menus[index].name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('메뉴 이름 고치기'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '메뉴판에 적힌 이름'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    setState(() => _menus[index] = _menus[index].renamed(name));
  }

  void _toggle(int index) => setState(
    () => _selected.contains(index)
        ? _selected.remove(index)
        : _selected.add(index),
  );

  void _order() {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('주문할 메뉴를 골라 주세요')));
      return;
    }
    // 고른 메뉴를 메뉴판 순서대로 문장 만들기 화면에 넘깁니다.
    // 이름을 고친 메뉴도 고친 이름 그대로 문장에 들어갑니다.
    final picked = [
      for (var i = 0; i < _menus.length; i++)
        if (_selected.contains(i)) _menus[i],
    ];
    context.push(
      '${AppRoutes.compose}?scenario=${widget.scenario.id}',
      extra: picked,
    );
  }

  /// '삼겹살로 문장 만들기' / '비빔밥으로 문장 만들기' / '2개로 문장 만들기'
  String get _orderLabel {
    if (_selected.isEmpty) return '메뉴를 골라 주세요';
    if (_selected.length > 1) return '${_selected.length}개로 문장 만들기';
    return '${withRo(_menus[_selected.first].name)} 문장 만들기';
  }

  String get _title => '${widget.scenario.place} 미션';

  @override
  Widget build(BuildContext context) {
    if (_guide) {
      return _GuideView(
        title: '$_title · 1/4',
        scenario: widget.scenario,
        error: _error,
        cameraSupported: _cameraSupported,
        onShoot: () =>
            _pick(_cameraSupported ? ImageSource.camera : ImageSource.gallery),
        onGallery: () => _pick(ImageSource.gallery),
        onExample: () => setState(_loadExample),
      );
    }

    final hasResult = _menus.isNotEmpty;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IjuHeader(title: '$_title · ${hasResult ? 2 : 1}/4'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                children: [
                  _PhotoBox(
                    photo: _photo,
                    scenario: widget.scenario,
                    loading: _loading,
                    found: hasResult ? _menus.length : null,
                  ),
                  const SizedBox(height: 16),
                  if (_loading) const _LoadingText(),
                  if (_error != null) _ErrorText(_error!),
                  if (hasResult) ...[
                    _ResultTitle(
                      note: _example
                          ? '예시 메뉴판이에요. 가게에서는 진짜 메뉴판을 찍어 보세요'
                          : '틀린 이름은 연필을 눌러 고칠 수 있어요 · '
                                '${(_elapsedMs / 1000).toStringAsFixed(1)}초',
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < _menus.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      MenuCard(
                        menu: _menus[i],
                        selected: _selected.contains(i),
                        onTap: () => _toggle(i),
                        onEdit: () => _edit(i),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Row(
                children: [
                  if (hasResult) ...[
                    SizedBox(
                      width: 112,
                      child: IjuButton(
                        label: _example ? '직접 찍기' : '다시 찍기',
                        type: IjuButtonType.secondary,
                        onPressed: _reset,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: IjuButton(label: _orderLabel, onPressed: _order),
                    ),
                  ] else
                    Expanded(
                      child: IjuButton(
                        label: '다시 찍기',
                        type: IjuButtonType.secondary,
                        onPressed: _loading ? null : _reset,
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

/// ‘-로/으로’. 삼겹살 → 삼겹살로, 비빔밥 → 비빔밥으로 (ㄹ 받침은 ‘로’)
String withRo(String word) {
  if (!hasBatchim(word)) return '$word로';
  final c = word.codeUnitAt(word.length - 1);
  return (c - 0xAC00) % 28 == 8 ? '$word로' : '$word으로';
}

/// 사진을 찍기 전 촬영 안내 (어두운 화면). 실제 카메라는 가운데 셔터를 누르면 열립니다.
class _GuideView extends StatelessWidget {
  const _GuideView({
    required this.title,
    required this.scenario,
    required this.error,
    required this.cameraSupported,
    required this.onShoot,
    required this.onGallery,
    required this.onExample,
  });

  final String title;
  final Scenario scenario;
  final String? error;
  final bool cameraSupported;
  final VoidCallback onShoot;
  final VoidCallback onGallery;
  final VoidCallback onExample;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go(AppRoutes.home),
                    icon: const Icon(Icons.close, color: Colors.white),
                    tooltip: '닫기',
                  ),
                  const SizedBox(width: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: error == null ? AppColors.darkChip : AppColors.warnBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: error != null
                  ? Text(
                      error!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.warnText,
                      ),
                    )
                  : const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '가게 메뉴판이 화면에 꽉 차게 찍어 주세요',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Chụp toàn bộ bảng thực đơn của quán',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFFCFD3D8),
                          ),
                        ),
                      ],
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(36, 20, 36, 12),
                child: DashedBorder(
                  color: AppColors.onPrimaryMuted,
                  radius: 18,
                  dash: 8,
                  gap: 6,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: _SampleBoard(scenario: scenario),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        '이 틀에 맞춰 찍어 주세요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.onPrimaryMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
              child: Row(
                children: [
                  Expanded(
                    child: _SideAction(
                      icon: Icons.photo_library_outlined,
                      label: '사진첩',
                      onTap: onGallery,
                    ),
                  ),
                  _Shutter(
                    label: cameraSupported ? '메뉴판 찍기' : '사진 올리기',
                    icon: cameraSupported ? null : Icons.upload,
                    onTap: onShoot,
                  ),
                  Expanded(
                    child: _SideAction(
                      icon: Icons.lightbulb_outline,
                      label: '예시 메뉴판',
                      onTap: onExample,
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

/// 가운데 큰 셔터 버튼. 폰이 아니면 업로드 아이콘을 넣습니다.
class _Shutter extends StatelessWidget {
  const _Shutter({required this.label, required this.onTap, this.icon});

  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: icon == null
                    ? null
                    : Icon(icon, color: AppColors.primaryDark, size: 28),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideAction extends StatelessWidget {
  const _SideAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFFCFD3D8)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 예시 메뉴판 그림: 흰 종이에 메뉴 이름과 가격. 촬영 안내와 예시 결과에 씁니다.
class _SampleBoard extends StatelessWidget {
  const _SampleBoard({required this.scenario});

  final Scenario scenario;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 13, color: AppColors.text, height: 1.7);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final m in exampleMenusFor(scenario.id))
            Row(
              children: [
                Expanded(child: Text(m.name, style: style)),
                Text(m.price, style: style),
              ],
            ),
        ],
      ),
    );
  }
}

/// 찍은 사진 미리보기. 사진이 없으면(예시 메뉴판) 예시 그림을 보여 줍니다.
class _PhotoBox extends StatelessWidget {
  const _PhotoBox({
    required this.photo,
    required this.scenario,
    required this.loading,
    this.found,
  });

  final Uint8List? photo;
  final Scenario scenario;
  final bool loading;
  final int? found;

  @override
  Widget build(BuildContext context) {
    final badge = found == null ? null : _FoundBadge(count: found!);
    if (photo == null) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        decoration: BoxDecoration(
          color: AppColors.dark,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ?badge,
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: _SampleBoard(scenario: scenario),
            ),
          ],
        ),
      );
    }
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: AppColors.dark,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(photo!, fit: BoxFit.cover),
          if (loading)
            const ColoredBox(
              color: Color(0x88000000),
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          if (badge != null) Positioned(left: 12, top: 12, child: badge),
        ],
      ),
    );
  }
}

class _FoundBadge extends StatelessWidget {
  const _FoundBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            '메뉴 $count개 찾음',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultTitle extends StatelessWidget {
  const _ResultTitle({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '무엇을 주문할까요?',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          note,
          style: const TextStyle(fontSize: 13, color: AppColors.textSub),
        ),
      ],
    );
  }
}

class _LoadingText extends StatelessWidget {
  const _LoadingText();

  @override
  Widget build(BuildContext context) {
    return const Text(
      '메뉴를 읽고 있어요. 손글씨 메뉴판은 10~20초 걸릴 수 있어요.',
      style: TextStyle(fontSize: 14, color: AppColors.textSub),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warnBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 14, color: AppColors.warnText),
      ),
    );
  }
}
