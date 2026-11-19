import 'package:go_router/go_router.dart';

import '../../app/languages.dart';

import 'package:material_ui/material_ui.dart';

import '../../api/api_client.dart';
import '../../app/colors.dart';
import '../../app/session.dart';
import '../../app/theme.dart';
import '../../widgets/place_map.dart';
import '../missions/missions_api.dart' show menuScanPath;
import 'nearby_api.dart';

/// 홈 '가까운 음식점': 현재 위치에서 1km 안의 음식점을 가까운 순으로. 담당: 개발자1
///
/// 가게 데이터는 소상공인 상가정보(places 표)이고, 이주 참여 가게는 앞에 '이주 참여'로 표시해요.
/// 1km 안에 없으면 3km까지 넓혀 봅니다. 가게를 누르면 그 가게로 메뉴판 찍기를 시작해요
/// (업종 힌트가 메뉴 인식에 들어가요).
class NearbyStores extends StatefulWidget {
  const NearbyStores({super.key});

  @override
  State<NearbyStores> createState() => _NearbyStoresState();
}

enum _Status { locating, loading, ready, location, offline }

class _NearbyStoresState extends State<NearbyStores> {
  _Status _status = _Status.locating;
  LocationProblem? _problem;
  List<NearbyPlace> _places = const [];
  int _radius = 1000;
  (double, double)? _here;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _status = _Status.locating);
    try {
      _here = await NearbyApi.locate();
    } on LocationException catch (e) {
      if (mounted) {
        setState(() {
          _status = _Status.location;
          _problem = e.problem;
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() => _status = _Status.loading);
    try {
      final (lat, lng) = _here!;
      var places = await NearbyApi.places(lat, lng);
      var radius = 1000;
      if (places.isEmpty) {
        radius = 3000;
        places = await NearbyApi.places(lat, lng, radius: radius);
      }
      if (!mounted) return;
      setState(() {
        _places = places;
        _radius = radius;
        _status = _Status.ready;
      });
    } on ApiException {
      if (mounted) setState(() => _status = _Status.offline);
    }
  }

  void _open(NearbyPlace p) {
    // 메뉴판 인식에 이 가게 업종을 힌트로 넘겨요 (POST /ai/menu-scan place_id).
    AppSession.placeId = p.id;
    context.push(menuScanPath(p.scenarioId));
  }

  void _showMap() {
    final here = _here;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                '가까운 음식점 ${_places.length}곳',
                style: AppText.subtitle,
              ),
            ),
            Expanded(
              child: PlaceMap(
                zoom: 16,
                pins: [
                  if (here != null)
                    MapPin(
                      lat: here.$1,
                      lng: here.$2,
                      width: 22,
                      height: 22,
                      child: const _HereDot(),
                    ),
                  for (final p in _places)
                    MapPin(
                      lat: p.lat,
                      lng: p.lng,
                      width: 44,
                      height: 52,
                      alignment: Alignment.topCenter,
                      onTap: () {
                        Navigator.pop(context);
                        _open(p);
                      },
                      child: StorePin(icon: p.icon),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '가까운 음식점',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    _status == _Status.ready
                        ? '${nt('Quán gần đây')} · ${_radius ~/ 1000}km'
                        : nt('Quán gần đây'),
                    style: AppText.native.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSub,
                    ),
                  ),
                ],
              ),
            ),
            if (_status == _Status.ready && _places.isNotEmpty)
              TextButton.icon(
                onPressed: _showMap,
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('지도'),
              ),
            IconButton(
              onPressed:
                  _status == _Status.locating || _status == _Status.loading
                  ? null
                  : _load,
              tooltip: '내 위치로 다시 찾기',
              icon: const Icon(Icons.my_location, size: 20),
              color: AppColors.primaryDark,
            ),
          ],
        ),
        const SizedBox(height: 8),
        switch (_status) {
          _Status.locating => const _Message(
            icon: Icons.my_location,
            text: '현재 위치를 찾고 있어요…',
            busy: true,
          ),
          _Status.loading => const _Message(
            icon: Icons.storefront_outlined,
            text: '근처 음식점을 찾고 있어요…',
            busy: true,
          ),
          _Status.offline => _Message(
            icon: Icons.cloud_off_outlined,
            text: '서버에 연결하지 못했어요',
            action: '다시 시도',
            onAction: _load,
          ),
          _Status.location => _locationMessage(),
          _Status.ready when _places.isEmpty => const _Message(
            icon: Icons.search_off,
            text: '3km 안에 등록된 가게가 없어요.\n가게 정보는 지금 강원도만 있어요.',
          ),
          _Status.ready => SizedBox(
            height: 156,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _places.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) =>
                  _PlaceCard(place: _places[i], onTap: () => _open(_places[i])),
            ),
          ),
        },
      ],
    );
  }

  Widget _locationMessage() {
    final problem = _problem ?? LocationProblem.failed;
    return switch (problem) {
      LocationProblem.serviceOff => _Message(
        icon: Icons.location_disabled,
        text: '휴대폰 위치(GPS)가 꺼져 있어요',
        action: '위치 켜기',
        onAction: () => NearbyApi.openSettings(problem),
      ),
      LocationProblem.denied => _Message(
        icon: Icons.location_off_outlined,
        text: '위치를 허용하면 가까운 음식점을 보여 줘요',
        action: '위치 허용하기',
        onAction: _load,
      ),
      LocationProblem.deniedForever => _Message(
        icon: Icons.location_off_outlined,
        text: '설정에서 이주 앱의 위치 권한을 켜 주세요',
        action: '설정 열기',
        onAction: () => NearbyApi.openSettings(problem),
      ),
      LocationProblem.failed => _Message(
        icon: Icons.location_searching,
        text: '현재 위치를 알 수 없어요',
        action: '다시 시도',
        onAction: _load,
      ),
    };
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.place, required this.onTap});

  final NearbyPlace place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(
            color: place.partner ? AppColors.primary : AppColors.border,
            width: place.partner ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        place.icon,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                    if (place.partner)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.pointBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          '이주 참여',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.pointText,
                          ),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  place.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${place.typeLabel} · ${place.distanceLabel}',
                  style: AppText.caption.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    this.action,
    this.onAction,
    this.busy = false,
  });

  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          if (busy)
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(icon, size: 20, color: AppColors.textSub),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.textBody,
              ),
            ),
          ),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

/// 지도 위 내 위치 (파란 점).
class _HereDot extends StatelessWidget {
  const _HereDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2F6FD6),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x552F6FD6), blurRadius: 8, spreadRadius: 4),
        ],
      ),
    );
  }
}
