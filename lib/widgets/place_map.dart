import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../app/colors.dart';

/// 지도 위 핀 하나: 위치 + 그릴 위젯(핀·말풍선).
class MapPin {
  const MapPin({
    required this.lat,
    required this.lng,
    required this.child,
    this.width = 44,
    this.height = 44,
    this.alignment = Alignment.center,
    this.onTap,
  });

  final double lat;
  final double lng;
  final Widget child;
  final double width;
  final double height;

  /// 핀 위젯의 어느 점이 좌표에 오는지 (말풍선은 아래쪽 가운데).
  final Alignment alignment;
  final VoidCallback? onTap;

  LatLng get point => LatLng(lat, lng);
}

/// 앱 전체에서 쓰는 지도 (Android · iOS · 웹 모두 같은 화면).
///
/// OpenStreetMap 타일을 flutter_map으로 그려서 키가 필요 없습니다.
/// 핀이 여러 개면 모두 보이게 맞추고, [route]면 핀을 순서대로 점선으로 잇습니다 (내 지도).
class PlaceMap extends StatelessWidget {
  const PlaceMap({
    super.key,
    required this.pins,
    this.route = false,
    this.interactive = true,
    this.zoom = 16,
  });

  final List<MapPin> pins;
  final bool route;

  /// false면 손으로 움직일 수 없는 미리보기 (마이페이지 카드).
  final bool interactive;

  /// 핀이 하나(또는 없음)일 때 확대 정도.
  final double zoom;

  /// 핀이 없을 때 보여 줄 곳 (홍천읍).
  static const _home = LatLng(37.6970, 127.8888);

  /// 위젯 테스트에서 끕니다: 지도 타일은 인터넷과 캐시 폴더(path_provider)가 필요해요.
  static bool showTiles = true;

  @override
  Widget build(BuildContext context) {
    final points = [for (final p in pins) p.point];
    final distinct = points.toSet();
    final options = MapOptions(
      initialCenter: points.isEmpty ? _home : points.first,
      initialZoom: zoom,
      initialCameraFit: distinct.length > 1
          ? CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(points),
              padding: const EdgeInsets.fromLTRB(48, 72, 48, 40),
              maxZoom: 17,
            )
          : null,
      interactionOptions: InteractionOptions(
        flags: interactive
            ? InteractiveFlag.all & ~InteractiveFlag.rotate
            : InteractiveFlag.none,
      ),
    );
    return ColoredBox(
      color: const Color(0xFFE8EDEA),
      child: FlutterMap(
        options: options,
        children: [
          if (showTiles)
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.gajiso.iju',
              // 지도 색을 앱 톤(옅은 회녹색)에 맞춰 살짝 빼 줍니다.
              tileBuilder: (context, tile, _) => ColorFiltered(
                colorFilter: const ColorFilter.matrix([
                  0.85, 0.1, 0.05, 0, 8, //
                  0.08, 0.87, 0.05, 0, 10,
                  0.08, 0.1, 0.82, 0, 6,
                  0, 0, 0, 1, 0,
                ]),
                child: tile,
              ),
            ),
          if (route && points.length > 1)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: points,
                  color: AppColors.accent,
                  strokeWidth: 3,
                  pattern: StrokePattern.dashed(segments: const [8, 6]),
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              for (final p in pins)
                Marker(
                  point: p.point,
                  width: p.width,
                  height: p.height,
                  alignment: p.alignment,
                  child: p.onTap == null
                      ? p.child
                      : GestureDetector(onTap: p.onTap, child: p.child),
                ),
            ],
          ),
          const SimpleAttributionWidget(
            source: Text('OpenStreetMap', style: TextStyle(fontSize: 11)),
            backgroundColor: Color(0xB3FFFFFF),
          ),
        ],
      ),
    );
  }
}

/// 내 지도의 번호 핀 (오렌지 원 + 흰 테두리).
class NumberPin extends StatelessWidget {
  const NumberPin(this.number, {super.key, this.size = 36});

  final int number;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '$number',
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
          color: AppColors.text,
        ),
      ),
    );
  }
}

/// 가게 핀 (초록 물방울 + 아이콘).
class StorePin extends StatelessWidget {
  const StorePin({super.key, this.icon = Icons.ramen_dining_outlined});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 52,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          const Icon(Icons.location_on, size: 52, color: AppColors.primary),
          Positioned(
            top: 9,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
