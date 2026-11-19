import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/router.dart';
import '../../app/diet.dart';
import '../../app/session.dart';
import '../../widgets/diet_picker.dart';
import '../../widgets/iju_button.dart';
import '../../widgets/iju_tab_bar.dart';
import '../../widgets/iju_text_field.dart';
import '../../widgets/section_label.dart';
import '../login/auth_api.dart';
import '../login/auth_session.dart';
import '../reward/coupon_list.dart';

/// 내 정보 탭: 닉네임 · 모국어 · 포인트 · 쿠폰 · 학습 기록.
/// Figma에는 이 화면이 없어 기존 카드·쿠폰 스타일로 만들었습니다.
///
/// 로그인했으면 레벨·포인트·학습 기록을 GET /me/stats에서 받고, 닉네임(PATCH /auth/me)과
/// 비밀번호(POST /auth/password)를 바꿀 수 있습니다. 로그인 없이 둘러볼 때는 시연 값을 보여 줍니다.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _languages = {
    'vi': 'Tiếng Việt',
    'en': 'English',
    'fil': 'Filipino',
    'km': 'ភាសាខ្មែរ',
    'ko': '한국어',
  };

  /// 로그인 없이 둘러볼 때 보여 주는 시연 값
  static const _demo = _UserStats(
    level: 2,
    points: 320,
    completedMissions: 1,
    reviewCount: 3,
    streakDays: 4,
  );

  /// 로그인했는데 아직 못 받았으면 null
  _UserStats? _stats = AppSession.loggedIn ? null : _demo;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (!AppSession.loggedIn) return;
    try {
      final stats = _UserStats.fromJson(await AuthApi.stats());
      if (mounted) setState(() => _stats = stats);
    } on AuthException {
      // 서버에 못 붙으면 '-'로 둡니다.
    }
  }

  Future<bool?> _sheet(Widget child) => showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (_) => child,
  );

  Future<void> _changeNickname() async {
    final changed = await _sheet(const _NicknameSheet());
    if (changed == true && mounted) setState(() {});
  }

  Future<void> _changePassword() async {
    final changed = await _sheet(const _PasswordSheet());
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('비밀번호를 바꿨어요.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = _languages[AppSession.language] ?? AppSession.language;
    final stats = _stats;
    final loggedIn = AppSession.loggedIn;
    // 구글로 가입한 계정은 비밀번호가 없습니다.
    final hasPassword = loggedIn && AppSession.authProvider != 'google';
    String count(int? n, String unit) => n == null ? '-' : '$n$unit';

    return IjuTabScaffold(
      tab: IjuTab.profile,
      title: '내 정보',
      sub: 'Thông tin của tôi',
      children: [
        _ProfileCard(
          nickname: AppSession.nickname ?? 'Nguyen',
          level: stats?.level ?? 1,
          points: stats?.points ?? 0,
        ),
        const SizedBox(height: 10),
        _Stats(
          items: [
            ('완료 미션', count(stats?.completedMissions, '개')),
            ('복습 문장', count(stats?.reviewCount, '개')),
            ('연속 학습', count(stats?.streakDays, '일')),
          ],
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
                onTap: loggedIn ? _changeNickname : null,
              ),
              if (hasPassword)
                _SettingRow(
                  label: '비밀번호',
                  value: '바꾸기',
                  onTap: _changePassword,
                ),
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

/// GET /me/stats 응답 (server/app/schemas.py UserStatsOut)
class _UserStats {
  const _UserStats({
    required this.level,
    required this.points,
    required this.completedMissions,
    required this.reviewCount,
    required this.streakDays,
  });

  factory _UserStats.fromJson(Map<String, dynamic> json) => _UserStats(
    level: json['level'] as int? ?? 1,
    points: json['points'] as int? ?? 0,
    completedMissions: json['completed_missions'] as int? ?? 0,
    reviewCount: json['review_count'] as int? ?? 0,
    streakDays: json['streak_days'] as int? ?? 0,
  );

  final int level;
  final int points;
  final int completedMissions;
  final int reviewCount;
  final int streakDays;
}

/// 바텀시트 공통 틀: 제목 + 입력칸 + 저장 버튼. 키보드에 가리지 않게 올라갑니다.
class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.title,
    required this.children,
    required this.busy,
    required this.onSave,
  });

  final String title;
  final List<Widget> children;
  final bool busy;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
            const SizedBox(height: 24),
            IjuButton(label: busy ? '저장하는 중…' : '저장하기', onPressed: onSave),
          ],
        ),
      ),
    );
  }
}

class _NicknameSheet extends StatefulWidget {
  const _NicknameSheet();

  @override
  State<_NicknameSheet> createState() => _NicknameSheetState();
}

class _NicknameSheetState extends State<_NicknameSheet> {
  late final _nickname = TextEditingController(text: AppSession.nickname);
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final name = _nickname.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '닉네임을 입력해 주세요.');
      return;
    }
    if (name == AppSession.nickname) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() => _busy = true);
    try {
      await AuthSession.update(await AuthApi.updateMe({'nickname': name}));
      if (mounted) Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: '닉네임 바꾸기',
      busy: _busy,
      onSave: _save,
      children: [
        IjuTextField(
          controller: _nickname,
          hintText: 'Nguyen',
          errorText: _error,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
        ),
      ],
    );
  }
}

class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet();

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _check = TextEditingController();
  String? _currentError;
  String? _nextError;
  String? _checkError;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_current, _next, _check]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _currentError = _current.text.isEmpty ? '지금 비밀번호를 입력해 주세요.' : null;
      _nextError = _next.text.length < 8 ? '비밀번호는 8자 이상으로 입력해 주세요.' : null;
      _checkError = _check.text != _next.text ? '새 비밀번호가 서로 달라요.' : null;
    });
    if (_currentError != null || _nextError != null || _checkError != null) {
      return;
    }
    setState(() => _busy = true);
    try {
      await AuthApi.changePassword(_current.text, _next.text);
      if (mounted) Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        // 지금 비밀번호가 틀리면 그 칸에, 나머지는 새 비밀번호 칸에 띄웁니다.
        if (e.code == 'WRONG_PASSWORD') {
          _currentError = e.message;
        } else {
          _nextError = e.message;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: '비밀번호 바꾸기',
      busy: _busy,
      onSave: _save,
      children: [
        const SectionLabel('지금 비밀번호'),
        const SizedBox(height: 8),
        IjuTextField(
          controller: _current,
          obscureText: true,
          errorText: _currentError,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        const SectionLabel('새 비밀번호', sub: '8자 이상'),
        const SizedBox(height: 8),
        IjuTextField(
          controller: _next,
          obscureText: true,
          errorText: _nextError,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        const SectionLabel('새 비밀번호 확인'),
        const SizedBox(height: 8),
        IjuTextField(
          controller: _check,
          obscureText: true,
          errorText: _checkError,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
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

  /// 없으면 바꿀 수 없는 값 (회색 글씨)
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
