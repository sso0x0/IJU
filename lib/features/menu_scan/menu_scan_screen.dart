import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/router.dart';
import '../../app/session.dart';
import '../../widgets/iju_button.dart';
import '../../widgets/iju_header.dart';
import '../../widgets/iju_icon.dart';
import 'menu_card.dart';
import 'menu_scan_api.dart';

/// 메뉴판 촬영 → 서버 인식 → 메뉴 카드. 담당: 개발자1
class MenuScanScreen extends StatefulWidget {
  const MenuScanScreen({super.key});

  @override
  State<MenuScanScreen> createState() => _MenuScanScreenState();
}

class _MenuScanScreenState extends State<MenuScanScreen> {
  final _picker = ImagePicker();

  Uint8List? _photo;
  bool _loading = false;
  String? _error;
  List<MenuCardData> _menus = [];
  final Set<int> _selected = {};
  int _elapsedMs = 0;

  /// 카메라는 Android·iOS 앱에서만 씁니다. 웹·PC에서는 파일 올리기만 보여줍니다.
  static bool get _cameraSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _pick(ImageSource source) async {
    XFile? file;
    try {
      file = await _picker.pickImage(source: source);
    } catch (_) {
      setState(
        () => _error = source == ImageSource.camera
            ? '카메라를 열 수 없어요. 「파일 올리기」로 사진을 올려 주세요.'
            : '사진을 불러올 수 없어요. 다른 파일로 다시 시도해 주세요.',
      );
      return;
    }
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _photo = bytes;
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('주문할 메뉴를 골라 주세요')));
      return;
    }
    // TODO(개발자2): 고른 메뉴 이름을 주문 문장 화면에 넘기기
    context.push(AppRoutes.compose);
  }

  /// 사진을 고르기 전: 파일 올리기 (+ 폰이면 메뉴판 찍기)
  Widget _pickButtons() {
    final upload = IjuButton(
      label: '파일 올리기',
      type: _cameraSupported ? IjuButtonType.secondary : IjuButtonType.primary,
      onPressed: _loading ? null : () => _pick(ImageSource.gallery),
    );
    if (!_cameraSupported) return upload;
    return Row(
      children: [
        Expanded(child: upload),
        const SizedBox(width: 10),
        Expanded(
          child: IjuButton(
            label: '메뉴판 찍기',
            onPressed: _loading ? null : () => _pick(ImageSource.camera),
          ),
        ),
      ],
    );
  }

  /// 결과가 나온 뒤: 다른 사진 + 주문하기
  Widget _resultButtons() {
    return Row(
      children: [
        SizedBox(
          width: 112,
          child: IjuButton(
            label: '다른 사진',
            type: IjuButtonType.secondary,
            onPressed: _loading
                ? null
                : () => _pick(
                    _cameraSupported ? ImageSource.camera : ImageSource.gallery,
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: IjuButton(
            label: _selected.isEmpty
                ? '메뉴를 골라 주세요'
                : '${_selected.length}개 주문하기',
            onPressed: _order,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasResult = _menus.isNotEmpty;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const IjuHeader(title: '메뉴판 인식'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                children: [
                  _PhotoBox(
                    photo: _photo,
                    loading: _loading,
                    found: hasResult ? _menus.length : null,
                  ),
                  const SizedBox(height: 16),
                  if (_loading) const _LoadingText(),
                  if (_error != null) _ErrorText(_error!),
                  if (hasResult) ...[
                    _ResultTitle(elapsedMs: _elapsedMs),
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
              child: hasResult ? _resultButtons() : _pickButtons(),
            ),
          ],
        ),
      ),
    );
  }
}

/// 찍은 사진 미리보기. 사진이 없으면 촬영 안내를 보여줍니다.
class _PhotoBox extends StatelessWidget {
  const _PhotoBox({required this.photo, required this.loading, this.found});

  final Uint8List? photo;
  final bool loading;
  final int? found;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: photo == null ? 240 : 180,
      decoration: BoxDecoration(
        color: AppColors.dark,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photo != null)
            Image.memory(photo!, fit: BoxFit.cover)
          else
            const _EmptyGuide(),
          if (loading)
            const ColoredBox(
              color: Color(0x88000000),
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          if (found != null)
            Positioned(
              left: 12,
              top: 12,
              child: _FoundBadge(count: found!),
            ),
        ],
      ),
    );
  }
}

class _EmptyGuide extends StatelessWidget {
  const _EmptyGuide();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.photo_camera_outlined, size: 44, color: Colors.white),
        SizedBox(height: 12),
        Text(
          '메뉴판 사진을 올려 주세요',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Chụp hoặc tải ảnh thực đơn · Upload a menu photo',
          style: TextStyle(fontSize: 13, color: Color(0xFFCFD3D8)),
        ),
      ],
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
  const _ResultTitle({required this.elapsedMs});

  final int elapsedMs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '이렇게 읽었어요. 먹고 싶은 메뉴를 골라 주세요',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '틀린 이름은 연필을 눌러 고칠 수 있어요 · '
          '${(elapsedMs / 1000).toStringAsFixed(1)}초',
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
