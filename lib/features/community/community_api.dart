import '../../app/session.dart';
import '../login/auth_api.dart';

/// 커뮤니티 글 하나: 누가 · 어느 가게에서 · 어떤 문장을 말했다 + 자유롭게 쓴 말. 담당: 개발자1
class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.userId,
    required this.nickname,
    required this.storeName,
    required this.sentence,
    required this.createdAt,
    this.meaning,
    this.body = '',
    this.lat,
    this.lng,
    this.mine = false,
    this.following = false,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> j) => CommunityPost(
    id: j['id'] as String,
    userId: j['user_id'] as String,
    nickname: j['nickname'] as String? ?? '이주 친구',
    storeName: j['store_name'] as String,
    sentence: j['sentence'] as String,
    meaning: j['meaning'] as String?,
    body: j['body'] as String? ?? '',
    lat: (j['lat'] as num?)?.toDouble(),
    lng: (j['lng'] as num?)?.toDouble(),
    createdAt:
        DateTime.tryParse(j['created_at'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
    mine: j['mine'] as bool? ?? false,
    following: j['following'] as bool? ?? false,
  );

  final String id;
  final String userId;
  final String nickname;
  final String storeName;
  final String sentence;
  final String? meaning;
  final String body;
  final double? lat;
  final double? lng;
  final DateTime createdAt;

  /// 내가 쓴 글
  final bool mine;

  /// 내가 이 글쓴이를 팔로우하는지
  final bool following;

  bool get hasPosition => lat != null && lng != null;

  CommunityPost withFollowing(bool on) => CommunityPost(
    id: id,
    userId: userId,
    nickname: nickname,
    storeName: storeName,
    sentence: sentence,
    meaning: meaning,
    body: body,
    lat: lat,
    lng: lng,
    createdAt: createdAt,
    mine: mine,
    following: on,
  );

  /// '방금' · '5분 전' · '3시간 전' · '2일 전' · '11월 3일'
  String agoLabel(DateTime now) {
    final d = now.difference(createdAt);
    if (d.inMinutes < 1) return '방금';
    if (d.inHours < 1) return '${d.inMinutes}분 전';
    if (d.inDays < 1) return '${d.inHours}시간 전';
    if (d.inDays < 7) return '${d.inDays}일 전';
    return '${createdAt.month}월 ${createdAt.day}일';
  }
}

/// 글 목록 결과. 서버에 못 붙으면 [offline]이고 예시 글을 담습니다.
class CommunityFeed {
  const CommunityFeed(this.posts, {this.offline = false, this.hasMore = false});

  final List<CommunityPost> posts;
  final bool offline;

  /// 아래로 내리면 더 불러올 글이 있는지
  final bool hasMore;

  /// 글만 바꾸고 나머지(오프라인 · 더 있음)는 그대로.
  CommunityFeed withPosts(List<CommunityPost> posts) =>
      CommunityFeed(posts, offline: offline, hasMore: hasMore);
}

abstract final class CommunityApi {
  /// 한 번에 불러오는 글 수
  static const pageSize = 10;

  /// 글 목록 (최신 순) [offset]부터 [pageSize]개. [following]이면 팔로우한 사람 글만.
  static Future<CommunityFeed> posts({
    bool following = false,
    int offset = 0,
  }) async {
    try {
      final json = await AuthApi.communityPosts(
        following: following,
        offset: offset,
        limit: pageSize,
      );
      return CommunityFeed([
        for (final p in json['posts'] as List)
          CommunityPost.fromJson(p as Map<String, dynamic>),
      ], hasMore: json['has_more'] as bool? ?? false);
    } on AuthException {
      // 서버를 켜지 않은 시연·테스트에서도 화면이 비지 않게 예시 글을 보여 줘요.
      return CommunityFeed(
        following || offset > 0 ? const [] : demoPosts(),
        offline: true,
      );
    }
  }

  /// 내가 쓴 글. 로그인하지 않았으면 빈 목록.
  static Future<List<CommunityPost>> myPosts() async {
    if (!AppSession.loggedIn) return const [];
    try {
      final json = await AuthApi.communityPosts(mine: true, limit: 50);
      return [
        for (final p in json['posts'] as List)
          CommunityPost.fromJson(p as Map<String, dynamic>),
      ];
    } on AuthException {
      return const [];
    }
  }

  /// 글을 올립니다. 실패하면 [AuthException]의 message를 그대로 보여 주면 됩니다.
  static Future<CommunityPost> write({
    required String storeName,
    required String sentence,
    String? meaning,
    String body = '',
    double? lat,
    double? lng,
  }) async {
    final json = await AuthApi.writePost({
      'store_name': storeName,
      'sentence': sentence,
      'meaning': meaning,
      'body': body,
      'lat': lat,
      'lng': lng,
    });
    return CommunityPost.fromJson(json);
  }

  static Future<void> delete(String id) => AuthApi.deletePost(id);

  static Future<void> follow(String userId, {required bool on}) =>
      AuthApi.follow(userId, on: on);

  /// 서버에 못 붙을 때 보여 주는 예시 글 (server/app/seed_data.py와 같은 내용).
  static List<CommunityPost> demoPosts() {
    final now = DateTime.now();
    return [
      CommunityPost(
        id: 'demo-1',
        userId: 'demo-minh',
        nickname: 'Minh',
        storeName: '골목식당',
        sentence: '비빔밥 한 그릇 포장으로 주세요.',
        meaning: 'Cho tôi một tô cơm trộn mang về.',
        body: '포장도 말해 봤어요! 사장님이 천천히 들어 주셨어요.',
        lat: 37.6979,
        lng: 127.8876,
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      CommunityPost(
        id: 'demo-2',
        userId: 'demo-sokha',
        nickname: 'Sokha',
        storeName: '새벽반찬',
        sentence: '두부조림 한 팩 주세요.',
        meaning: 'Cho tôi một hộp đậu phụ kho.',
        body: "반찬가게에서는 '한 팩'이라고 하면 돼요.",
        lat: 37.6962,
        lng: 127.8901,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      CommunityPost(
        id: 'demo-3',
        userId: 'demo-minh',
        nickname: 'Minh',
        storeName: '홍천 한우정육점',
        sentence: '국물에 고기 들어가요?',
        meaning: 'Trong nước dùng có thịt không?',
        body: '할랄이라 꼭 물어봐요. 이 문장 쓰기 좋아요.',
        lat: 37.6970,
        lng: 127.8888,
        createdAt: now.subtract(const Duration(days: 4)),
      ),
    ];
  }
}

/// '커뮤니티 지도에 공유'를 켠 사람의 내 지도 가게 하나 (GET /community/shared-places).
class SharedPlace {
  const SharedPlace({
    required this.userId,
    required this.nickname,
    required this.storeName,
    required this.sentence,
    required this.lat,
    required this.lng,
    this.meaning,
    this.mine = false,
    this.following = false,
  });

  factory SharedPlace.fromJson(Map<String, dynamic> j) => SharedPlace(
    userId: j['user_id'] as String,
    nickname: j['nickname'] as String? ?? '이주 친구',
    storeName: j['store_name'] as String,
    sentence: j['sentence'] as String,
    meaning: j['meaning'] as String?,
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
    mine: j['mine'] as bool? ?? false,
    following: j['following'] as bool? ?? false,
  );

  final String userId;
  final String nickname;
  final String storeName;
  final String sentence;
  final String? meaning;
  final double lat;
  final double lng;
  final bool mine;
  final bool following;

  /// 지도에서 눌렀을 때 글 카드로 보여 주려고 글 모양으로 바꿉니다.
  CommunityPost toPost() => CommunityPost(
    id: 'shared-$userId-$storeName-$sentence',
    userId: userId,
    nickname: nickname,
    storeName: storeName,
    sentence: sentence,
    meaning: meaning,
    body: '내 지도에서 공유한 문장이에요',
    lat: lat,
    lng: lng,
    createdAt: DateTime.now(),
    mine: mine,
    following: following,
  );
}

/// 공유된 지도 가게. 서버에 못 붙으면 빈 목록.
Future<List<SharedPlace>> loadSharedPlaces({bool following = false}) async {
  try {
    final json = await AuthApi.sharedPlaces(following: following);
    return [
      for (final p in json['places'] as List)
        SharedPlace.fromJson(p as Map<String, dynamic>),
    ];
  } on AuthException {
    return const [];
  }
}
