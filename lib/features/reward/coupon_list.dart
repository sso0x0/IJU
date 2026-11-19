import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../api/api_client.dart';
import '../../app/colors.dart';
import '../../widgets/iju_tab_bar.dart';
import '../real_order/order_api.dart';

/// GET /coupons 한 건 (server/app/schemas.py CouponItem). 담당: 개발자3
class CouponInfo {
  const CouponInfo({
    required this.id,
    required this.value,
    required this.status,
    required this.expiresAt,
    this.storeName,
  });

  factory CouponInfo.fromJson(Map<String, dynamic> json) => CouponInfo(
    id: json['id'] as String,
    value: json['value'] as int,
    status: json['status'] as String,
    expiresAt: json['expires_at'] as String? ?? '',
    storeName: json['store_name'] as String?,
  );

  final String id;
  final int value;

  /// active | used | expired
  final String status;
  final String expiresAt;
  final String? storeName;

  String get amount =>
      '${value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}원 할인';

  /// '12월 19일까지' (날짜를 못 읽으면 '30일 안에 사용')
  String get until {
    final t = DateTime.tryParse(expiresAt)?.toLocal();
    return t == null ? '30일 안에 사용' : '${t.month}월 ${t.day}일까지';
  }
}

abstract final class CouponApi {
  /// 서버가 꺼져 있으면 null.
  static Future<List<CouponInfo>?> list() async {
    try {
      final json = await ApiClient.getJson('/coupons', {
        'user_id': currentUserId,
      });
      return [
        for (final c in (json['coupons'] as List).cast<Map<String, dynamic>>())
          CouponInfo.fromJson(c),
      ];
    } on ApiException {
      return null;
    }
  }

  /// POST /coupons/{id}/use. 반환: (성공 여부, 안내 문구)
  static Future<(bool, String)> use(String couponId, String code) async {
    try {
      final json = await ApiClient.postJson('/coupons/$couponId/use', {
        'user_id': currentUserId,
        'code': code,
      });
      return (json['used'] as bool, json['message'] as String);
    } on ApiException {
      return (false, '서버에 연결하지 못했어요. 잠시 후 다시 시도해 주세요.');
    }
  }
}

/// 내 정보 탭의 '내 쿠폰' 목록. 쓸 수 있는 쿠폰을 누르면 사장님 확인 코드로 사용 처리합니다.
/// 서버가 꺼져 있으면 시연용 쿠폰 1장을 보여 줍니다.
class MyCoupons extends StatefulWidget {
  const MyCoupons({super.key});

  @override
  State<MyCoupons> createState() => _MyCouponsState();
}

class _MyCouponsState extends State<MyCoupons> {
  late Future<List<CouponInfo>?> _coupons = CouponApi.list();

  static const _demo = [
    CouponInfo(
      id: 'demo',
      value: 2000,
      status: 'active',
      expiresAt: '',
      storeName: '[가게 이름] 정육점',
    ),
  ];

  Future<void> _use(CouponInfo coupon) async {
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const _UseDialog(),
    );
    if (code == null || !mounted) return;
    final (ok, message) = await CouponApi.use(coupon.id, code);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    if (ok) setState(() => _coupons = CouponApi.list());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CouponInfo>?>(
      future: _coupons,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IjuListTitle('내 쿠폰'),
              Center(child: CircularProgressIndicator()),
            ],
          );
        }
        final server = snap.data;
        final coupons = server ?? _demo;
        final usable = coupons.where((c) => c.status == 'active').length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IjuListTitle('내 쿠폰', count: usable),
            if (coupons.isEmpty)
              const Text(
                '미션을 끝내고 영수증을 인증하면 쿠폰을 받아요.',
                style: TextStyle(fontSize: 14, color: AppColors.textBody),
              ),
            for (var i = 0; i < coupons.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _CouponTile(
                coupon: coupons[i],
                // 시연용 쿠폰(서버 없음)은 사용 처리하지 않음
                onTap: server != null && coupons[i].status == 'active'
                    ? () => _use(coupons[i])
                    : null,
              ),
            ],
          ],
        );
      },
    );
  }
}

/// 보상 화면 'Coupon'을 목록용으로 줄인 모양. 쓴 쿠폰·지난 쿠폰은 흐리게.
class _CouponTile extends StatelessWidget {
  const _CouponTile({required this.coupon, required this.onTap});

  final CouponInfo coupon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = coupon.status == 'active';
    final small = TextStyle(
      fontSize: 13,
      color: active ? AppColors.couponText : AppColors.textSub,
    );
    final note = switch (coupon.status) {
      'used' => '사용 완료',
      'expired' => '기간 만료',
      _ => '${coupon.until} · 누르면 사용',
    };

    return Material(
      color: active ? AppColors.accent : AppColors.divider,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                coupon.storeName ?? '이주 참여 가게',
                style: small.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                coupon.amount,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: active
                      ? AppColors.couponTextStrong
                      : AppColors.textSub,
                  decoration: active ? null : TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(height: 4),
              Text(note, style: small),
            ],
          ),
        ),
      ),
    );
  }
}

class _UseDialog extends StatefulWidget {
  const _UseDialog();

  @override
  State<_UseDialog> createState() => _UseDialogState();
}

class _UseDialogState extends State<_UseDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim();
    if (code.isNotEmpty) Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('쿠폰 사용'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '계산할 때 사장님께 이 화면을 보여 드리고\n사장님 확인 코드 4자리를 받아 입력해 주세요.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textBody,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 4,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 12,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(onPressed: _submit, child: const Text('사용하기')),
      ],
    );
  }
}
