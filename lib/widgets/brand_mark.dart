import 'package:material_ui/material_ui.dart';

import '../app/colors.dart';
import '../l10n/generated/app_localizations.dart';

/// 로고(손그림 이중 테두리의 손가락) + 앱 이름 + 한 줄 소개.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.showTagline = true, this.size = 52});

  final bool showTagline;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Image.asset(
          'assets/brand/logo.png',
          width: size,
          excludeFromSemantics: true,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.appName,
                style: TextStyle(
                  fontSize: size * 0.6,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              if (showTagline) ...[
                const SizedBox(height: 4),
                Text(
                  l10n.appTagline,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textBody,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
