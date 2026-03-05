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
  // If link has a data-track label, include it so we can differentiate hero vs footer vs sticky.
  document.addEventListener('click', (e) => {
    const a = e.target && e.target.closest ? e.target.closest('a[href]') : null;
    if (!a) return;
    const href = a.getAttribute('href') || '';
    if (APP_STORE_RE.test(href)) {
      const label = (a.dataset && (a.dataset.track || a.dataset.trackLabel || a.dataset.trackTarget)) || '';
      sendTrack('app_store_click', label ? `${label}|${href}` : href);
    }
  }, { capture: true });

  // ----------------------
  // Sticky mobile App Store CTA
  // ----------------------
  // Goal: catch long-scroll readers on guides/SEO pages.
  // Dismiss persists for a week.
  try {
    const path = location.pathname || '/';
    const isHome = path === '/' || /\/index\.html$/i.test(path);
    const isLegal = path.startsWith('/privacy') || path.startsWith('/terms');
    const isSmallScreen = window.matchMedia && window.matchMedia('(max-width: 767px)').matches;

    const DISMISS_KEY = 'jabbit_sticky_cta_dismissed_at';
    const dismissedAt = Number(localStorage.getItem(DISMISS_KEY) || '0');
    const weekMs = 7 * 24 * 60 * 60 * 1000;
    const isDismissed = dismissedAt && (Date.now() - dismissedAt) < weekMs;

    if (!isHome && !isLegal && isSmallScreen && !isDismissed) {
      const bar = document.createElement('div');
      bar.setAttribute('role', 'region');
      bar.setAttribute('aria-label', 'Download Jabbit');
      bar.style.position = 'fixed';
      bar.style.left = '12px';
      bar.style.right = '12px';
      bar.style.bottom = '12px';
      bar.style.zIndex = '9999';
      bar.style.background = 'rgba(255,255,255,0.92)';
      bar.style.backdropFilter = 'blur(10px)';
      bar.style.border = '1px solid rgba(226,232,240,0.9)';
      bar.style.borderRadius = '16px';
      bar.style.boxShadow = '0 10px 30px rgba(2,6,23,0.12)';
      bar.style.padding = '10px 10px';

      const inner = document.createElement('div');
      inner.style.display = 'flex';
      inner.style.alignItems = 'center';
      inner.style.gap = '10px';

      const cta = document.createElement('a');
      cta.href = 'https://apps.apple.com/us/app/jabbit-peptide-tracker/id6756848719';
      cta.target = '_blank';
      cta.rel = 'noopener noreferrer';
      cta.dataset.track = 'sticky_cta';
      cta.textContent = 'Get Jabbit on the App Store';
      cta.style.flex = '1';
      cta.style.display = 'inline-flex';
      cta.style.alignItems = 'center';
      cta.style.justifyContent = 'center';
      cta.style.padding = '12px 12px';
      cta.style.borderRadius = '14px';
      cta.style.fontWeight = '750';
      cta.style.background = '#14b8a6';
      cta.style.color = '#062a27';
      cta.style.textDecoration = 'none';

      const close = document.createElement('button');
      close.type = 'button';
      close.setAttribute('aria-label', 'Dismiss');
      close.textContent = '×';
      close.style.width = '40px';
      close.style.height = '40px';
      close.style.borderRadius = '12px';
      close.style.border = '1px solid rgba(226,232,240,0.9)';
      close.style.background = 'transparent';
      close.style.color = '#0f172a';
      close.style.fontSize = '22px';
      close.style.lineHeight = '1';
      close.style.cursor = 'pointer';

      close.addEventListener('click', () => {
        localStorage.setItem(DISMISS_KEY, String(Date.now()));
        bar.remove();
        document.documentElement.style.scrollPaddingBottom = '';
      });

      inner.appendChild(cta);
      inner.appendChild(close);
      bar.appendChild(inner);
      document.body.appendChild(bar);

      // Prevent the bar from covering last lines/footers.
      document.documentElement.style.scrollPaddingBottom = '90px';
    }
  } catch (_) {}
})();
