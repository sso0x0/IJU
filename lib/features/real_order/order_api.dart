import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../api/api_client.dart';
import '../../app/session.dart';

/// 시나리오 id → 서버 미션 id (server/app/seed_data.py와 같은 값).
/// TODO(개발자3): 홈에서 GET /missions로 고른 미션 id를 넘기게 되면 이 표는 지워도 됩니다.
const missionIdByScenario = {
  'restaurant': '00000000-0000-0000-0000-000000000202',
  'side_dish': '00000000-0000-0000-0000-000000000203',
};

/// 로그인(온보딩 POST /users) 연결 전에 쓰는 시연용 사용자 id.
const demoUserId = '00000000-0000-0000-0000-000000000999';

/// 서버에 보낼 사용자 id. 로그인 전이면 [demoUserId].
/// TODO(개발자1): 온보딩에서 AppSession.userId를 채우면 Supabase에도 기록됩니다.
String get currentUserId => AppSession.userId ?? demoUserId;

/// 실전 주문 화면으로 넘기는 값. 음성 연습 화면에서 만든 문장을 받습니다.
class RealOrderArgs {
  const RealOrderArgs({required this.sentence, required this.missionId});

  final String sentence;
  final String missionId;

  /// 주소로 바로 들어왔을 때 쓰는 시연 문장 (Figma와 같은 화면).
  static const demo = RealOrderArgs(
    sentence: '김치찌개 2인분 덜 맵게 해 주세요.',
    missionId: '00000000-0000-0000-0000-000000000202',
  );
}

/// server/app/schemas.py Coupon
class Coupon {
  const Coupon({
    required this.id,
    required this.value,
    required this.expiresAt,
  });

  final String id;
  final int value;
  final String expiresAt;
}

/// POST /receipts, POST /receipts/merchant-confirm 응답 (schemas.py ReceiptOut).
class ReceiptResult {
  const ReceiptResult({
    required this.verified,
    required this.reason,
    this.message,
    this.storeName,
    this.amount,
    this.coupon,
    this.fallback = false,
  });

  factory ReceiptResult.fromJson(Map<String, dynamic> json) {
    final c = json['coupon'] as Map<String, dynamic>?;
    return ReceiptResult(
      verified: json['verified'] as bool,
      reason: json['reason'] as String,
      message: json['message'] as String?,
      storeName: json['store_name'] as String?,
      amount: json['amount'] as int?,
      coupon: c == null
          ? null
          : Coupon(
              id: c['id'] as String,
              value: c['value'] as int,
              expiresAt: c['expires_at'] as String,
            ),
    );
  }

  /// 서버에 연결하지 못했을 때 시연이 끊기지 않게 쓰는 대체 결과 (PRD 3.5 안정성).
  static const offline = ReceiptResult(
    verified: true,
    reason: 'ok',
    message: '인증 완료! 쿠폰이 발급됐어요.',
    storeName: '홍천 한식당',
    amount: 16800,
    coupon: Coupon(id: 'offline', value: 2000, expiresAt: ''),
    fallback: true,
  );

  /// ok | low_confidence | duplicate_image | duplicate_receipt
  /// | unknown_store | expired | daily_limit | wrong_code
  final bool verified;
  final String reason;

  /// 화면에 그대로 띄울 안내 문구
  final String? message;
  final String? storeName;
  final int? amount;
  final Coupon? coupon;

  /// true면 서버 대신 [offline] 대체 결과
  final bool fallback;
}

/// 보상 화면으로 넘기는 값.
class RewardArgs {
  const RewardArgs({
    required this.result,
    required this.sentence,
    required this.step,
  });

  final ReceiptResult result;
  final String sentence;

  /// 실전 주문에서 도달한 단계 (1~4)
  final int step;
}

abstract final class OrderApi {
  static String get _userId => currentUserId;

  /// POST /attempts. 실패해도 화면은 계속 진행합니다.
  static Future<void> saveAttempt({
    required String missionId,
    required int step,
    required String sentence,
  }) async {
    try {
      await ApiClient.postJson('/attempts', {
        'user_id': _userId,
        'mission_id': missionId,
        'step': step,
        'sentence': sentence,
      });
    } on ApiException {
      // 기록 실패는 시연에 영향 없음
    }
  }

  /// POST /receipts (영수증 사진 업로드). 서버에 못 붙으면 [ReceiptResult.offline].
  static Future<ReceiptResult> verifyReceipt({
    required String missionId,
    required Uint8List image,
    required String filename,
  }) async {
    try {
      final req =
          http.MultipartRequest(
              'POST',
              Uri.parse('${ApiClient.baseUrl}/receipts'),
            )
            ..fields['user_id'] = _userId
            ..fields['mission_id'] = missionId
            ..files.add(
              http.MultipartFile.fromBytes('image', image, filename: filename),
            );
      // 영수증 인식(LLM)까지 기다리므로 일반 요청보다 길게
      final streamed = await req.send().timeout(const Duration(seconds: 20));
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode != 200) {
        throw ApiException('/receipts → ${res.statusCode}');
      }
      return ReceiptResult.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
      );
    } catch (_) {
      return ReceiptResult.offline;
    }
  }

  /// POST /receipts/merchant-confirm (사장님 확인 코드). 서버에 못 붙으면 [ReceiptResult.offline].
  static Future<ReceiptResult> merchantConfirm({
    required String missionId,
    required String code,
  }) async {
    try {
      final json = await ApiClient.postJson('/receipts/merchant-confirm', {
        'user_id': _userId,
        'mission_id': missionId,
        'code': code,
      });
      return ReceiptResult.fromJson(json);
    } on ApiException {
      return ReceiptResult.offline;
    }
  }
}
