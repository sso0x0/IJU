/// 구글 로그인 버튼. 웹은 google_button_web.dart(구글 공식 버튼), 그 밖은 안내만 하는 stub.
library;

export 'google_button_stub.dart'
    if (dart.library.js_interop) 'google_button_web.dart';
