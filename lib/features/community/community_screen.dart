import 'package:material_ui/material_ui.dart';

import '../../app/languages.dart';

import '../../app/colors.dart';
import '../../app/session.dart';
import '../../app/theme.dart';
import '../../widgets/iju_tab_bar.dart';
import '../../widgets/place_map.dart';
import '../login/auth_api.dart';
import '../practice/speech.dart';
import 'community_api.dart';
import 'post_card.dart';
import 'write_post_sheet.dart';

/// G6 커뮤니티 탭: 다른 사람들이 어느 가게에서 어떤 문장을 말했는지. 담당: 개발자1
///
/// 위에는 글을 가게 위치에 말풍선으로 띄운 지도, 아래는 글 목록입니다.
/// 기본은 전체 글이고, '팔로우한 사람만'을 체크하면 팔로우한 사람 글만 봐요.
/// 글쓰기 · 팔로우는 로그인해야 할 수 있어요.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _speech = Speech();
  CommunityFeed? _feed;

  /// '커뮤니티 지도에 공유'를 켠 사람들의 가게 (지도에만 보여요)
  List<SharedPlace> _shared = const [];
  bool _followingOnly = false;
  int _loadId = 0;

  /// 아래쪽 다음 10개를 불러오는 중
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _speech.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = ++_loadId;
    final (feed, shared) = await (
      CommunityApi.posts(following: _followingOnly),
      loadSharedPlaces(following: _followingOnly),
    ).wait;
    if (mounted && id == _loadId) {
      setState(() {
        _feed = feed;
        _shared = shared;
        _loadingMore = false;
      });
    }
  }

  /// 목록 끝에 가까워지면 다음 10개를 붙여요.
  Future<void> _loadMore() async {
    final feed = _feed;
    if (feed == null || !feed.hasMore || _loadingMore) return;
    final id = _loadId;
    setState(() => _loadingMore = true);
    final next = await CommunityApi.posts(
      following: _followingOnly,
      offset: feed.posts.length,
    );
    if (!mounted || id != _loadId) return;
    final seen = {for (final p in feed.posts) p.id};
    setState(() {
      _feed = CommunityFeed(
        [
          ...feed.posts,
          for (final p in next.posts)
            if (!seen.contains(p.id)) p,
        ],
        offline: next.offline,
        hasMore: next.hasMore && !next.offline,
      );
      _loadingMore = false;
    });
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis == Axis.vertical && n.metrics.extentAfter < 400) {
      _loadMore();
    }
    return false;
  }

  void _toast(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  bool _needLogin(String what) {
    if (AppSession.loggedIn) return false;
    _toast('로그인하면 $what 수 있어요');
    return true;
  }

  void _setFollowingOnly(bool on) {
    if (on && _needLogin('팔로우한 사람 글만 볼')) return;
    setState(() {
      _followingOnly = on;
      _feed = null;
    });
    _load();
  }

  Future<void> _write() async {
    if (_needLogin('글을 쓸')) return;
    final post = await showWritePostSheet(context);
    if (post == null || !mounted) return;
    _toast('글을 올렸어요');
    if (!_followingOnly) {
      setState(
        () => _feed = (_feed ?? const CommunityFeed([])).withPosts([
          post,
          ...?_feed?.posts,
        ]),
      );
    }
  }

  Future<void> _toggleFollow(CommunityPost post) async {
    if (_needLogin('팔로우할')) return;
    final on = !post.following;
    void apply(bool value) => setState(() {
      final posts = [
        for (final p in _feed?.posts ?? const <CommunityPost>[])
          if (p.userId == post.userId) p.withFollowing(value) else p,
      ];
      // '팔로우한 사람만'에서 팔로우를 끊으면 그 사람 글은 목록에서 빠져요.
      _feed = (_feed ?? const CommunityFeed([])).withPosts([
        for (final p in posts)
          if (!_followingOnly || p.following) p,
      ]);
    });
    apply(on);
    try {
      await CommunityApi.follow(post.userId, on: on);
      _toast(on ? '${post.nickname}님을 팔로우해요' : '팔로우를 끊었어요');
    } on AuthException catch (e) {
      if (!mounted) return;
      _toast(e.message);
      _load();
    }
  }

  Future<void> _delete(CommunityPost post) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('글을 지울까요?'),
        content: const Text('지운 글은 되돌릴 수 없어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('지우기'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await CommunityApi.delete(post.id);
      setState(
        () => _feed = (_feed ?? const CommunityFeed([])).withPosts([
          for (final p in _feed?.posts ?? const <CommunityPost>[])
            if (p.id != post.id) p,
        ]),
      );
    } on AuthException catch (e) {
      _toast(e.message);
    }
  }

  void _showPost(CommunityPost post) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: PostCard(post: post, onListen: () => _speak(post.sentence)),
    ),
  );

  Future<void> _speak(String text) async {
    try {
      await _speech.speak(text);
    } catch (_) {
      _toast('이 기기에서는 소리를 낼 수 없어요');
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = _feed;
    final posts = feed?.posts ?? const <CommunityPost>[];
    // 아래로 내리면 다음 10개를 이어서 불러와요.
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: IjuTabScaffold(
        tab: IjuTab.community,
        title: '커뮤니티',
        // 'Community · What…'를 두 줄로 나눠 보여 줘요.
        sub: nt('Cộng đồng · Mọi người đã gọi gì ở đâu')
            .replaceFirst(' · ', '\n'),
        trailing: _WriteButton(onTap: _write),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: SizedBox(
              height: 280,
              child: PlaceMap(
                zoom: 15,
                pins: [
                  // 같은 가게에 글이 여러 개면 가장 최근 글 하나만 말풍선으로.
                  for (final p in {
                    for (final p in posts.reversed)
                      if (p.hasPosition) p.storeName: p,
                  }.values)
                    MapPin(
                      lat: p.lat!,
                      lng: p.lng!,
                      width: 210,
                      height: 104,
                      alignment: Alignment.topCenter,
                      onTap: () => _showPost(p),
                      child: _SentenceBubble(post: p),
                    ),
                  // 지도 공유: 글이 없는 가게만 (가게마다 가장 최근 문장 하나)
                  for (final s in {
                    for (final s in _shared.reversed)
                      if (!posts.any((p) => p.storeName == s.storeName))
                        s.storeName: s,
                  }.values)
                    MapPin(
                      lat: s.lat,
                      lng: s.lng,
                      width: 210,
                      height: 104,
                      alignment: Alignment.topCenter,
                      onTap: () => _showPost(s.toPost()),
                      child: _SentenceBubble(post: s.toPost(), shared: true),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _followingOnly
                          ? '팔로우한 사람이 말한 문장 ${posts.length}개'
                          : '모두가 말한 문장 ${posts.length}개',
                      style: AppText.subtitle.copyWith(fontSize: 18),
                    ),
                    Text(
                      nt('{n} câu mọi người đã nói', {'n': posts.length}),
                      style: AppText.native.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSub,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _FollowingFilter(value: _followingOnly, onChanged: _setFollowingOnly),
          const SizedBox(height: 12),
          if (feed?.offline ?? false)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text('서버에 연결하지 못해서 예시 글을 보여 줘요', style: AppText.caption),
            ),
          if (feed == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (posts.isEmpty)
            _Empty(followingOnly: _followingOnly)
          else
            for (final p in posts) ...[
              PostCard(
                post: p,
                onFollow: () => _toggleFollow(p),
                onDelete: () => _delete(p),
                onListen: () => _speak(p.sentence),
              ),
              const SizedBox(height: 10),
            ],
          if (_loadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (feed != null &&
              !feed.hasMore &&
              posts.length > CommunityApi.pageSize)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  '모든 글을 다 봤어요',
                  style: TextStyle(color: AppColors.textSub),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 헤더 오른쪽 '글쓰기' 버튼.
class _WriteButton extends StatelessWidget {
  const _WriteButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const SizedBox(
          height: 44,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_outlined, size: 18, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  '글쓰기',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
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

/// '팔로우한 사람만 보기' 체크.
class _FollowingFilter extends StatelessWidget {
  const _FollowingFilter({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: value ? AppColors.primary50 : AppColors.background,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 2, 14, 2),
          child: Row(
            children: [
              Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
              const Text(
                '팔로우한 사람만 보기',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              Flexible(
                child: Text(
                  ' · Chỉ người tôi theo dõi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.native.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSub,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 지도 위 말풍선: '가게 · 글쓴이' + 말한 문장 + 꼬리 + 가게 핀.
class _SentenceBubble extends StatelessWidget {
  const _SentenceBubble({required this.post, this.shared = false});

  final CommunityPost post;

  /// 글이 아니라 '지도 공유'로 들어온 문장 (오렌지 핀)
  final bool shared;

  @override
  Widget build(BuildContext context) {
    // 핀 끝이 좌표에 오도록 아래쪽에 붙여 그려요.
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 210),
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${post.storeName} · ${post.nickname}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
              Text(
                '“${post.sentence}”',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.location_on,
          size: 30,
          color: shared ? AppColors.accent : AppColors.primary,
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.followingOnly});

  final bool followingOnly;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        followingOnly
            ? '팔로우한 사람의 글이 아직 없어요.\n전체 글에서 마음에 드는 사람을 팔로우해 보세요.'
            : '아직 글이 없어요. 처음으로 내가 말한 문장을 올려 보세요!',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 15,
          height: 1.5,
          color: AppColors.textBody,
        ),
      ),
    );
  }
}
