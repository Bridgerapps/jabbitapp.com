// Shared JS: mobile nav + lightweight analytics
(() => {
  // -----------------
  // Mobile nav toggle
  // -----------------
  const btn = document.getElementById('mobile-menu-btn');
  const menu = document.getElementById('mobile-menu');
  const icon = document.getElementById('menu-icon');

  if (btn && menu && icon) {
    const openPath = 'M6 18L18 6M6 6l12 12';
    const closedPath = 'M4 6h16M4 12h16M4 18h16';

    const setOpen = (isOpen) => {
      menu.classList.toggle('hidden', !isOpen);
      icon.setAttribute('d', isOpen ? openPath : closedPath);
      btn.setAttribute('aria-expanded', String(isOpen));
    };

    btn.addEventListener('click', () => {
      const isOpen = menu.classList.contains('hidden');
      setOpen(isOpen);
    });

    menu.querySelectorAll('a').forEach((a) => {
      a.addEventListener('click', () => setOpen(false));
    });

    setOpen(false);
  }

  // ---------
  // Analytics
  // ---------
  const APP_STORE_RE = /apps\.apple\.com\/.*\/id6756848719/i;

  const sendTrack = (event, target = '') => {
    const payload = {
      event,
      page: location.pathname || '/',
      target,
      ref: document.referrer || '',
      ts: Date.now(),
    };

    // Prefer same-origin proxy endpoint to avoid mixed-content issues.
    const url = '/api/track';

    try {
      if (navigator.sendBeacon) {
        const blob = new Blob([JSON.stringify(payload)], { type: 'application/json' });
        navigator.sendBeacon(url, blob);
        return;
      }
    } catch (_) {}

    // Keepalive fetch for non-Beacon browsers.
    fetch(url, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(payload),
      keepalive: true,
      credentials: 'omit',
    }).catch(() => {
      // Fallback: GET "pixel" hit to our same-origin proxy endpoint.
      // (No secrets in the browser; server will attach secret when forwarding.)
      const q = new URLSearchParams({
        event,
        page: payload.page,
        target: target || '',
        ref: payload.ref || '',
      });
      const img = new Image();
      img.src = `/api/track?${q.toString()}`;
    });
  };

  // One pageview per page load
  sendTrack('pageview');

  // Track App Store outbound click intent
  document.addEventListener('click', (e) => {
    const a = e.target && e.target.closest ? e.target.closest('a[href]') : null;
    if (!a) return;
    const href = a.getAttribute('href') || '';
    if (APP_STORE_RE.test(href)) {
      sendTrack('app_store_click', href);
    }
  }, { capture: true });
})();
