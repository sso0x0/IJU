import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:material_ui/material_ui.dart';
import 'package:web/web.dart' as web;

import 'order_place_store.dart';

/// 카카오맵 JavaScript 키. `--dart-define=KAKAO_JS_KEY=...`로 바꿀 수 있습니다.
/// JavaScript 키는 브라우저에 그대로 내려가는 공개 키라 콘솔의 Web 도메인 등록으로 막습니다.
const _kakaoJsKey = String.fromEnvironment(
  'KAKAO_JS_KEY',
  defaultValue: '4ea1e48d942f0ffb3609f785edf86b42',
);

@JS('ijuKakaoMap.render')
external void _render(
  web.HTMLElement element,
  String key,
  String placesJson,
  String? focusId,
  JSFunction onSelect,
);

/// 웹: web/kakao_map.js로 카카오맵을 그립니다.
class KakaoMapView extends StatefulWidget {
  const KakaoMapView({
    super.key,
    required this.places,
    this.focusId,
    this.onSelect,
  });

  final List<OrderPlace> places;

  /// 이 가게를 가운데에 크게 보여 줍니다.
  final String? focusId;

  /// 핀을 눌렀을 때 가게 id
  final void Function(String id)? onSelect;

  @override
  State<KakaoMapView> createState() => _KakaoMapViewState();
}

class _KakaoMapViewState extends State<KakaoMapView> {
  static int _seq = 0;

  late final String _viewType = 'iju-kakao-map-${_seq++}';
  web.HTMLDivElement? _element;

  @override
  void initState() {
    super.initState();
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final div = web.HTMLDivElement()
        ..style.width = '100%'
        ..style.height = '100%';
      _element = div;
      _draw();
      return div;
    });
  }

  @override
  void didUpdateWidget(KakaoMapView old) {
    super.didUpdateWidget(old);
    if (old.places != widget.places || old.focusId != widget.focusId) _draw();
  }

  void _draw() {
    final el = _element;
    if (el == null) return;
    _render(
      el,
      _kakaoJsKey,
      jsonEncode([for (final p in widget.places) p.toMapJson()]),
      widget.focusId,
      ((JSString id) => widget.onSelect?.call(id.toDart)).toJS,
    );
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}

/// 새 탭으로 엽니다 (카카오맵 길찾기).
void openExternalUrl(String url) => web.window.open(url, '_blank');
