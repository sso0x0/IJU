import 'package:material_ui/material_ui.dart';

import '../../app/languages.dart';

import '../../app/colors.dart';
import '../../app/theme.dart';
import '../../widgets/iju_button.dart';
import 'chalkboard.dart';
import 'example_menus.dart';

/// C6 이름 고치기 시트. 고친 이름을 돌려주면 그 이름으로 판정을 다시 합니다.
///
/// [original]은 메뉴판에서 읽은 글씨, [current]는 지금 이름(이미 고쳤으면 고친 이름)입니다.
Future<String?> showRenameSheet(
  BuildContext context, {
  required String original,
  required String current,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _RenameSheet(original: original, current: current),
  );
}

/// 메뉴판 글씨를 잘못 읽었을 때 고를 수 있는 흔한 메뉴 이름.
const _commonMenus = [
  '김치찌개',
  '된장찌개',
  '순두부찌개',
  '부대찌개',
  '청국장',
  '제육볶음',
  '오징어볶음',
  '낙지볶음',
  '두부부침',
  '계란말이',
  '계란찜',
  '비빔밥',
  '돌솥비빔밥',
  '김치볶음밥',
  '볶음밥',
  '공기밥',
  '공깃밥',
  '곱빼기',
  '순대국',
  '순댓국',
  '돼지국밥',
  '뼈해장국',
  '해장국',
  '갈비탕',
  '설렁탕',
  '곰탕',
  '삼계탕',
  '육개장',
  '김치전',
  '해물파전',
  '파전',
  '감자전',
  '떡볶이',
  '라볶이',
  '순대',
  '튀김',
  '김밥',
  '참치김밥',
  '라면',
  '칼국수',
  '수제비',
  '잔치국수',
  '비빔국수',
  '냉면',
  '물냉면',
  '비빔냉면',
  '쫄면',
  '우동',
  '만두',
  '군만두',
  '물만두',
  '돈가스',
  '불고기',
  '닭갈비',
  '찜닭',
  '삼겹살',
  '목살',
  '항정살',
  '갈비',
  '소갈비',
  '돼지갈비',
  '보쌈',
  '족발',
  '닭볶음탕',
  '고등어구이',
  '생선구이',
  '갈치조림',
  '두부조림',
  '잡채',
  '나물',
  '콩나물국밥',
  '미역국',
  '떡국',
  '만둣국',
  '오므라이스',
  '카레라이스',
  '김치',
  '깍두기',
];

/// 글자 단위 편집 거리.
int _distance(String a, String b) {
  final prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    var diag = prev[0];
    prev[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final up = prev[j];
      prev[j] = [
        prev[j] + 1,
        prev[j - 1] + 1,
        diag + (a[i - 1] == b[j - 1] ? 0 : 1),
      ].reduce((x, y) => x < y ? x : y);
      diag = up;
    }
  }
  return prev[b.length];
}

/// 읽은 글씨와 비슷한 메뉴 이름 (가까운 순, 최대 3개).
List<String> similarMenus(String text) {
  final s = text.replaceAll(RegExp(r'\s'), '');
  if (s.isEmpty) return const [];
  final names = <String>{
    ..._commonMenus,
    for (final id in const ['restaurant', 'side_dish'])
      for (final m in exampleMenusFor(id)) m.name,
  };
  final limit = s.length <= 3 ? 1 : 2;
  final scored = [
    for (final n in names)
      if (_distance(s, n) <= limit) (n, _distance(s, n)),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  return [for (final e in scored.take(3)) e.$1];
}

class _RenameSheet extends StatefulWidget {
  const _RenameSheet({required this.original, required this.current});

  final String original;
  final String current;

  @override
  State<_RenameSheet> createState() => _RenameSheetState();
}

class _RenameSheetState extends State<_RenameSheet> {
  late final _controller = TextEditingController(text: widget.current);
  late final List<String> _suggestions = similarMenus(widget.original);

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text.trim();
    return Padding(
      // 키보드가 올라오면 시트도 같이 올라가요.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('메뉴 이름 고치기', style: AppText.subtitle),
                      Text(
                        nt('Sửa tên món'),
                        style: AppText.native.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSub,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.background,
                    fixedSize: const Size.square(48),
                  ),
                  icon: const Icon(Icons.close, color: AppColors.text),
                  tooltip: '닫기 · ${nt('Đóng')}',
                ),
              ],
            ),
            const SizedBox(height: 14),
            _FieldLabel('찍은 글씨', nt('Chữ đã chụp')),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
              decoration: BoxDecoration(
                color: AppColors.board,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.boardFrame, width: 5),
              ),
              child: ChalkRow(name: widget.original, faded: true),
            ),
            const SizedBox(height: 16),
            _FieldLabel('메뉴 이름', nt('Tên món')),
            const SizedBox(height: 8),
            SizedBox(
              height: 56,
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
                decoration: const InputDecoration(
                  hintText: '메뉴판에 적힌 이름',
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(AppRadius.input),
                    ),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
            ),
            if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 14),
              _FieldLabel('이 메뉴인가요?', nt('Có phải món này?'), small: true),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in _suggestions)
                    _SuggestionChip(
                      label: s,
                      selected: s == text,
                      onTap: () => _controller.value = TextEditingValue(
                        text: s,
                        selection: TextSelection.collapsed(offset: s.length),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 18,
                    color: AppColors.textBody,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '고친 이름으로 판정을 다시 해요.',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textBody,
                          ),
                        ),
                        Text(
                          nt('Sẽ kiểm tra lại theo tên đã sửa.'),
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
            ),
            const SizedBox(height: 16),
            IjuButton(
              label: '고쳐서 다시 판정',
              sub: nt('Sửa và kiểm tra lại'),
              onPressed: text.isEmpty ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.ko, this.native, {this.small = false});

  final String ko;
  final String native;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: ko,
        style: TextStyle(
          fontSize: small ? 14 : 15,
          fontWeight: FontWeight.w800,
          color: small ? AppColors.textBody : AppColors.text,
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

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  const Icon(Icons.check, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.text,
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
