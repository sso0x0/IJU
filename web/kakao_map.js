// 주문 지도 (카카오맵 JavaScript SDK). lib/features/order_map/kakao_map_web.dart에서 부릅니다. 담당: 개발자1
// 카카오 개발자 콘솔 > 앱 > 플랫폼 > Web 에 실행 주소(예: http://localhost:5000)를 등록해야 지도가 뜹니다.
window.ijuKakaoMap = (function () {
  var loading = null;
  var CENTER = [37.8813, 127.7298]; // 가게가 없을 때: 춘천

  function load(key) {
    if (window.kakao && kakao.maps && kakao.maps.LatLng) return Promise.resolve();
    if (!loading) {
      loading = new Promise(function (resolve, reject) {
        var s = document.createElement('script');
        s.src = 'https://dapi.kakao.com/v2/maps/sdk.js?autoload=false&libraries=services&appkey=' +
          encodeURIComponent(key);
        s.onload = function () { kakao.maps.load(resolve); };
        s.onerror = function () { loading = null; reject(new Error('kakao sdk')); };
        document.head.appendChild(s);
      });
    }
    return loading;
  }

  // 플랫폼 뷰 div가 화면에 붙고 크기가 생길 때까지 기다립니다.
  function whenSized(el) {
    return new Promise(function (resolve) {
      (function check() {
        if (el.isConnected && el.offsetWidth > 0 && el.offsetHeight > 0) resolve();
        else requestAnimationFrame(check);
      })();
    });
  }

  // 좌표가 없는 가게는 주소 → 가게 이름 순으로 찾아 봅니다.
  function locate(place) {
    if (place.lat != null && place.lng != null) return Promise.resolve(place);
    return new Promise(function (resolve) {
      var done = function (lat, lng) {
        if (lat != null) { place.lat = lat; place.lng = lng; }
        resolve(place);
      };
      var byName = function () {
        new kakao.maps.services.Places().keywordSearch(place.name, function (r, status) {
          if (status === kakao.maps.services.Status.OK && r.length) done(+r[0].y, +r[0].x);
          else done(null);
        });
      };
      if (!place.address) return byName();
      new kakao.maps.services.Geocoder().addressSearch(place.address, function (r, status) {
        if (status === kakao.maps.services.Status.OK && r.length) done(+r[0].y, +r[0].x);
        else byName();
      });
    });
  }

  function pinHtml(place, strong) {
    var wrap = document.createElement('button');
    wrap.type = 'button';
    wrap.setAttribute('aria-label', place.name);
    wrap.style.cssText = 'display:flex;flex-direction:column;align-items:center;gap:4px;' +
      'background:none;border:none;padding:0;cursor:pointer;' +
      "font-family:'Noto Sans KR',sans-serif";
    var label = document.createElement('span');
    label.textContent = place.name;
    label.style.cssText = 'height:28px;padding:0 10px;border-radius:14px;display:flex;align-items:center;' +
      'white-space:nowrap;font-size:13px;' +
      (strong
        ? 'background:#0E7C5A;color:#fff;font-weight:700;'
        : 'background:#fff;color:#1A1D21;border:1px solid #D5D8DD;');
    var dot = document.createElement('span');
    dot.style.cssText = 'width:12px;height:12px;border-radius:50%;border:3px solid #fff;' +
      'box-shadow:0 1px 3px rgba(0,0,0,.25);background:' + (strong ? '#0E7C5A' : '#1A1D21');
    wrap.appendChild(label);
    wrap.appendChild(dot);
    return wrap;
  }

  function draw(el, places, focusId, onSelect) {
    var map = el.__ijuMap;
    if (!map) {
      map = new kakao.maps.Map(el, { center: new kakao.maps.LatLng(CENTER[0], CENTER[1]), level: 6 });
      el.__ijuMap = map;
      el.__ijuOverlays = [];
      if (window.ResizeObserver) new ResizeObserver(function () { map.relayout(); }).observe(el);
    }
    el.__ijuOverlays.forEach(function (o) { o.setMap(null); });
    el.__ijuOverlays = [];

    var shown = places.filter(function (p) { return p.lat != null && p.lng != null; });
    var bounds = new kakao.maps.LatLngBounds();
    shown.forEach(function (p, i) {
      var pos = new kakao.maps.LatLng(p.lat, p.lng);
      var strong = focusId ? p.id === focusId : i === 0;
      var content = pinHtml(p, strong);
      content.addEventListener('click', function () { if (onSelect) onSelect(p.id); });
      var overlay = new kakao.maps.CustomOverlay({ position: pos, content: content, yAnchor: 1, zIndex: strong ? 2 : 1 });
      overlay.setMap(map);
      el.__ijuOverlays.push(overlay);
      bounds.extend(pos);
    });

    var focus = shown.filter(function (p) { return p.id === focusId; })[0];
    if (focus) {
      map.setLevel(3);
      map.setCenter(new kakao.maps.LatLng(focus.lat, focus.lng));
    } else if (shown.length === 1) {
      map.setLevel(4);
      map.setCenter(new kakao.maps.LatLng(shown[0].lat, shown[0].lng));
    } else if (shown.length > 1) {
      map.setBounds(bounds, 60, 40, 40, 40);
    }
  }

  function render(el, key, placesJson, focusId, onSelect) {
    var places = JSON.parse(placesJson);
    Promise.all([load(key), whenSized(el)])
      .then(function () { return Promise.all(places.map(locate)); })
      .then(function () { draw(el, places, focusId || null, onSelect); })
      .catch(function () {
        el.style.display = 'flex';
        el.style.alignItems = 'center';
        el.style.justifyContent = 'center';
        el.style.color = '#5A606A';
        el.style.fontSize = '14px';
        el.textContent = '지도를 불러오지 못했어요';
      });
  }

  return { render: render };
})();
