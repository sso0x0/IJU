import 'native_strings.dart';
import 'session.dart';

/// 학습자가 고를 수 있는 모국어.
///
/// 아이디어 소개서 기준: 강원 계절근로자 출신국(베트남·필리핀·캄보디아·라오스·태국·몽골·
/// 우즈베키스탄·인도네시아·네팔)과 결혼이민자(중국·베트남), 종교·식단(할랄: 인도네시아·
/// 우즈베키스탄, 힌두: 네팔)에 맞췄어요. 서버 schemas.py의 Language와 같은 코드입니다.
class AppLanguage {
  const AppLanguage(this.code, this.name, this.korean, this.english);

  /// 서버로 보내는 코드 (users.language)
  final String code;

  /// 그 언어로 쓴 이름 (Tiếng Việt)
  final String name;

  /// 한국어 이름 (베트남어)
  final String korean;
  final String english;
}

const appLanguages = [
  AppLanguage('vi', 'Tiếng Việt', '베트남어', 'Vietnamese'),
  AppLanguage('fil', 'Filipino', '필리핀어', 'Filipino'),
  AppLanguage('km', 'ភាសាខ្មែរ', '크메르어', 'Khmer'),
  AppLanguage('lo', 'ພາສາລາວ', '라오어', 'Lao'),
  AppLanguage('th', 'ภาษาไทย', '태국어', 'Thai'),
  AppLanguage('id', 'Bahasa Indonesia', '인도네시아어', 'Indonesian'),
  AppLanguage('uz', 'Oʻzbekcha', '우즈베크어', 'Uzbek'),
  AppLanguage('mn', 'Монгол хэл', '몽골어', 'Mongolian'),
  AppLanguage('ne', 'नेपाली', '네팔어', 'Nepali'),
  AppLanguage('zh', '中文', '중국어', 'Chinese'),
  AppLanguage('en', 'English', '영어', 'English'),
];

AppLanguage languageOf(String code) => appLanguages.firstWhere(
  (l) => l.code == code,
  orElse: () => appLanguages.first,
);

/// 화면의 모국어 보조 문구를 사용자가 고른 언어로 바꿉니다.
///
/// 원문(베트남어)을 키로 [nativeStrings]에서 찾고, 그 언어가 없으면 영어, 영어도 없으면
/// 원문 그대로. [args]의 `{이름}` 자리를 채웁니다 (예: `nt('Đã chọn {n} món', {'n': 2})`).
String nt(String vi, [Map<String, Object?> args = const {}]) {
  final lang = AppSession.language;
  final row = nativeStrings[vi];
  var text = lang == 'vi' ? vi : (row?[lang] ?? row?['en'] ?? vi);
  for (final MapEntry(:key, :value) in args.entries) {
    text = text.replaceAll('{$key}', '$value');
  }
  return text;
}
