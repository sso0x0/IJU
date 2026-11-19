import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/router.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/iju_button.dart';
import '../../widgets/iju_icon.dart';
import '../../widgets/iju_text_field.dart';
import '../../widgets/section_label.dart';

/// Figma '0 로그인'. 닉네임 + 4자리 비밀번호로 다시 들어옵니다.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nickname = TextEditingController();
  final _pin = TextEditingController();

  @override
  void dispose() {
    _nickname.dispose();
    _pin.dispose();
    super.dispose();
  }

  void _login() {
    // TODO: 닉네임 + PIN 확인 API가 생기면 연결
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              sliver: SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.appName,
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.appTagline,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textBody,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      '다시 오셨네요!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Chào mừng bạn quay lại',
                      style: TextStyle(fontSize: 14, color: AppColors.textSub),
                    ),
                    const SizedBox(height: 28),
                    const SectionLabel('닉네임', sub: 'Biệt danh'),
                    const SizedBox(height: 8),
                    IjuTextField(controller: _nickname, hintText: 'Nguyen'),
                    const SizedBox(height: 28),
                    const SectionLabel('비밀번호 4자리', sub: 'Mã PIN 4 số'),
                    const SizedBox(height: 8),
                    _PinInput(controller: _pin),
                    const SizedBox(height: 8),
                    const PrivacyNote(),
                    const Spacer(),
                    const SizedBox(height: 28),
                    IjuButton(label: '로그인 · Đăng nhập', onPressed: _login),
                    const SizedBox(height: 10),
                    IjuButton(
                      label: '처음이에요 · Bắt đầu mới',
                      type: IjuButtonType.secondary,
                      onPressed: () => context.push(AppRoutes.onboarding),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: IjuTextLink(
                        label: '비밀번호를 잊었어요',
                        onTap: () {
                          // TODO: 비밀번호 재설정 흐름
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Figma 'PinBoxes'. 숫자 칸 4개 위에 보이지 않는 입력창을 겹쳐 키보드 입력을 받습니다.
class _PinInput extends StatelessWidget {
  const _PinInput({required this.controller});

  final TextEditingController controller;

  static const _length = 4;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        children: [
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final filled = controller.text.length;
              return Row(
                children: [
                  for (var i = 0; i < _length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: _PinBox(filled: i < filled, active: i == filled),
                    ),
                  ],
                ],
              );
            },
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: _length,
                showCursor: false,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(counterText: ''),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinBox extends StatelessWidget {
  const _PinBox({required this.filled, required this.active});

  final bool filled;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? AppColors.primarySoft : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: active
            ? Border.all(color: AppColors.primary, width: 2)
            : Border.all(color: AppColors.border),
      ),
      child: filled ? const IjuIcon(IjuIcons.pinDot, size: 12) : null,
    );
  }
}
