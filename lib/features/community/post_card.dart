import 'package:material_ui/material_ui.dart';

import '../../app/languages.dart';

import '../../app/colors.dart';
import '../../app/theme.dart';
import '../review/practice_link.dart';
import 'community_api.dart';

/// 커뮤니티 글 카드 (G6 아래 목록).
///
/// 글쓴이 · 가게 · 시간 → 말한 문장(크게) → 모국어 뜻 → 자유롭게 쓴 말 →
/// 듣기 · 이 문장 연습하기. 다른 사람 글이면 오른쪽 위에 팔로우 버튼, 내 글이면 지우기.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    this.onFollow,
    this.onDelete,
    this.onListen,
  });

  final CommunityPost post;

  /// 팔로우 켜기/끄기 (없으면 버튼을 숨겨요)
  final VoidCallback? onFollow;
  final VoidCallback? onDelete;
  final VoidCallback? onListen;

  @override
  Widget build(BuildContext context) {
    final initial = post.nickname.isEmpty
        ? '?'
        : post.nickname.characters.first;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.pointBg,
                child: Text(
                  initial.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.pointText,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.mine ? '${post.nickname} · 나' : post.nickname,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 14,
                          color: AppColors.textSub,
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            '${post.storeName} · '
                            '${post.agoLabel(DateTime.now())}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.caption.copyWith(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (post.mine && onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  tooltip: '글 지우기',
                  icon: const Icon(Icons.delete_outline, size: 22),
                  color: AppColors.textSub,
                )
              else if (!post.mine && onFollow != null)
                FollowButton(following: post.following, onTap: onFollow!),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '“${post.sentence}”',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.35,
              letterSpacing: -0.3,
              color: AppColors.text,
            ),
          ),
          if (post.meaning != null && post.meaning!.isNotEmpty)
            Text(
              post.meaning!,
              style: AppText.native.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.textSub,
              ),
            ),
          if (post.body.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              post.body,
              style: const TextStyle(
                fontSize: 15,
                height: 1.45,
                color: AppColors.textBody,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (onListen != null) ...[
                _PillButton(
                  icon: Icons.volume_up_outlined,
                  label: '듣기',
                  native: nt('Nghe'),
                  onTap: onListen!,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: _PillButton(
                  icon: Icons.mic_none,
                  label: '이 문장 연습하기',
                  native: nt('Luyện'),
                  filled: true,
                  onTap: () => practiceSentence(
                    context,
                    sentence: post.sentence,
                    meaning: post.meaning,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// '팔로우' / '팔로잉' 버튼.
class FollowButton extends StatelessWidget {
  const FollowButton({super.key, required this.following, required this.onTap});

  final bool following;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: following ? AppColors.primarySoft : AppColors.primary,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 36,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  following ? Icons.check : Icons.person_add_alt_1_outlined,
                  size: 16,
                  color: following ? AppColors.primaryDark : Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  following ? '팔로잉' : '팔로우',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: following ? AppColors.primaryDark : Colors.white,
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

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.native,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final String native;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final fg = AppColors.primaryDark;
    return Material(
      color: filled ? AppColors.surface : AppColors.primary50,
      shape: StadiumBorder(
        side: BorderSide(
          color: filled ? AppColors.primary : AppColors.primarySoft,
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: fg,
                    ),
                  ),
                ),
                Text(
                  ' · $native',
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
