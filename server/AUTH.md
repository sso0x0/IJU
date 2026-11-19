# 로그인 (개발자1)

아이디·이메일·비밀번호 가입과 구글 로그인입니다. 청온 앱의 로그인 구조(중복 자동 확인, 약관 동의 버전, 소셜 가입 2단계)를 그대로 따릅니다.

- 서버 코드: `app/routers/auth.py`, `app/auth.py`(비밀번호 해시·토큰), `app/terms.py`(약관 문구)
- Supabase를 쓰면 `auth_schema.sql`을 SQL Editor에서 한 번 실행하세요. 메모리 DB는 그대로 동작합니다.
- `.env`: `AUTH_SECRET`(토큰 서명용 랜덤 문자열), `GOOGLE_CLIENT_IDS`(구글 로그인 쓸 때)

## 이름 주의: `login_id`와 `user.id`

청온은 로그인 아이디를 `user_id`라고 불렀지만, 이주 서버의 다른 API(`/receipts`, `/attempts`, `/missions`)는 이미 `user_id`를 **users.id(UUID)** 라는 뜻으로 씁니다. 그래서

- 로그인 아이디는 **`login_id`**
- 로그인 응답의 **`user.id`** 를 `AppSession.userId`에 넣고, 다른 API의 `user_id`로 그대로 보냅니다.

## API

오류는 모두 `{"code": "...", "message": "..."}` 형식입니다. 앱은 `message`를 그대로 띄우고, 필요한 경우만 `code`로 분기합니다.

| 메서드 | 경로 | 보내는 값 | 성공 | 주요 오류 code |
| --- | --- | --- | --- | --- |
| GET | /auth/terms | | `terms_version`, `terms_text`, `privacy_text` | |
| POST | /auth/check-id | `login_id` | 200 `message` | `INVALID_ID`(422), `ID_TAKEN`(409) |
| POST | /auth/check-email | `email` | 200 `message` | `INVALID_EMAIL`(422), `EMAIL_TAKEN`(409) |
| POST | /auth/signup | `login_id`, `email`, `password`, `terms_agreed`, `privacy_agreed`, `terms_version` (+ 선택 `nickname`, `language`, `residence_type`) | 세션 | `TERMS_REQUIRED`(400), `TERMS_CHANGED`(409), `ID_TAKEN`, `EMAIL_TAKEN`, `WEAK_PASSWORD`(422) |
| POST | /auth/login | `login_id`, `password` | 세션 | `WRONG_CREDENTIALS`(401) |
| POST | /auth/social | `provider: "google"`, `id_token` | 가입함 → 세션 / 처음 → `signup_required: true`, `email` | `INVALID_GOOGLE_TOKEN`(401) |
| POST | /auth/social/signup | `id_token`, `name`(닉네임), 약관 3개 | 세션 | `NICKNAME_TAKEN`(409), `TERMS_CHANGED`(409), `ALREADY_SIGNED_UP`(409) |
| GET | /auth/me | 헤더 `Authorization: Bearer <access_token>` | `user` | `LOGIN_REQUIRED`, `INVALID_TOKEN`(401) |
| PATCH | /auth/me | 헤더 + `nickname`/`language`/`residence_type` 중 바꿀 것 | `user` | `NICKNAME_TAKEN` |

세션 응답:

```json
{
  "access_token": "eyJ...",
  "token_type": "bearer",
  "user": {
    "id": "UUID — 다른 API의 user_id",
    "login_id": "nguyen01",
    "email": "nguyen@example.com",
    "nickname": "nguyen01",
    "language": null,
    "residence_type": null,
    "level": 1,
    "points": 0,
    "auth_provider": "local"
  }
}
```

규칙: 아이디 영문·숫자·밑줄 4~20자(대소문자 구분 없음), 비밀번호 8자 이상, 닉네임 한글·영문·숫자·밑줄 2~20자. 가입하면 바로 세션을 돌려주므로 따로 로그인할 필요가 없습니다.

## 화면 구성 (Flutter)

청온 Activity를 이주 화면으로 옮기면 이렇게 됩니다. 색·버튼은 기존 `IjuButton`, `IjuTextField`, `SectionLabel`(한국어 + 모국어 보조)을 씁니다.

| 화면 (route) | 청온 | 들어갈 것 |
| --- | --- | --- |
| 로그인 `/` | LoginActivity | 아이디, 비밀번호, [로그인], [Google로 계속하기], 회원가입 · 비밀번호 찾기 링크 |
| 회원가입 `/signup` | SignupActivity | 아이디(칸을 벗어나면 `/auth/check-id`), 이메일(벗어나면 `/auth/check-email`), 비밀번호, 비밀번호 확인, 약관 체크 2개 + [보기], [가입하기], [Google로 가입] |
| 구글 가입 `/signup/google` | GoogleSignupActivity | 구글 이메일(읽기 전용), 닉네임, 약관 체크 2개, [가입 완료] |
| 비밀번호 찾기 `/find-password` | FindPasswordActivity | 아이디 입력 + "준비 중" 안내 (청온과 같음. 메일 발송 서버가 없어서 아직 API 없음) |
| 온보딩 `/onboarding` (기존) | — | 가입 직후 모국어·체류 유형 → `PATCH /auth/me` |

약관 동의 위젯은 청온 `SignupConsent`처럼 **회원가입·구글 가입이 같이 쓰는 위젯 하나**로 만듭니다.

1. 화면이 열리면 `GET /auth/terms` → `terms_version`을 기억. 불러오기 전에는 체크박스와 [보기]를 막아 둠
2. 두 체크박스는 처음에 꺼져 있고, 둘 다 켜져야 가입 버튼이 활성화 (흐리게 0.45 → 1)
3. [보기]는 다이얼로그에 `terms_text` / `privacy_text`
4. 가입 요청 body에 `terms_agreed`, `privacy_agreed`, `terms_version`을 붙임
5. 응답이 `409 TERMS_CHANGED`면 체크를 풀고 약관을 다시 불러옴

## 연동 방법

### 1. 패키지

```yaml
dependencies:
  shared_preferences: ^2.3.0   # 토큰 저장 (청온의 SharedPreferences "loginInfo")
  google_sign_in: ^7.1.0       # 구글 로그인
```

### 2. AuthApi (`lib/features/login/auth_api.dart`)

지금 `ApiClient.postJson`은 200이 아니면 응답 본문을 버리고 `ApiException`만 던집니다. 로그인은 `code`·`message`가 필요하므로 `http`로 직접 부르고 오류 본문을 읽는 작은 클래스를 둡니다.

```dart
class AuthException implements Exception {
  AuthException(this.status, this.code, this.message);
  final int status;
  final String code;
  final String message;
}

abstract final class AuthApi {
  static Future<Map<String, dynamic>> _send(String method, String path, [Map<String, Object?>? body]) async {
    final token = AppSession.accessToken;
    final req = http.Request(method, Uri.parse('${ApiClient.baseUrl}$path'))
      ..headers['Content-Type'] = 'application/json; charset=utf-8'
      ..headers.addAll({if (token != null) 'Authorization': 'Bearer $token'})
      ..body = body == null ? '' : jsonEncode(body);
    final streamed = await req.send().timeout(const Duration(seconds: 12));
    final out = await http.Response.fromStream(streamed);
    final json = out.body.isEmpty ? <String, dynamic>{} : jsonDecode(utf8.decode(out.bodyBytes)) as Map<String, dynamic>;
    if (out.statusCode != 200) {
      throw AuthException(out.statusCode, json['code'] as String? ?? '', json['message'] as String? ?? '다시 시도해 주세요.');
    }
    return json;
  }

  static Future<Map<String, dynamic>> terms() => _send('GET', '/auth/terms');
  static Future<void> checkId(String id) => _send('POST', '/auth/check-id', {'login_id': id});
  static Future<void> checkEmail(String email) => _send('POST', '/auth/check-email', {'email': email});
  static Future<Map<String, dynamic>> signup(Map<String, Object?> body) => _send('POST', '/auth/signup', body);
  static Future<Map<String, dynamic>> login(String id, String pw) => _send('POST', '/auth/login', {'login_id': id, 'password': pw});
  static Future<Map<String, dynamic>> google(String idToken) => _send('POST', '/auth/social', {'provider': 'google', 'id_token': idToken});
  static Future<Map<String, dynamic>> googleSignup(Map<String, Object?> body) => _send('POST', '/auth/social/signup', body);
  static Future<Map<String, dynamic>> me() => _send('GET', '/auth/me');
  static Future<Map<String, dynamic>> updateMe(Map<String, Object?> body) => _send('PATCH', '/auth/me', body);
}
```

### 3. 세션 저장 (청온 `saveSession`)

`AppSession`에 `accessToken`을 추가하고, 로그인·가입 성공 응답을 받으면

1. `AppSession.accessToken = body['access_token']`, `AppSession.userId = body['user']['id']`
2. `user['language']`가 있으면 `AppSession.language`에도 넣기
3. `SharedPreferences`에 `accessToken`, `userId`, `authProvider` 저장
4. `language`가 비어 있으면 `/onboarding`, 있으면 `/home`으로 `context.go`

### 4. 자동 로그인 (청온 `isLoggedIn` 확인)

앱 시작(`main.dart` 또는 로그인 화면 `initState`)에서 저장된 토큰이 있으면 `GET /auth/me`

- 200 → 세션 복원 후 `/home`
- 401 → 저장값 지우고 로그인 화면 그대로

### 5. 회원가입 화면의 중복 확인 (청온과 같은 방식)

- 아이디 칸 `Focus(onFocusChange: (has) { if (!has) _checkId(); })`
- 글자가 바뀌면 `_idChecked = false` (청온 `TextWatcher`)
- `checkId` 성공 → `_idChecked = true`, 실패 → `AuthException.message`를 칸 아래 `errorText`로
- [가입하기]를 눌렀을 때 `_idChecked`, `_emailChecked`, 비밀번호 일치, 약관 동의를 순서대로 확인한 뒤 `AuthApi.signup`
- 서버도 같은 검사를 다시 하므로 앱 검사를 건너뛰어도 잘못 가입되지는 않습니다

### 6. 구글 로그인 (청온 `SocialLoginManager` 흐름)

```
[Google로 계속하기] → 구글에서 id_token 받기 → POST /auth/social
    ├ user 있음 → 세션 저장 → 홈
    └ signup_required → /signup/google (extra: id_token, email)
           → 닉네임 + 약관 → POST /auth/social/signup
               ├ 성공 → 세션 저장 → 온보딩
               ├ 409 NICKNAME_TAKEN → 닉네임 칸에 message
               ├ 409 TERMS_CHANGED → 약관 다시 불러오기
               └ 401 → 구글 토큰 만료, 로그인 화면으로
```

준비할 것:

1. [Google Cloud Console](https://console.cloud.google.com/apis/credentials) › OAuth 클라이언트 ID › **웹 애플리케이션** 생성, 승인된 JavaScript 원본에 `http://localhost:5000` 추가
2. 그 클라이언트 ID를 서버 `.env`의 `GOOGLE_CLIENT_IDS`에 넣고 서버 재시작
3. 앱은 `google_sign_in` 7.x 기준으로 `GoogleSignIn.instance.initialize(clientId: <웹 클라이언트 ID>)`
   - 웹에서는 구글 정책상 직접 만든 버튼으로 id_token을 받을 수 없어서, `google_sign_in_web`의 `renderButton()`이 그리는 구글 버튼을 화면에 두고
   - `GoogleSignIn.instance.authenticationEvents`에서 로그인 이벤트가 오면 `event.user.authentication.idToken`을 `AuthApi.google`로 보냅니다
   - 패키지 API가 버전마다 달라서, 설치한 버전의 README 예제를 같이 확인하세요

### 7. 기존 화면 정리

- `login_screen.dart`: 지금은 닉네임 + PIN이고 `_login()`이 바로 홈으로 갑니다. 아이디·비밀번호 칸으로 바꾸고 `AuthApi.login` 연결
- `onboarding_screen.dart`: 맨 앞에 회원가입 화면을 두거나, 가입 후 모국어·체류 유형만 받고 `PATCH /auth/me`
- `order_api.dart`의 `currentUserId`는 `AppSession.userId ?? demoUserId`라서, 로그인 후 `AppSession.userId`만 채우면 영수증·미션 API가 자동으로 그 사용자로 기록됩니다
- 기존 `POST /users`(닉네임만 가입)는 시연 호환용으로 남겨 두었습니다
