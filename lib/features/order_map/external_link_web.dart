import 'package:web/web.dart' as web;

/// 웹: 새 탭으로 엽니다.
void openExternalUrl(String url) => web.window.open(url, '_blank');
