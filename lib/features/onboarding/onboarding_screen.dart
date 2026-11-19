import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/diet.dart';
import '../../app/languages.dart';
import '../../app/router.dart';
import '../../app/session.dart';
import '../../app/theme.dart';
import '../../widgets/iju_button.dart';
import '../../widgets/iju_text_field.dart';
import '../../widgets/progress.dart';
import '../login/auth_api.dart';
import '../login/auth_session.dart';
import '../login/google_signup_screen.dart';

/// 온보딩에서 고른 값. 회원가입(아이디·구글) 때 계정에 같이 저장해요.
class OnboardingResult {
  const OnboardingResult({
    required this.language,
    required this.residenceType,
    required this.nickname,
    required this.diets,
  });

  /// 서버 Language 코드 (vi, fil, ...)
  final String language;

  /// worker · marriage · student · visitor
  final String residenceType;
  final String nickname;
  final Set<Diet> diets;

  Map<String, Object?> toJson() => {
    'language': language,
    'residence_type': residenceType,
    'nickname': nickname,
    'diets': [for (final d in diets) d.name],
  };
}

/// A3~A6 온보딩: 모국어 → 나는 누구(+닉네임) → 식단 → 종교. 담당: 개발자1
///
/// - 처음이에요(로그인 화면) → 온보딩 → 아이디 회원가입 ([AppRoutes.signup])
/// - 처음 온 구글 계정([googleArgs]) → 온보딩 → 구글 가입 ([AppRoutes.googleSignup])
/// - 로그인했는데 모국어가 없는 예전 계정 → 온보딩 → 계정에 저장하고 홈
///
/// 수준 진단(A7)은 넣지 않았어요.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.googleArgs});

  final GoogleSignupArgs? googleArgs;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

/// 나는 누구 (A4)
const _who = [
  ('worker', '근로자', 'Người lao động', Icons.work_outline),
  ('marriage', '결혼이민자', 'Kết hôn di trú', Icons.home_outlined),
  ('student', '유학생', 'Du học sinh', Icons.menu_book_outlined),
  ('visitor', '여행·방문', 'Du lịch · thăm', Icons.flight_outlined),
];

enum _Religion { islam, judaism, hindu, none }

class _OnboardingScreenState extends State<OnboardingScreen> {
  static final _nicknameRule = RegExp(r'^[가-힣a-zA-Z0-9_]{2,20}$');
  static const _steps = 4;

  int _step = 0;
  String _language = AppSession.language;
  String? _residence;
  final _nickname = TextEditingController(text: AppSession.nickname);
  String? _nicknameError;

  /// 채식 단계 (하나만, 없으면 null)
  Diet? _vegetarian;
  _Religion _religion = _Religion.none;

  /// 종교를 음식에서 어떻게 지키는지 ([_howOptions]의 번호)
  int _how = 0;

  /// '음식은 따로 지키지 않아요'가 아니면 종교를 판정에 넣어요.
  bool get _observe =>
      _religion != _Religion.none && _howOptions(_religion)[_how].$1;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    for (final d in AppSession.diets.value) {
      if (d.religion) {
        _religion = _Religion.values.byName(d.name);
      } else {
        _vegetarian = d;
      }
    }
  }

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  Set<Diet> get _diets => {
    ?_vegetarian,
    if (_observe)
      switch (_religion) {
        _Religion.islam => Diet.islam,
        _Religion.judaism => Diet.judaism,
        _Religion.hindu => Diet.hindu,
        _Religion.none => null,
      },
  }.whereType<Diet>().toSet();

  OnboardingResult get _result => OnboardingResult(
    language: _language,
    residenceType: _residence ?? 'worker',
    nickname: _nickname.text.trim(),
    diets: _diets,
  );

  bool get _canNext => switch (_step) {
    1 => _residence != null && _nickname.text.trim().isNotEmpty,
    _ => true,
  };

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.login);
    }
  }

  Future<void> _next() async {
    if (_step == 0) {
      // 고른 언어로 바로 보조 문구를 바꿔 보여 줘요.
      AppSession.language = _language;
    }
    if (_step == 1 && !_nicknameRule.hasMatch(_nickname.text.trim())) {
      setState(() => _nicknameError = '한글, 영문, 숫자, 밑줄 2~20자로 입력해 주세요.');
      return;
    }
    if (_step < _steps - 1) {
      setState(() {
        _step++;
        _nicknameError = null;
      });
      return;
    }
    await _finish();
  }

  Future<void> _finish() async {
    final result = _result;
    AppSession.language = result.language;
    AppSession.diets.value = result.diets;
    if (widget.googleArgs case final g?) {
      context.push(
        AppRoutes.googleSignup,
        extra: GoogleSignupArgs(
          idToken: g.idToken,
          email: g.email,
          onboarding: result,
        ),
      );
      return;
    }
    if (!AppSession.loggedIn) {
      context.push(AppRoutes.signup, extra: result);
      return;
    }
    // 예전 계정: 계정에 저장하고 홈으로
    setState(() => _busy = true);
    try {
      final body = result.toJson();
      if (result.nickname == AppSession.nickname) body.remove('nickname');
      await AuthSession.update(await AuthApi.updateMe(body));
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      if (e.code == 'NICKNAME_TAKEN' || e.code == 'INVALID_NICKNAME') {
        setState(() {
          _step = 1;
          _nicknameError = e.message;
        });
        return;
      }
      if (!e.offline) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
        return;
      }
    }
    if (mounted) context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final (title, sub, body) = switch (_step) {
      0 => (
        '어떤 말이 편해요?',
        'Chọn ngôn ngữ · Pumili ng wika · Choose language',
        _languagePage(),
      ),
      1 => ('나는 누구예요?', nt('Bạn là ai?'), _whoPage()),
      2 => ('어떤 식단을 지켜요?', nt('Bạn theo chế độ ăn nào?'), _dietPage()),
      _ => (
        '종교가 있어요?',
        nt('Bạn có tôn giáo không? (không bắt buộc)'),
        _religionPage(),
      ),
    };
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _back,
                      tooltip: '뒤로',
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: SegmentBar(total: _steps, filled: _step + 1),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.title),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: AppText.native.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSub,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: body),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: IjuButton(
                  label: _busy
                      ? '저장 중…'
                      : _step == _steps - 1
                      ? '다 됐어요'
                      : '다음',
                  sub: _step == _steps - 1 ? nt('Xong') : nt('Tiếp theo'),
                  onPressed: _canNext && !_busy ? _next : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- A3 모국어

  Widget _languagePage() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      itemCount: appLanguages.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final l = appLanguages[i];
        return _SelectTile(
          selected: _language == l.code,
          onTap: () => setState(() => _language = l.code),
          title: l.name,
          sub: '${l.korean} · ${l.english}',
        );
      },
    );
  }

  // ---------------------------------------------------------------- A4 나는 누구

  Widget _whoPage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.05,
          children: [
            for (final (code, ko, vi, icon) in _who)
              _WhoCard(
                icon: icon,
                title: ko,
                sub: nt(vi),
                selected: _residence == code,
                onTap: () => setState(() => _residence = code),
              ),
          ],
        ),
        const SizedBox(height: 20),
        _Label('닉네임', nt('Biệt danh')),
        const SizedBox(height: 8),
        IjuTextField(
          controller: _nickname,
          hintText: 'Lan',
          errorText: _nicknameError,
          onChanged: (_) => setState(() => _nicknameError = null),
        ),
        const SizedBox(height: 6),
        Text(
          '앱에서 부를 이름이에요. 실명이 아니어도 돼요. · '
          '${nt('Tên gọi trong ứng dụng, không cần tên thật.')}',
          style: AppText.caption.copyWith(fontSize: 13),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- A5 식단

  Widget _dietPage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      children: [
        _SelectTile(
          selected: _vegetarian == null,
          onTap: () => setState(() => _vegetarian = null),
          title: '가리는 음식 없어요',
          sub: nt('Tôi ăn được mọi thứ'),
          icon: Icons.restaurant_outlined,
        ),
        for (final d in Diet.vegetarian) ...[
          const SizedBox(height: 8),
          _SelectTile(
            selected: _vegetarian == d,
            onTap: () => setState(() => _vegetarian = d),
            title: d.label,
            sub: dietAbout(d),
            icon: Icons.eco_outlined,
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------- A6 종교

  /// 종교별 '음식은 어떻게 지켜요?' 보기 (지키는지, 한국어, 모국어).
  List<(bool, String, String)> _howOptions(_Religion religion) =>
      switch (religion) {
        _Religion.islam => [
          (true, '할랄 음식만 먹어요', nt('Chỉ ăn đồ Halal')),
          (true, '돼지고기·술만 피해요', nt('Chỉ tránh thịt heo, rượu')),
          (false, '음식은 따로 지키지 않아요', nt('Không kiêng gì')),
        ],
        _Religion.judaism => [
          (true, '코셔 음식만 먹어요', nt('Chỉ ăn đồ Kosher')),
          (true, '돼지고기·조개류만 피해요', nt('Chỉ tránh thịt heo, hải sản có vỏ')),
          (false, '음식은 따로 지키지 않아요', nt('Không kiêng gì')),
        ],
        _Religion.hindu => [
          (true, '소고기를 안 먹어요', nt('Không ăn thịt bò')),
          (false, '음식은 따로 지키지 않아요', nt('Không kiêng gì')),
        ],
        _Religion.none => const <(bool, String, String)>[],
      };

  Widget _religionPage() {
    final options = _howOptions(_religion);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (r, ko, vi) in [
              (_Religion.islam, '이슬람', nt('Hồi giáo')),
              (_Religion.judaism, '유대교', nt('Do Thái')),
              (_Religion.hindu, '힌두교', 'Hindu'),
              (_Religion.none, '없음', nt('Không')),
            ])
              _Chip(
                label: ko,
                sub: nt(vi),
                selected: _religion == r,
                onTap: () => setState(() {
                  _religion = r;
                  _how = 0;
                }),
              ),
          ],
        ),
        if (options.isNotEmpty) ...[
          const SizedBox(height: 20),
          _Label('음식은 어떻게 지켜요?', nt('Bạn giữ thế nào?')),
          const SizedBox(height: 8),
          for (var i = 0; i < options.length; i++) ...[
            _SelectTile(
              selected: _how == i,
              onTap: () => setState(() => _how = i),
              title: options[i].$2,
              sub: options[i].$3,
            ),
            const SizedBox(height: 8),
          ],
        ],
        const SizedBox(height: 8),
        Text(
          '고른 내용은 메뉴 판정(먹어도 돼요·물어보세요·피하세요)에 써요. '
          '마이페이지에서 언제든 바꿀 수 있어요.',
          style: AppText.caption.copyWith(fontSize: 13),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.ko, this.native);

  final String ko;
  final String native;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: ko,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: AppColors.text,
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
    );
  }
}

/// 한 줄 선택 칸 (언어 · 식단 · 지키는 방식).
class _SelectTile extends StatelessWidget {
  const _SelectTile({
    required this.selected,
    required this.onTap,
    required this.title,
    required this.sub,
    this.icon,
  });

  final bool selected;
  final VoidCallback onTap;
  final String title;
  final String sub;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary50 : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: AppText.native.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSub,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? AppColors.primary : AppColors.borderStrong,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WhoCard extends StatelessWidget {
  const _WhoCard({
    required this.icon,
    required this.title,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary50 : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.primary50,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      icon,
                      color: selected ? Colors.white : AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                  if (selected)
                    const Icon(Icons.check_circle, color: AppColors.primary),
                ],
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              Text(
                sub,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.native.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSub,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.text;
    return Material(
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
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  Icon(Icons.check, size: 16, color: fg),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  sub,
                  style: AppText.native.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
