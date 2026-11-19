/// 카카오맵 위젯. 웹은 kakao_map_web.dart(카카오 JS SDK), 그 밖은 자리만 보여 주는 stub.
library;

export 'kakao_map_stub.dart'
    if (dart.library.js_interop) 'kakao_map_web.dart';
