import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/colors.dart';
import '../../app/router.dart';
import '../../widgets/iju_button.dart';
import '../../widgets/iju_header.dart';

/// 아직 만들지 않은 화면의 자리. 시연 흐름을 끝까지 눌러볼 수 있게 다음 화면으로 넘어가는 버튼만 있습니다.
/// 담당자는 features/<기능>/ 에 화면을 만든 뒤 app/router.dart에서 이 화면을 교체하세요.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.owner,
    required this.nextLabel,
    required this.nextRoute,
  });

  final String title;
  final String owner;
  final String nextLabel;
  final String nextRoute;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IjuHeader(title: title),
            Expanded(
              child: Center(
                child: Text(
                  '$owner 담당 화면 (준비 중)',
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSub,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: IjuButton(
                label: nextLabel,
                onPressed: () => nextRoute == AppRoutes.home
                    ? context.go(nextRoute)
                    : context.push(nextRoute),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
