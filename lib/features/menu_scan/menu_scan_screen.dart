import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../app/languages.dart';

import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/diet.dart';
import '../../app/router.dart';
import '../../app/session.dart';
import '../../app/theme.dart';
import '../../widgets/iju_button.dart';
import '../../widgets/verdict_badge.dart';
import '../scenario/scenarios.dart';
import 'chalkboard.dart';
import 'example_menus.dart';
import 'menu_card.dart';
import 'menu_scan_api.dart';
import 'rename_sheet.dart';

/// 메뉴판 촬영 → 서버 인식 → 판정 결과 → 고른 메뉴로 문장 만들기. 담당: 개발자1
///
/// 디자인 'B·C 홈 → 메뉴판 → 판정'을 따릅니다.
/// C1 촬영 안내 → C2 읽는 중 → C3 결과 · 사진 보기 ⇄ C4 결과 · 목록 보기,
/// 카드·메뉴 줄을 누르면 C5 메뉴 상세 시트, 연필을 누르면 C6 이름 고치기 시트.
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

  /// 읽는 중에 취소하면 늦게 온 결과를 버리려고 요청마다 번호를 붙입니다.
  int _scanId = 0;

  /// C3 사진 보기 / C4 목록 보기
  bool _photoView = true;

  /// 판정 필터. null이면 전체.
  Verdict? _filter;

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

  void _loadExample() {
    _scanId++;
    _photo = null;
    _loading = false;
    _example = true;
    _error = null;
    _menus = [for (final m in exampleMenusFor(widget.scenario.id)) m.toCard()];
    _selected.clear();
    _filter = null;
    _photoView = true;
  }

  /// 처음 촬영 안내 화면(C1)으로 돌아갑니다. 읽는 중이면 취소합니다.
  void _reset() => setState(() {
    _scanId++;
    _photo = null;
    _loading = false;
    _example = false;
    _error = null;
    _menus = [];
    _selected.clear();
    _filter = null;
  });

  void _leave() =>
      context.canPop() ? context.pop() : context.go(AppRoutes.home);

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
    final id = ++_scanId;
    setState(() {
      _photo = bytes;
      _example = false;
      _loading = true;
      _error = null;
      _menus = [];
      _selected.clear();
      _filter = null;
      _photoView = true;
    });
    try {
      final result = await scanMenu(
        bytes,
        filename: file.name,
        language: AppSession.language,
        placeId: AppSession.placeId,
      );
      if (!mounted || id != _scanId) return;
      setState(() {
        _menus = result.items;
        _error = result.items.isEmpty
            ? '메뉴를 찾지 못했어요. 메뉴판이 화면에 꽉 차게 다시 찍어 주세요.'
            : null;
      });
    } on MenuScanException catch (e) {
      if (!mounted || id != _scanId) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted && id == _scanId) setState(() => _loading = false);
    }
  }

  Future<void> _edit(int index) async {
    final menu = _menus[index];
    final name = await showRenameSheet(
      context,
      original: menu.scannedText,
      current: menu.name,
    );
    if (name == null || name.isEmpty || name == menu.name || !mounted) return;
    setState(() => _menus[index] = menu.renamed(name));
  }

  void _toggle(int index) => setState(
    () => _selected.contains(index)
        ? _selected.remove(index)
        : _selected.add(index),
  );

  void _order() {
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

  @override
  Widget build(BuildContext context) {
    if (_loading || (_photo != null && _menus.isEmpty)) {
      return _ReadingView(
        photo: _photo,
        error: _loading ? null : _error,
        onClose: _reset,
        onRetake: _reset,
        onExample: () => setState(_loadExample),
      );
    }
    if (_menus.isEmpty) {
      return _CameraGuide(
        scenario: widget.scenario,
        error: _error,
        cameraSupported: _cameraSupported,
        onClose: _leave,
        onShoot: () =>
            _pick(_cameraSupported ? ImageSource.camera : ImageSource.gallery),
        onGallery: () => _pick(ImageSource.gallery),
        onExample: () => setState(_loadExample),
      );
    }

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ResultHeader(onBack: _leave, onRetake: _reset),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ViewTabs(
                photo: _photoView,
                onChanged: (v) => setState(() => _photoView = v),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _photoView
                  ? _PhotoResult(
                      menus: _menus,
                      photo: _photo,
                      example: _example,
                      boardTitle: '${widget.scenario.place} 차림표',
                      // 메뉴 줄을 누르면 그 메뉴를 골라 목록 보기로 넘어가요.
                      onOpen: (i) => setState(() {
                        _selected.add(i);
                        _photoView = false;
                      }),
                    )
                  : _ListResult(
                      menus: _menus,
                      selected: _selected,
                      filter: _filter,
                      onFilter: (v) => setState(() => _filter = v),
                      onSelect: _toggle,
                      onEdit: _edit,
                    ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomInset),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: _photoView
                  ? IjuButton(
                      label: '목록에서 메뉴 고르기',
                      sub: nt('Chọn món'),
                      icon: Icons.format_list_bulleted,
                      type: IjuButtonType.secondary,
                      onPressed: () => setState(() => _photoView = false),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_selected.isNotEmpty) ...[
                          _KoNativeLine(
                            '${_selected.length}개 골랐어요',
                            nt('Đã chọn {n} món', {'n': _selected.length}),
                          ),
                          const SizedBox(height: 8),
                        ],
                        IjuButton(
                          label: _orderLabel,
                          sub: _selected.isEmpty ? null : nt('Tạo câu'),
                          icon: _selected.isEmpty ? null : Icons.auto_awesome,
                          onPressed: _selected.isEmpty ? null : _order,
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

/// '1인분 15,000원' → '15,000' (칠판에는 숫자만).
String _boardPrice(String price) =>
    RegExp(r'[\d,]+(?=원)').firstMatch(price)?.group(0) ?? price;

/// '할랄 기준' 같은 판정 기준 이름. 식단을 고르지 않았으면 null.
String? dietBasis(Set<Diet> diets) {
  if (diets.isEmpty) return null;
  final label = diets.first.label;
  final name = RegExp(r'\((.+)\)').firstMatch(label)?.group(1) ?? label;
  return diets.length > 1 ? '$name 외 ${diets.length - 1} 기준' : '$name 기준';
}

// ------------------------------------------------------------ C1 촬영 안내

/// C1 메뉴판 촬영: 어두운 화면 + 예시 칠판 메뉴판 + 네 귀퉁이 틀 + 셔터.
/// 실제 카메라는 가운데 셔터를 누르면 기기 카메라로 열립니다.
class _CameraGuide extends StatelessWidget {
  const _CameraGuide({
    required this.scenario,
    required this.error,
    required this.cameraSupported,
    required this.onClose,
    required this.onShoot,
    required this.onGallery,
    required this.onExample,
  });

  final Scenario scenario;
  final String? error;
  final bool cameraSupported;
  final VoidCallback onClose;
  final VoidCallback onShoot;
  final VoidCallback onGallery;
  final VoidCallback onExample;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final bottomBar = 210.0 + pad.bottom;
    final basis = dietBasis(AppSession.diets.value);
    final frame = EdgeInsets.fromLTRB(22, pad.top + 142, 22, bottomBar + 22);
    return Scaffold(
      backgroundColor: AppColors.camera,
      body: Stack(
        children: [
          // 예시 메뉴판 (살짝 기울어진 칠판)
          Positioned.fill(
            child: Padding(
              padding: frame.add(const EdgeInsets.all(10)),
              child: FittedBox(
                child: Transform.rotate(
                  angle: -2 * math.pi / 180,
                  child: Opacity(
                    opacity: 0.92,
                    child: Chalkboard(
                      width: 330,
                      title: '${scenario.place} 차림표',
                      rows: [
                        for (final m in exampleMenusFor(scenario.id))
                          ChalkRow(name: m.name, price: _boardPrice(m.price)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(child: ColoredBox(color: Color(0x40000000))),
          ),
          Positioned.fill(
            child: Padding(
              padding: frame,
              child: const IgnorePointer(
                child: CustomPaint(painter: _CornersPainter()),
              ),
            ),
          ),
          Positioned(
            top: pad.top + 16,
            left: 12,
            right: 12,
            child: Row(
              children: [
                _RoundIconButton(
                  icon: Icons.close,
                  tooltip: '닫기 · ${nt('Đóng')}',
                  onTap: onClose,
                ),
                const Spacer(),
                if (basis != null) _DarkPill(label: basis),
                const Spacer(),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Positioned(
            top: pad.top + 76,
            left: 20,
            right: 20,
            child: _GuidePill(error: error),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: bottomBar,
            child: ColoredBox(
              color: AppColors.camera,
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 0, 12, 30 + pad.bottom),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _SideAction(
                      icon: Icons.photo_outlined,
                      label: '사진첩',
                      native: nt('Thư viện'),
                      onTap: onGallery,
                    ),
                    _Shutter(
                      label: cameraSupported ? '찍기' : '사진 올리기',
                      icon: cameraSupported ? null : Icons.upload,
                      onTap: onShoot,
                    ),
                    _SideAction(
                      icon: Icons.menu_book_outlined,
                      label: '예시 메뉴판',
                      native: nt('Menu mẫu'),
                      onTap: onExample,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 흰 반투명 안내 말풍선. 오류가 있으면 오류를 보여 줍니다.
class _GuidePill extends StatelessWidget {
  const _GuidePill({required this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
      ),
      child: error != null
          ? Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 20,
                  color: AppColors.dangerText,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.dangerText,
                    ),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                const Text(
                  '메뉴판이 화면에 꽉 차게 찍어 주세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  nt('Chụp sao cho menu đầy khung hình'),
                  textAlign: TextAlign.center,
                  style: AppText.native.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
    );
  }
}

/// 네 귀퉁이 흰 틀 (44 · 두께 5 · 반경 14).
class _CornersPainter extends CustomPainter {
  const _CornersPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const len = 44.0;
    const r = 14.0;
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;
    void corner(Offset a, Offset c, Offset b) {
      // a → (모서리 c를 둥글게) → b
      final toC = (c - a) / (c - a).distance;
      final fromC = (b - c) / (b - c).distance;
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(c.dx - toC.dx * r, c.dy - toC.dy * r)
        ..quadraticBezierTo(
          c.dx,
          c.dy,
          c.dx + fromC.dx * r,
          c.dy + fromC.dy * r,
        )
        ..lineTo(b.dx, b.dy);
      canvas.drawPath(path, paint);
    }

    corner(const Offset(0, len), Offset.zero, const Offset(len, 0));
    corner(Offset(w - len, 0), Offset(w, 0), Offset(w, len));
    corner(Offset(w, h - len), Offset(w, h), Offset(w - len, h));
    corner(Offset(len, h), Offset(0, h), Offset(0, h - len));
  }

  @override
  bool shouldRepaint(_CornersPainter oldDelegate) => false;
}

/// 어두운 화면 위 48 동그란 버튼 (닫기 · 취소).
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.14),
        fixedSize: const Size.square(48),
      ),
      icon: Icon(icon, color: Colors.white),
    );
  }
}

/// 어두운 화면 위 판정 기준 알약 ('할랄 기준').
class _DarkPill extends StatelessWidget {
  const _DarkPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// 가운데 큰 셔터 (84, 흰 원 + 바깥 흰 링). 폰이 아니면 업로드 아이콘을 넣습니다.
class _Shutter extends StatelessWidget {
  const _Shutter({required this.label, required this.onTap, this.icon});

  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 92,
          height: 92,
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: AppColors.camera, width: 6),
            ),
            child: icon == null
                ? null
                : Icon(icon, color: AppColors.primaryDark, size: 30),
          ),
        ),
      ),
    );
  }
}

class _SideAction extends StatelessWidget {
  const _SideAction({
    required this.icon,
    required this.label,
    required this.native,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String native;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 96,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                native,
                style: AppText.native.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppColors.onCameraMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ C2 읽는 중

/// C2 읽는 중: 위에 찍은 사진 + 스캔 줄, 아래 진행 바와 빈 카드.
/// 읽지 못했으면([error]) 같은 자리에 오류와 다시 찍기 버튼을 보여 줍니다.
class _ReadingView extends StatefulWidget {
  const _ReadingView({
    required this.photo,
    required this.error,
    required this.onClose,
    required this.onRetake,
    required this.onExample,
  });

  final Uint8List? photo;
  final String? error;
  final VoidCallback onClose;
  final VoidCallback onRetake;
  final VoidCallback onExample;

  @override
  State<_ReadingView> createState() => _ReadingViewState();
}

class _ReadingViewState extends State<_ReadingView>
    with SingleTickerProviderStateMixin {
  late final _scan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  final _clock = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    if (widget.error == null) _scan.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_ReadingView old) {
    super.didUpdateWidget(old);
    if (widget.error != null) _scan.stop();
  }

  @override
  void dispose() {
    _scan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final reading = widget.error == null;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 330 + top,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: AppColors.camera),
                if (widget.photo != null)
                  Image.memory(widget.photo!, fit: BoxFit.cover),
                const ColoredBox(color: Color(0x59000000)),
                if (reading)
                  AnimatedBuilder(
                    animation: _scan,
                    builder: (context, _) => Align(
                      alignment: Alignment(0, -0.8 + 1.6 * _scan.value),
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.scanLine,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.scanLine.withValues(alpha: 0.55),
                              blurRadius: 18,
                              spreadRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 20,
                  top: top + 16,
                  child: _RoundIconButton(
                    icon: Icons.close,
                    tooltip: reading
                        ? '취소 · ${nt('Hủy')}'
                        : '닫기 · ${nt('Đóng')}',
                    onTap: widget.onClose,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              children: reading ? _reading() : _failed(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _reading() => [
    AnimatedBuilder(
      animation: _scan,
      builder: (context, _) {
        final sec = _clock.elapsedMilliseconds / 1000;
        // 손글씨는 10~20초: 처음엔 빨리, 갈수록 천천히 차고 끝까지는 안 가요.
        final progress = 0.92 * (1 - math.exp(-sec / 7));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: _Heading('메뉴를 읽고 있어요', nt('Đang đọc menu…'))),
                Text(
                  '${sec.floor()}초',
                  style: AppText.number.copyWith(
                    fontSize: 18,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                color: AppColors.primary,
                backgroundColor: AppColors.border,
              ),
            ),
          ],
        );
      },
    ),
    const SizedBox(height: 12),
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.info_outline, size: 16, color: AppColors.textSub),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '손글씨 메뉴판은 10~20초 걸릴 수 있어요',
                style: TextStyle(fontSize: 14, color: AppColors.textSub),
              ),
              Text(
                nt('Menu viết tay có thể mất 10–20 giây'),
                style: AppText.native.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSub,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    const SizedBox(height: 14),
    const _SkeletonCard(),
    const SizedBox(height: 10),
    const _SkeletonCard(),
  ];

  List<Widget> _failed() => [
    _Heading('메뉴를 읽지 못했어요', nt('Không đọc được menu')),
    const SizedBox(height: 12),
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warnBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        widget.error!,
        style: const TextStyle(fontSize: 15, color: AppColors.warnText),
      ),
    ),
    const SizedBox(height: 20),
    IjuButton(
      label: '다시 찍기',
      sub: nt('Chụp lại'),
      icon: Icons.photo_camera_outlined,
      onPressed: widget.onRetake,
    ),
    const SizedBox(height: 10),
    IjuButton(
      label: '예시 메뉴판으로 해 보기',
      sub: nt('Menu mẫu'),
      type: IjuButtonType.secondary,
      onPressed: widget.onExample,
    ),
  ];
}

class _Heading extends StatelessWidget {
  const _Heading(this.ko, this.native);

  final String ko;
  final String native;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(ko, style: AppText.subtitle.copyWith(fontSize: 22)),
        Text(
          native,
          style: AppText.native.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.textSub,
          ),
        ),
      ],
    );
  }
}

/// 읽는 중 자리 표시 카드.
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    Widget bar(double? width, double height, [double factor = 1]) =>
        FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: width == null ? factor : null,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: AppColors.skeleton,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
    return Opacity(
      opacity: 0.7,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bar(110, 28),
            const SizedBox(height: 10),
            bar(null, 24, 0.6),
            const SizedBox(height: 10),
            bar(null, 14, 0.4),
            const SizedBox(height: 10),
            bar(null, 14, 0.8),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ C3·C4 결과

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.onBack, required this.onRetake});

  final VoidCallback onBack;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            IconButton(
              onPressed: onBack,
              tooltip: '뒤로 · ${nt('Quay lại')}',
              icon: const Icon(Icons.arrow_back_ios_new, size: 22),
              color: AppColors.text,
              style: IconButton.styleFrom(fixedSize: const Size.square(48)),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '메뉴 결과',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    nt('Kết quả menu'),
                    style: AppText.native.copyWith(
                      fontSize: 13,
                      color: AppColors.textSub,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onRetake,
              tooltip: '다시 찍기 · ${nt('Chụp lại')}',
              icon: const Icon(Icons.refresh, size: 24),
              color: AppColors.text,
              style: IconButton.styleFrom(fixedSize: const Size.square(48)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 사진 · Ảnh / 목록 · Danh sách 탭.
class _ViewTabs extends StatelessWidget {
  const _ViewTabs({required this.photo, required this.onChanged});

  final bool photo;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(bool value, IconData icon, String ko, String native) {
      final on = photo == value;
      return Expanded(
        child: Semantics(
          selected: on,
          button: true,
          child: GestureDetector(
            onTap: () => onChanged(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 48,
              decoration: BoxDecoration(
                color: on ? AppColors.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                boxShadow: on
                    ? const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: on ? AppColors.text : AppColors.textBody,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    ko,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                      color: on ? AppColors.text : AppColors.textBody,
                    ),
                  ),
                  Text(
                    ' · $native',
                    style: AppText.native.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: on ? AppColors.text : AppColors.textBody,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.tabTrack,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          tab(true, Icons.image_outlined, '사진', nt('Ảnh')),
          const SizedBox(width: 4),
          tab(false, Icons.format_list_bulleted, '목록', nt('Danh sách')),
        ],
      ),
    );
  }
}

/// C3 사진 보기: 판정 요약 + 칠판 메뉴판에 메뉴마다 판정을 붙여 보여 줍니다.
///
/// 서버가 글자 위치를 주지 않아서 사진 위에 바로 붙이지 않고,
/// 읽은 메뉴를 칠판 메뉴판으로 다시 그려 판정을 붙입니다.
class _PhotoResult extends StatelessWidget {
  const _PhotoResult({
    required this.menus,
    required this.photo,
    required this.example,
    required this.boardTitle,
    required this.onOpen,
  });

  final List<MenuCardData> menus;
  final Uint8List? photo;
  final bool example;
  final String boardTitle;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final diets = AppSession.diets.value;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      children: [
        _SummaryCard(menus: menus, example: example),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 18, 10, 14),
          decoration: BoxDecoration(
            color: AppColors.camera,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (photo != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 140,
                    child: Image.memory(photo!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Chalkboard(
                title: boardTitle,
                gap: 14,
                rows: [
                  for (var i = 0; i < menus.length; i++)
                    VerdictChalkRow(
                      name: menus[i].name,
                      verdict: MenuVerdict.of(menus[i].name, diets)?.verdict,
                      needsCheck: menus[i].needsCheck,
                      onTap: () => onOpen(i),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: _KoNativeLine(
            '메뉴 줄을 누르면 그 메뉴를 골라요',
            nt('Chạm vào món để chọn'),
            muted: true,
          ),
        ),
      ],
    );
  }
}

/// 메뉴 N개 · 판정 기준 · 판정별 개수.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.menus, required this.example});

  final List<MenuCardData> menus;
  final bool example;

  @override
  Widget build(BuildContext context) {
    final diets = AppSession.diets.value;
    final basis = dietBasis(diets);
    final counts = _verdictCounts(menus);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: '메뉴 ${menus.length}개',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                    children: [
                      TextSpan(
                        text: ' · ${nt('{n} món', {'n': menus.length})}',
                        style: AppText.native.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textBody,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (basis != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        size: 14,
                        color: AppColors.primary900,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        basis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary900,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (counts != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                for (final v in Verdict.values)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(v.icon, size: 16, color: v.fg),
                      const SizedBox(width: 4),
                      Text(
                        '${v.label} ${counts[v] ?? 0}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: v.fg,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [for (final v in Verdict.values) '${v.native} ${counts[v] ?? 0}']
                  .join(' · '),
              style: AppText.native.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.textSub,
              ),
            ),
          ],
          if (example) ...[
            const SizedBox(height: 8),
            const Text(
              '예시 메뉴판이에요. 가게에서는 진짜 메뉴판을 찍어 보세요',
              style: AppText.caption,
            ),
          ],
        ],
      ),
    );
  }
}

/// 판정별 메뉴 수. 식단을 고르지 않았으면 null.
Map<Verdict, int>? _verdictCounts(List<MenuCardData> menus) {
  final diets = AppSession.diets.value;
  if (diets.isEmpty) return null;
  final counts = <Verdict, int>{};
  for (final m in menus) {
    final v = MenuVerdict.of(m.name, diets)?.verdict;
    if (v != null) counts[v] = (counts[v] ?? 0) + 1;
  }
  return counts;
}

/// C4 목록 보기: 판정 필터 칩 + 메뉴 카드.
class _ListResult extends StatelessWidget {
  const _ListResult({
    required this.menus,
    required this.selected,
    required this.filter,
    required this.onFilter,
    required this.onSelect,
    required this.onEdit,
  });

  final List<MenuCardData> menus;
  final Set<int> selected;
  final Verdict? filter;
  final ValueChanged<Verdict?> onFilter;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onEdit;

  @override
  Widget build(BuildContext context) {
    final diets = AppSession.diets.value;
    final counts = _verdictCounts(menus);
    final shown = [
      for (var i = 0; i < menus.length; i++)
        if (filter == null ||
            MenuVerdict.of(menus[i].name, diets)?.verdict == filter)
          i,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (counts != null) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _FilterChip(
                  label: '전체 ${menus.length}',
                  native: nt('Tất cả'),
                  selected: filter == null,
                  onTap: () => onFilter(null),
                ),
                for (final v in Verdict.values)
                  _FilterChip(
                    label: '${v.label} ${counts[v] ?? 0}',
                    native: v.native,
                    selected: filter == v,
                    onTap: () => onFilter(v),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            itemCount: shown.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, k) {
              final i = shown[k];
              return MenuCard(
                menu: menus[i],
                selected: selected.contains(i),
                onSelect: () => onSelect(i),
                onEdit: () => onEdit(i),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.native,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String native;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.text;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? AppColors.primary : AppColors.surface,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 40,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[
                    Icon(Icons.check, size: 16, color: fg),
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
                  const SizedBox(width: 6),
                  Opacity(
                    opacity: 0.85,
                    child: Text(
                      native,
                      style: AppText.native.copyWith(fontSize: 13, color: fg),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 한국어 + 작은 모국어 한 줄 ('1개 골랐어요 · ${nt('Đã chọn 1 món')}').
class _KoNativeLine extends StatelessWidget {
  const _KoNativeLine(this.ko, this.native, {this.muted = false});

  final String ko;
  final String native;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final color = muted ? AppColors.textSub : AppColors.primaryDark;
    return Text.rich(
      TextSpan(
        text: ko,
        style: TextStyle(
          fontSize: 14,
          fontWeight: muted ? FontWeight.w500 : FontWeight.w700,
          color: color,
        ),
        children: [
          TextSpan(
            text: ' · $native',
            style: AppText.native.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: color,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
