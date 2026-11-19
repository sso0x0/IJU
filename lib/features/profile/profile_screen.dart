import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/languages.dart';
import '../../app/theme.dart';
import '../../app/router.dart';
import '../../app/diet.dart';
import '../../app/session.dart';
import '../../widgets/diet_picker.dart';
import '../../widgets/iju_button.dart';
import '../../widgets/iju_header.dart';
import '../../widgets/iju_tab_bar.dart';
import '../../widgets/iju_text_field.dart';
import '../../widgets/section_label.dart';
import '../community/community_api.dart';
import '../community/post_card.dart';
import '../login/auth_api.dart';
import '../login/auth_session.dart';
import '../order_map/order_place_store.dart';
import '../review/practice_link.dart';
import '../review/review_store.dart';
import '../reward/coupon_list.dart';

/// 마이페이지 탭 (G3). 한눈에 보이게 간단한 목록으로 나눴어요.
///
/// - 내 기록: 내 지도 · 내 쿠폰 · 내가 말한 문장 · 커뮤니티에 쓴 글 (누르면 각 화면)
/// - 설정: 모국어 · 식단·종교 · 닉네임 · 비밀번호
///
/// 포인트·학습 기록은 GET /me/stats, 닉네임·모국어는 PATCH /auth/me,
/// 비밀번호는 POST /auth/password.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  _UserStats? _stats;
  late final Future<List<CommunityPost>> _posts = CommunityApi.myPosts();

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

  Future<void> _changeLanguage() async {
    final changed = await _sheet(const _LanguageSheet());
    if (changed == true && mounted) setState(() {});
  }

  void _openPage(String title, String sub, Widget body) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _SubPage(title: title, sub: sub, child: body),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    final loggedIn = AppSession.loggedIn;
    // 구글로 가입한 계정은 비밀번호가 없습니다.
    final hasPassword = loggedIn && AppSession.authProvider != 'google';
    String count(int? n, String unit) => n == null ? '-' : '$n$unit';
    final places = OrderPlaceStore.items.value;
    final stores = places.map((p) => p.storeName).toSet().length;

    return IjuTabScaffold(
      tab: IjuTab.profile,
      title: '마이페이지',
      sub: nt('Trang cá nhân'),
      children: [
        _ProfileCard(
          nickname: AppSession.nickname ?? '-',
          points: stats?.points ?? 0,
        ),
        const SizedBox(height: 10),
        _Stats(
          items: [
            ('가 본 가게', '$stores곳'),
            ('복습 문장', count(stats?.reviewCount, '개')),
            ('연속 학습', count(stats?.streakDays, '일')),
          ],
        ),
        _GroupTitle('내 기록', nt('Hoạt động của tôi')),
        _ListGroup(
          rows: [
            _ListRow(
              icon: Icons.map_outlined,
              title: '내 지도',
              sub: nt('Bản đồ của tôi'),
              value: '$stores곳 · 문장 ${places.length}개',
              onTap: () => context.push(AppRoutes.orderMap),
            ),
            _ListRow(
              icon: Icons.confirmation_number_outlined,
              title: '내 쿠폰',
              sub: nt('Phiếu giảm giá'),
              value: '쿠폰함',
              onTap: () =>
                  _openPage('내 쿠폰', nt('Phiếu giảm giá'), const MyCoupons()),
            ),
            ValueListenableBuilder(
              valueListenable: ReviewStore.items,
              builder: (context, items, _) => _ListRow(
                icon: Icons.record_voice_over_outlined,
                title: '내가 말한 문장',
                sub: nt('Câu tôi đã nói'),
                value: '${items.length}개',
                onTap: () => _openPage(
                  '내가 말한 문장',
                  nt('Câu tôi đã nói'),
                  const _MySentences(),
                ),
              ),
            ),
            FutureBuilder<List<CommunityPost>>(
              future: _posts,
              builder: (context, snap) => _ListRow(
                icon: Icons.forum_outlined,
                title: '커뮤니티에 쓴 글',
                sub: nt('Bài viết của tôi'),
                value: snap.hasData ? '${snap.data!.length}개' : '',
                onTap: () async {
                  _openPage(
                    '커뮤니티에 쓴 글',
                    nt('Bài viết của tôi'),
                    _MyPosts(posts: snap.data ?? const []),
                  );
                },
              ),
            ),
          ],
        ),
        _GroupTitle('설정', nt('Cài đặt')),
        // 식단 바텀시트에서 저장하면 바로 바뀌도록 지켜봅니다.
        ValueListenableBuilder(
          valueListenable: AppSession.diets,
          builder: (context, diets, _) => _ListGroup(
            rows: [
              _ListRow(
                icon: Icons.translate,
                title: '모국어',
                sub: nt('Ngôn ngữ'),
                value: languageOf(AppSession.language).name,
                onTap: loggedIn ? _changeLanguage : null,
              ),
              _ListRow(
                icon: Icons.restaurant_menu_outlined,
                title: '식단 · 종교',
                sub: nt('Ăn kiêng · tôn giáo'),
                value: dietLabels(diets) ?? '고르기',
                onTap: () => showDietSheet(context),
              ),
              _ListRow(
                icon: Icons.badge_outlined,
                title: '닉네임',
                sub: nt('Biệt danh'),
                value: AppSession.nickname ?? '-',
                onTap: loggedIn ? _changeNickname : null,
              ),
              if (hasPassword)
                _ListRow(
                  icon: Icons.lock_outline,
                  title: '비밀번호',
                  sub: nt('Mật khẩu'),
                  value: '바꾸기',
                  onTap: _changePassword,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ListGroup(
          rows: [
            _ListRow(
              icon: Icons.logout,
              title: '로그아웃',
              sub: nt('Đăng xuất'),
              danger: true,
              onTap: () async {
                await AuthSession.clear();
                if (context.mounted) context.go(AppRoutes.login);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          '실명, 전화번호, 체류 자격은 받지 않아요.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textSub),
        ),
      ],
    );
  }
}

/// 목록 위 작은 제목 ('내 기록 · ${nt('Hoạt động của tôi')}').
class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.ko, this.native);

  final String ko;
  final String native;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
      child: Text.rich(
        TextSpan(
          text: ko,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textBody,
          ),
          children: [
            TextSpan(
              text: ' · $native',
              style: AppText.native.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppColors.textSub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 흰 카드 안에 줄을 구분선으로 나눠 담아요.
class _ListGroup extends StatelessWidget {
  const _ListGroup({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                indent: 56,
                color: AppColors.divider,
              ),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// 목록 한 줄: 아이콘 · 이름(+모국어) · 오른쪽 값 · 화살표.
class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.icon,
    required this.title,
    required this.sub,
    this.value = '',
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String sub;
  final String value;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.dangerText : AppColors.text;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: danger ? AppColors.dangerText : AppColors.primaryDark,
              ),
              const SizedBox(width: 18),
              // 제목 쪽을 넓게 줘서 모국어 보조 문구가 두 줄로 꺾이지 않게 해요.
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    Text(
                      sub,
                      style: AppText.native.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSub,
                      ),
                    ),
                  ],
                ),
              ),
              if (value.isNotEmpty)
                Flexible(
                  flex: 2,
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSub,
                    ),
                  ),
                ),
              if (onTap != null && !danger)
                const Icon(Icons.chevron_right, color: AppColors.borderStrong),
            ],
          ),
        ),
      ),
    );
  }
}

/// 내 쿠폰 · 커뮤니티에 쓴 글 화면 틀.
class _SubPage extends StatelessWidget {
  const _SubPage({required this.title, required this.sub, required this.child});

  final String title;
  final String sub;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IjuHeader(title: title, subtitle: sub),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [child],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 내가 말한 문장 목록 (복습 목록 전체). 줄마다 복습하기.
class _MySentences extends StatelessWidget {
  const _MySentences();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: ReviewStore.items,
      builder: (context, items, _) {
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              '말하기 연습을 하면 여기에 쌓여요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppColors.textSub),
            ),
          );
        }
        return _ListGroup(
          rows: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.sentence,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                            ),
                          ),
                          if (item.meaning.isNotEmpty)
                            Text(
                              item.meaning,
                              style: AppText.native.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textSub,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            item.done
                                ? '복습 3단계 끝'
                                : '복습 ${item.cleared}/3단계 · 다음 복습 ${item.dueLabel(DateTime.now())}',
                            style: AppText.caption.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => practiceSentence(
                        context,
                        sentence: item.sentence,
                        meaning: item.meaning,
                      ),
                      icon: const Icon(Icons.mic_none, size: 18),
                      label: const Text('복습하기'),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MyPosts extends StatelessWidget {
  const _MyPosts({required this.posts});

  final List<CommunityPost> posts;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text(
          '아직 쓴 글이 없어요. 커뮤니티에 내가 말한 문장을 올려 보세요',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: AppColors.textSub),
        ),
      );
    }
    return Column(
      children: [
        for (final p in posts) ...[
          PostCard(post: p),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// 모국어 바꾸기 (PATCH /auth/me language).
class _LanguageSheet extends StatefulWidget {
  const _LanguageSheet();

  @override
  State<_LanguageSheet> createState() => _LanguageSheetState();
}

class _LanguageSheetState extends State<_LanguageSheet> {
  bool _busy = false;

  Future<void> _pick(String code) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await AuthSession.update(await AuthApi.updateMe({'language': code}));
      if (mounted) Navigator.pop(context, true);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('모국어', style: AppText.subtitle),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: appLanguages.length,
                separatorBuilder: (_, _) => const Divider(
                  height: 1,
                  indent: 20,
                  color: AppColors.divider,
                ),
                itemBuilder: (context, i) {
                  final l = appLanguages[i];
                  final on = l.code == AppSession.language;
                  return ListTile(
                    onTap: () => _pick(l.code),
                    title: Text(
                      l.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text('${l.korean} · ${l.english}'),
                    trailing: on
                        ? const Icon(
                            Icons.check_circle,
                            color: AppColors.primary,
                          )
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// GET /me/stats 응답 (server/app/schemas.py UserStatsOut)
class _UserStats {
  const _UserStats({
    required this.points,
    required this.completedMissions,
    required this.reviewCount,
    required this.streakDays,
  });

  factory _UserStats.fromJson(Map<String, dynamic> json) => _UserStats(
    points: json['points'] as int? ?? 0,
    completedMissions: json['completed_missions'] as int? ?? 0,
    reviewCount: json['review_count'] as int? ?? 0,
    streakDays: json['streak_days'] as int? ?? 0,
  );

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
  const _ProfileCard({required this.nickname, required this.points});

  final String nickname;
  final int points;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              nickname.characters.first,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
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
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '한국어 연습 중',
                  style: const TextStyle(
                    fontSize: 14,
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
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          for (final (label, value) in items)
            Expanded(
              child: Column(
                children: [
                  Text(
                    value,
                    style: AppText.number.copyWith(
                      fontSize: 22,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textBody,
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
