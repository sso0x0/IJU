import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/router.dart';
import '../../app/diet.dart';
import '../../app/session.dart';
import '../../widgets/diet_picker.dart';
import '../../widgets/iju_button.dart';
import '../../widgets/iju_tab_bar.dart';
import '../login/auth_session.dart';
import '../reward/coupon_list.dart';

/// 내 정보 탭: 닉네임 · 모국어 · 포인트 · 쿠폰 · 학습 기록.
/// Figma에는 이 화면이 없어 기존 카드·쿠폰 스타일로 만들었습니다.
/// TODO(개발자1): 로그인 사용자 정보(GET /users/{id})로 교체. 지금은 시연용 고정 데이터입니다.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const _languages = {
    'vi': 'Tiếng Việt',
    'en': 'English',
    'fil': 'Filipino',
    'km': 'ភាសាខ្មែរ',
    'ko': '한국어',
  };

  @override
  Widget build(BuildContext context) {
    final language = _languages[AppSession.language] ?? AppSession.language;

    return IjuTabScaffold(
      tab: IjuTab.profile,
      title: '내 정보',
      sub: 'Thông tin của tôi',
      children: [
        _ProfileCard(
          nickname: AppSession.nickname ?? 'Nguyen',
          level: 2,
          points: 320,
        ),
        const SizedBox(height: 10),
        const _Stats(
          items: [('완료 미션', '1개'), ('복습 문장', '3개'), ('연속 학습', '4일')],
        ),
        // 내 쿠폰: GET /coupons, 누르면 사장님 코드로 사용 처리 (개발자3)
        const MyCoupons(),
        const IjuListTitle('설정'),
        // 식단 바텀시트에서 저장하면 바로 바뀌도록 지켜봅니다.
        ValueListenableBuilder(
          valueListenable: AppSession.diets,
          builder: (context, diets, _) => _SettingsGroup(
            rows: [
              _SettingRow(
                label: '모국어',
                value: language,
                onTap: () => context.push(AppRoutes.onboarding),
              ),
              _SettingRow(
                label: '식단 · 종교',
                value: dietLabels(diets) ?? '고르기',
                onTap: () => showDietSheet(context),
              ),
              _SettingRow(
                label: '닉네임',
                value: AppSession.nickname ?? 'Nguyen',
              ),
              const _SettingRow(label: '비밀번호', value: '바꾸기'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '실명, 전화번호, 체류 자격은 받지 않아요.',
          style: TextStyle(fontSize: 13, color: AppColors.textSub),
        ),
        const SizedBox(height: 20),
        IjuButton(
          label: '로그아웃',
          type: IjuButtonType.secondary,
          onPressed: () async {
            await AuthSession.clear();
            if (context.mounted) context.go(AppRoutes.login);
          },
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.nickname,
    required this.level,
    required this.points,
  });

  final String nickname;
  final int level;
  final int points;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Text(
              nickname.characters.first,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nickname,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '레벨 $level · 동네 가게 연습 중',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSub,
                  ),
                ),
              ],
            ),
          ),
          PointsBadge(points: points),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.items});

  /// (항목, 값)
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          for (final (label, value) in items)
            Expanded(
              child: Column(
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSub,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.rows});

  final List<_SettingRow> rows;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, indent: 16, color: AppColors.divider),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.value, this.onTap});

  final String label;
  final String value;

  /// TODO(개발자1): 닉네임·비밀번호 바꾸기 화면이 생기면 연결
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 15, color: AppColors.text),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  color: onTap == null ? AppColors.textSub : AppColors.primary,
                  fontWeight: onTap == null ? FontWeight.w400 : FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
