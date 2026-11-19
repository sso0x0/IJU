// 구글 로그인 버튼 (Google Identity Services). lib/features/login/google_button_web.dart에서 부릅니다. 담당: 개발자1
// 구글 클라우드 콘솔 › 클라이언트 › 승인된 JavaScript 원본에 실행 주소(http://localhost:5000)가 있어야 합니다.
window.ijuGoogle = (function () {
  var loading = null;
  var initedFor = null;
  var onToken = null; // 마지막으로 그린 버튼의 화면이 토큰을 받습니다.

  function load() {
    if (window.google && google.accounts && google.accounts.id) return Promise.resolve();
    if (!loading) {
      loading = new Promise(function (resolve, reject) {
        var s = document.createElement('script');
        s.src = 'https://accounts.google.com/gsi/client';
        s.async = true;
        s.onload = resolve;
        s.onerror = function () { loading = null; reject(new Error('gsi')); };
        document.head.appendChild(s);
      });
    }
    return loading;
  }

  function whenSized(el) {
    return new Promise(function (resolve) {
      (function check() {
        if (el.isConnected && el.offsetWidth > 0) resolve();
        else requestAnimationFrame(check);
      })();
    });
  }

  // text: 'continue_with' | 'signup_with' | 'signin_with'
  function renderButton(el, clientId, text, tokenCallback, errorCallback) {
    onToken = tokenCallback;
    Promise.all([load(), whenSized(el)])
      .then(function () {
        if (initedFor !== clientId) {
          google.accounts.id.initialize({
            client_id: clientId,
            callback: function (response) {
              if (onToken && response && response.credential) onToken(response.credential);
            },
            auto_select: false,
            cancel_on_tap_outside: true,
          });
          initedFor = clientId;
        }
        el.innerHTML = '';
        google.accounts.id.renderButton(el, {
          type: 'standard',
          theme: 'outline',
          size: 'large',
          shape: 'rectangular',
          text: text,
          locale: 'ko',
          width: Math.max(200, Math.min(400, el.offsetWidth)),
        });
      })
      .catch(function () { if (errorCallback) errorCallback(); });
  }

  return { renderButton: renderButton };
})();
