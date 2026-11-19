/// 바깥 링크 열기 (카카오맵 길찾기). 웹은 새 탭, 앱은 카카오맵 앱·브라우저.
library;

export 'external_link_app.dart'
    if (dart.library.js_interop) 'external_link_web.dart';
