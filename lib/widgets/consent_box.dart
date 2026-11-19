import 'package:material_ui/material_ui.dart';

import '../app/colors.dart';
import '../features/login/auth_api.dart';

/// 약관 동의 상태 (청온 SignupConsent). 회원가입·구글 가입 화면이 같이 씁니다. 담당: 개발자1
///
/// GET /auth/terms로 버전·문구를 받아 두고, 두 항목 모두 동의해야 [accepted]가 됩니다.
/// 가입 요청이 409 TERMS_CHANGED로 돌아오면 [reload]로 다시 받습니다.
class ConsentController extends ChangeNotifier {
  ConsentController() {
    reload();
  }

  String? _version;
  String _termsText = '';
  String _privacyText = '';
  bool terms = false;
  bool privacy = false;
  bool loading = true;
  bool failed = false;
  bool _disposed = false;

  bool get ready => _version != null;
  bool get accepted => ready && terms && privacy;

  /// 가입 요청 body에 붙이는 값.
  Map<String, Object?> toJson() => {
    'terms_agreed': terms,
    'privacy_agreed': privacy,
    'terms_version': _version,
  };

  Future<void> reload() async {
    _version = null;
    terms = false;
    privacy = false;
    loading = true;
    failed = false;
    _notify();
    try {
      final json = await AuthApi.terms();
      _version = json['terms_version'] as String?;
      _termsText = json['terms_text'] as String? ?? '';
      _privacyText = json['privacy_text'] as String? ?? '';
      failed = _version == null;
    } on AuthException {
      failed = true;
    }
    loading = false;
    _notify();
  }

  void setTerms(bool value) {
    terms = value;
    _notify();
  }

  void setPrivacy(bool value) {
    privacy = value;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// 체크박스 2개(이용약관·개인정보) + [보기]. 약관을 받기 전에는 막혀 있습니다.
class ConsentBox extends StatelessWidget {
  const ConsentBox({super.key, required this.controller, this.enabled = true});

  final ConsentController controller;

  /// 가입 요청 중에는 false
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        final active = enabled && c.ready;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Row(
                label: '[필수] 이용약관 동의',
                value: c.terms,
                enabled: active,
                onChanged: c.setTerms,
                onView: c.ready
                    ? () => _show(context, '이용약관', c._termsText)
                    : null,
              ),
              const Divider(height: 1, color: AppColors.divider),
              _Row(
                label: '[필수] 개인정보 수집·이용 동의',
                value: c.privacy,
                enabled: active,
                onChanged: c.setPrivacy,
                onView: c.ready
                    ? () => _show(context, '개인정보 수집·이용 동의', c._privacyText)
                    : null,
              ),
              if (c.loading)
                const Padding(
                  padding: EdgeInsets.fromLTRB(8, 4, 8, 10),
                  child: Text(
                    '약관을 불러오는 중이에요…',
                    style: TextStyle(fontSize: 13, color: AppColors.textSub),
                  ),
                ),
              if (c.failed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '약관을 불러오지 못했어요.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.dangerText,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: c.reload,
                        child: const Text('다시 불러오기'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static void _show(BuildContext context, String title, String text) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(text, style: const TextStyle(fontSize: 15, height: 1.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.onView,
  });

  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onView;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: value,
          activeColor: AppColors.primary,
          onChanged: enabled ? (v) => onChanged(v ?? false) : null,
        ),
        Expanded(
          child: GestureDetector(
            onTap: enabled ? () => onChanged(!value) : null,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: enabled ? AppColors.text : AppColors.textSub,
              ),
            ),
          ),
        ),
        TextButton(
          onPressed: onView,
          style: TextButton.styleFrom(foregroundColor: AppColors.textSub),
          child: const Text(
            '보기',
            style: TextStyle(
              fontSize: 13,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}
