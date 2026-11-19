import 'package:material_ui/material_ui.dart';

import '../app/colors.dart';
import '../app/theme.dart';

/// 굵은 한국어 + 회색 모국어 보조 문구 (예: '닉네임 · ${nt('Biệt danh')}').
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.sub});

  final String text;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
        children: [
          if (sub != null)
            TextSpan(
              text: ' · $sub',
              style: AppText.native.copyWith(
                fontSize: 14,
                color: AppColors.textSub,
              ),
            ),
        ],
      ),
    );
  }
}

/// 개인정보 안내 한 줄.
class PrivacyNote extends StatelessWidget {
  const PrivacyNote({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      '실명, 전화번호, 체류 자격은 받지 않아요.',
      style: TextStyle(fontSize: 14, color: AppColors.textSub),
    );
  }
}
