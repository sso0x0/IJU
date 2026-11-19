import 'package:flutter_test/flutter_test.dart';
import 'package:iju/app/diet.dart';
import 'package:iju/app/session.dart';
import 'package:iju/features/login/auth_session.dart';

void main() {
  tearDown(() {
    AppSession.diets.value = const {};
    AppSession.shareMap.value = false;
  });

  test('계정에 저장된 식단·종교와 지도 공유 설정을 불러와요', () async {
    await AuthSession.update({
      'id': 'u1',
      'diets': ['islam', 'vegan', '없는식단'],
      'share_map': true,
    });
    expect(AppSession.diets.value, {Diet.islam, Diet.vegan});
    expect(AppSession.shareMap.value, isTrue);
  });

  test('로그아웃하면 식단과 공유 설정을 지워요', () async {
    AppSession.diets.value = {Diet.islam};
    AppSession.shareMap.value = true;
    await AuthSession.clear();
    expect(AppSession.diets.value, isEmpty);
    expect(AppSession.shareMap.value, isFalse);
  });
}
