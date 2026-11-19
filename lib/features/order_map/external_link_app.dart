import 'package:url_launcher/url_launcher.dart';

/// 앱(Android·iOS): 카카오맵 앱이나 브라우저로 엽니다.
void openExternalUrl(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
