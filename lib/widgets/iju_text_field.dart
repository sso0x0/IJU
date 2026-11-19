import 'package:material_ui/material_ui.dart';

import '../app/colors.dart';
import '../app/theme.dart';

/// 디자인 시스템 '입력칸'. 높이 56, 둥근 14, 테두리 1.5 (선택 시 초록 2).
/// [errorText]가 있으면 빨간 테두리와 함께 칸 아래에 안내 문구를 보여 줍니다.
/// [obscureText](비밀번호)면 오른쪽 눈 아이콘으로 글자를 보였다 가렸다 할 수 있어요.
class IjuTextField extends StatefulWidget {
  const IjuTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.errorText,
    this.obscureText = false,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? hintText;
  final String? errorText;
  final bool obscureText;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<IjuTextField> createState() => _IjuTextFieldState();
}

class _IjuTextFieldState extends State<IjuTextField> {
  /// 비밀번호 글자를 가리고 있는지 (눈 아이콘으로 바꿔요)
  late bool _hidden = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.input),
      borderSide: BorderSide(
        color: hasError ? AppColors.danger : AppColors.border,
        width: 1.5,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 56,
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            enabled: widget.enabled,
            obscureText: widget.obscureText && _hidden,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            style: const TextStyle(fontSize: 17, color: AppColors.text),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: const TextStyle(color: AppColors.textSub),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              border: border,
              enabledBorder: border,
              disabledBorder: border,
              focusedBorder: border.copyWith(
                borderSide: BorderSide(
                  color: hasError ? AppColors.danger : AppColors.primary,
                  width: 2,
                ),
              ),
              suffixIcon: widget.obscureText
                  ? IconButton(
                      onPressed: () => setState(() => _hidden = !_hidden),
                      tooltip: _hidden ? '비밀번호 보기' : '비밀번호 숨기기',
                      icon: Icon(
                        _hidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.textSub,
                      ),
                    )
                  : null,
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(
            widget.errorText!,
            style: const TextStyle(fontSize: 14, color: AppColors.dangerText),
          ),
        ],
      ],
    );
  }
}
