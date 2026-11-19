import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../real_order/order_api.dart';

/// 영수증 인증 흐름 (PRD 3.3 예외 흐름 포함). 담당: 개발자3
/// 촬영 → POST /receipts → 인식 실패면 재촬영 1회 → 그래도 실패면 사장님 확인 코드.
/// 성공하면 결과, 사용자가 취소하거나 인증이 거절되면 null.
Future<ReceiptResult?> runReceiptFlow(
  BuildContext context, {
  required String missionId,
}) async {
  final picker = ImagePicker();
  var lowConfidence = 0;

  while (true) {
    final source = await _pickSource(context);
    if (source == null || !context.mounted) return null;

    XFile? file;
    try {
      file = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
    } catch (_) {
      file = null; // 권한 거부 등
    }
    if (file == null || !context.mounted) return null;

    final bytes = await file.readAsBytes();
    if (!context.mounted) return null;

    final result = await _withLoading(
      context,
      OrderApi.verifyReceipt(
        missionId: missionId,
        image: bytes,
        filename: file.name,
      ),
    );
    if (!context.mounted) return null;
    if (result.verified) return result;

    if (result.reason == 'low_confidence') {
      lowConfidence++;
      if (lowConfidence >= 2) return _merchantCode(context, missionId);
      _toast(context, '영수증을 잘 읽지 못했어요. 밝은 곳에서 한 번 더 찍어 주세요.');
      continue;
    }
    // 같은 영수증, 24시간 지남, 참여 가게 아님, 하루 3회 초과
    _toast(context, result.message ?? '인증하지 못했어요.');
    return null;
  }
}

Future<ImageSource?> _pickSource(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              '영수증을 올려 주세요',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ),
          ListTile(
            title: const Text('카메라로 찍기'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            title: const Text('앨범에서 고르기'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// 사장님 확인 코드 입력. 3번 틀리면 null.
Future<ReceiptResult?> _merchantCode(
  BuildContext context,
  String missionId,
) async {
  for (var tries = 0; tries < 3; tries++) {
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const _CodeDialog(),
    );
    if (code == null || !context.mounted) return null;

    final result = await _withLoading(
      context,
      OrderApi.merchantConfirm(missionId: missionId, code: code),
    );
    if (!context.mounted) return null;
    if (result.verified) return result;
    _toast(context, result.message ?? '확인 코드가 맞지 않아요.');
    if (result.reason != 'wrong_code') return null; // 하루 3회 초과 등
  }
  return null;
}

class _CodeDialog extends StatefulWidget {
  const _CodeDialog();

  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim();
    if (code.isNotEmpty) Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('사장님 확인 코드'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '영수증을 읽지 못했어요.\n사장님께 확인 코드 4자리를 받아 입력해 주세요.',
            style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.textBody),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 4,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 12,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(onPressed: _submit, child: const Text('확인')),
      ],
    );
  }
}

/// 서버 응답을 기다리는 동안 화면을 막고 로딩을 보여 줍니다.
Future<T> _withLoading<T>(BuildContext context, Future<T> future) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  try {
    return await future;
  } finally {
    navigator.pop();
  }
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
