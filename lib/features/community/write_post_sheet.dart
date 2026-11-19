import 'package:material_ui/material_ui.dart';

import '../../app/languages.dart';

import '../../app/colors.dart';
import '../../app/theme.dart';
import '../../widgets/iju_button.dart';
import '../login/auth_api.dart';
import '../order_map/order_place_store.dart';
import '../review/review_store.dart';
import 'community_api.dart';

/// 커뮤니티 글쓰기 시트. 올리면 새 글을 돌려줍니다.
///
/// 내 지도의 가게를 누르면 가게 · 문장 · 위치가 한 번에 채워지고,
/// 복습 목록의 문장을 눌러 문장만 고를 수도 있어요. 직접 써도 됩니다.
Future<CommunityPost?> showWritePostSheet(BuildContext context) {
  return showModalBottomSheet<CommunityPost>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _WritePostSheet(),
  );
}

class _WritePostSheet extends StatefulWidget {
  const _WritePostSheet();

  @override
  State<_WritePostSheet> createState() => _WritePostSheetState();
}

class _WritePostSheetState extends State<_WritePostSheet> {
  final _store = TextEditingController();
  final _sentence = TextEditingController();
  final _body = TextEditingController();
  String? _meaning;
  double? _lat;
  double? _lng;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _store.addListener(_changed);
    _sentence.addListener(_changed);
  }

  void _changed() => setState(() => _error = null);

  @override
  void dispose() {
    _store.dispose();
    _sentence.dispose();
    _body.dispose();
    super.dispose();
  }

  void _pickPlace(OrderPlace p) => setState(() {
    _store.text = p.storeName;
    _sentence.text = p.sentence;
    _meaning = p.meaning;
    _lat = p.lat;
    _lng = p.lng;
  });

  void _pickSentence(ReviewItem r) => setState(() {
    _sentence.text = r.sentence;
    _meaning = r.meaning;
  });

  Future<void> _submit() async {
    final store = _store.text.trim();
    final sentence = _sentence.text.trim();
    if (store.isEmpty || sentence.isEmpty) {
      setState(() => _error = '가게와 문장을 채워 주세요');
      return;
    }
    // 고른 가게와 다른 가게를 직접 쓰면 위치는 빼요.
    final fromPlace = OrderPlaceStore.items.value.any(
      (p) => p.storeName == store && p.lat == _lat,
    );
    setState(() => _sending = true);
    try {
      final post = await CommunityApi.write(
        storeName: store,
        sentence: sentence,
        meaning: _meaning,
        body: _body.text.trim(),
        lat: fromPlace ? _lat : null,
        lng: fromPlace ? _lng : null,
      );
      if (mounted) Navigator.pop(context, post);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final places = OrderPlaceStore.items.value.take(6).toList();
    final placed = {for (final p in places) p.sentence};
    final sentences = [
      for (final r in ReviewStore.items.value)
        if (!placed.contains(r.sentence)) r,
    ].take(6).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('어디서 무슨 말을 했나요?', style: AppText.subtitle),
            Text(
              nt('Bạn đã nói gì, ở đâu?'),
              style: AppText.native.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.textSub,
              ),
            ),
            if (places.isNotEmpty) ...[
              const SizedBox(height: 16),
              _Label('내 지도에서 고르기', nt('Chọn từ bản đồ của tôi')),
              const SizedBox(height: 8),
              for (final p in places)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _PickTile(
                    title: p.storeName,
                    sub: '“${p.sentence}”',
                    selected:
                        _store.text == p.storeName &&
                        _sentence.text == p.sentence,
                    onTap: () => _pickPlace(p),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            _Label('가게 이름', nt('Tên quán')),
            const SizedBox(height: 8),
            TextField(
              controller: _store,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: '예) 골목식당',
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: 14),
            _Label('내가 말한 문장', nt('Câu tôi đã nói')),
            const SizedBox(height: 8),
            TextField(
              controller: _sentence,
              textInputAction: TextInputAction.next,
              onChanged: (_) => _meaning = null,
              decoration: const InputDecoration(hintText: '예) 김치찌개 하나 주세요.'),
            ),
            if (sentences.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final r in sentences)
                    ActionChip(
                      label: Text(r.sentence),
                      onPressed: () => _pickSentence(r),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            _Label('하고 싶은 말', nt('Viết gì đó')),
            const SizedBox(height: 8),
            TextField(
              controller: _body,
              minLines: 3,
              maxLines: 6,
              maxLength: 1000,
              decoration: const InputDecoration(
                hintText: '사장님 반응, 팁, 느낀 점을 자유롭게 써 주세요',
                contentPadding: EdgeInsets.all(14),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.dangerText,
                  ),
                ),
              ),
            IjuButton(
              label: _sending ? '올리는 중…' : '올리기',
              sub: nt('Đăng'),
              icon: Icons.send_outlined,
              onPressed: _sending ? null : _submit,
            ),
          ],
        ),
      ),
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

class _PickTile extends StatelessWidget {
  const _PickTile({
    required this.title,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary50 : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.place_outlined,
                size: 20,
                color: selected ? AppColors.primary : AppColors.textSub,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
        ),
      ),
    );
  }
}
