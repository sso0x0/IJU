import '../../api/api_client.dart';
import '../scenario/scenarios.dart';

/// GET /recipes/match — 메뉴 이름으로 Supabase recipes 표에서 레시피 재료를 찾습니다.
abstract final class RecipeApi {
  /// 같은 메뉴는 한 번만 묻습니다 (메뉴 칩을 오가도 다시 부르지 않음).
  static final _cache = <String, RecipeMatch>{};

  /// 서버가 꺼져 있거나 실패하면 null. 화면은 메뉴 이름으로 짐작한 재료를 그대로 씁니다.
  static Future<RecipeMatch?> match(String menu) async {
    if (_cache[menu] case final hit?) return hit;
    try {
      final json = await ApiClient.getJson('/recipes/match', {
        'menu': menu,
      }, const Duration(seconds: 8));
      return _cache[menu] = RecipeMatch.fromJson(json);
    } on Exception {
      return null;
    }
  }
}
