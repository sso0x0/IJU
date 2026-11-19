import 'package:material_ui/material_ui.dart';

import '../app/colors.dart';
import '../app/diet.dart';
import '../app/session.dart';
import 'iju_button.dart';
import 'iju_chip.dart';
import 'section_label.dart';

/// 식단(채식 7단계)과 종교를 여러 개 고르는 칩 묶음. 온보딩과 내 정보에서 함께 씁니다.
/// 칩의 ⓘ를 누르면 무엇을 피하는지 학습자 언어로 보여 줍니다.
class DietPicker extends StatelessWidget {
  const DietPicker({super.key, required this.value, required this.onChanged});

  final Set<Diet> value;
  final ValueChanged<Set<Diet>> onChanged;

  void _toggle(Diet d) {
    final next = {...value};
    if (!next.remove(d)) next.add(d);
    onChanged(next);
  }

  void _about(BuildContext context, Diet d) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('${d.label} · ${dietAbout(d)}')));
  }

  Widget _chips(BuildContext context, List<Diet> diets) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final d in diets)
        IjuChip(
          label: d.label,
          selected: value.contains(d),
          onTap: () => _toggle(d),
          onInfo: () => _about(context, d),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('채식', sub: 'Vegetarian'),
        const SizedBox(height: 10),
        _chips(context, Diet.vegetarian),
        const SizedBox(height: 18),
        const SectionLabel('종교', sub: 'Religion'),
        const SizedBox(height: 10),
        _chips(context, Diet.religions),
        const SizedBox(height: 8),
        const Text(
          '여러 개 고를 수 있어요. 문장 만들기에서 빼 달라는 말과 물어볼 말을 미리 골라 둘게요.',
          style: TextStyle(fontSize: 13, color: AppColors.textSub),
        ),
      ],
    );
  }
}

/// 내 정보에서 식단·종교를 바꾸는 바텀시트. 저장하면 [AppSession.diets]를 바꿉니다.
Future<void> showDietSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (_) => const _DietSheet(),
  );
}

class _DietSheet extends StatefulWidget {
  const _DietSheet();

  @override
  State<_DietSheet> createState() => _DietSheetState();
}

class _DietSheetState extends State<_DietSheet> {
  late Set<Diet> _value = AppSession.diets.value;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '식단 · 종교',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 16),
            DietPicker(
              value: _value,
              onChanged: (v) => setState(() => _value = v),
            ),
            const SizedBox(height: 24),
            IjuButton(
              label: '저장하기',
              onPressed: () {
                AppSession.diets.value = _value;
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
