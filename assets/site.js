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
  const recentTrackKeys = new Map();

  // ----------------------
  // iOS Smart App Banner
  // ----------------------
  // Safari can show a native banner prompting install/open.
  // We inject it via JS so every static page gets it without duplicating <head> markup.
  try {
    const ua = navigator.userAgent || '';
    const isIOS = /iPad|iPhone|iPod/i.test(ua);
    const isStandalone = (window.navigator && window.navigator.standalone) || false;
    const path = location.pathname || '/';
    const isLegal = path.startsWith('/privacy') || path.startsWith('/terms');

    if (isIOS && !isStandalone && !isLegal) {
      const existing = document.querySelector('meta[name="apple-itunes-app"]');
      if (!existing) {
        const meta = document.createElement('meta');
        meta.setAttribute('name', 'apple-itunes-app');
        meta.setAttribute('content', 'app-id=6756848719');
        document.head && document.head.appendChild(meta);
      }
    }
  } catch (_) {}

  const sendTrack = (event, target = '') => {
    const payload = {
      event,
      page: location.pathname || '/',
      target,
      ref: document.referrer || '',
      ts: Date.now(),
    };

    // Guard against duplicate click events from nested handlers or rapid taps.
    const dedupeKey = `${payload.event}|${payload.page}|${payload.target}`;
    const now = Date.now();
    const lastSentAt = recentTrackKeys.get(dedupeKey) || 0;
    if (now - lastSentAt < 1500) return;
    recentTrackKeys.set(dedupeKey, now);

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
  // Skip internal health-check/test routes so we don't pollute funnel metrics.
  // (These routes can be hit by uptime monitors or local checks.)
  const pathname = (location && location.pathname) ? location.pathname : '/';
  const isTestRoute = /^\/health-test\/?$/.test(pathname);
  if (!isTestRoute) {
    sendTrack('pageview');
  }

  // Normalize App Store link behavior (always new tab + safe rel)
  // This reduces "page lost" friction and keeps outbound clicks consistent across older pages.
  try {
    document.querySelectorAll('a[href]').forEach((a) => {
      const href = a.getAttribute('href') || '';
      if (!APP_STORE_RE.test(href)) return;
      a.setAttribute('target', '_blank');
      const rel = (a.getAttribute('rel') || '').toLowerCase();
      if (!rel.includes('noopener')) a.setAttribute('rel', `${rel ? rel + ' ' : ''}noopener noreferrer`.trim());
    });
  } catch (_) {}

  // Basic engagement: scroll depth (helps us prioritize pages that actually get read)
  // Fires at most once per threshold.
  try {
    if (!isTestRoute) {
      const fired = new Set();
      const thresholds = [25, 50, 75];

      const onScroll = () => {
        const doc = document.documentElement;
        const scrollTop = window.scrollY || doc.scrollTop || 0;
        const height = Math.max(1, (doc.scrollHeight || 0) - (window.innerHeight || 0));
        const pct = Math.round((scrollTop / height) * 100);

        thresholds.forEach((t) => {
          if (pct >= t && !fired.has(t)) {
            fired.add(t);
            sendTrack('scroll_depth', String(t));
          }
        });

        if (fired.size === thresholds.length) {
          window.removeEventListener('scroll', onScroll, { passive: true });
        }
      };

      window.addEventListener('scroll', onScroll, { passive: true });
    }
  } catch (_) {}

  // Track App Store outbound click intent
  // If link has a data-track label, include it so we can differentiate hero vs footer vs sticky.
  document.addEventListener('click', (e) => {
    if (isTestRoute) return;
    const a = e.target && e.target.closest ? e.target.closest('a[href]') : null;
    if (!a) return;
    const href = a.getAttribute('href') || '';

    // Optional internal-link tracking for key funnels (no personal data).
    // Usage: <a href="/some-page" data-track-internal="home_popular_trackers">...
    try {
      const internalLabel = a.getAttribute('data-track-internal') || (a.dataset && (a.dataset.trackInternal || a.dataset.trackinternal)) || '';
      const isInternal = href.startsWith('/') && !href.startsWith('//') && !href.startsWith('/api/');
      if (internalLabel && isInternal) {
        sendTrack('internal_click', `${String(internalLabel).slice(0, 60)}|${href.slice(0, 120)}`);
      }
    } catch (_) {}

    if (APP_STORE_RE.test(href)) {
      const explicit = (a.dataset && (a.dataset.track || a.dataset.trackLabel || a.dataset.trackTarget)) || '';

      // Fallback label: helps us attribute clicks without hand-tagging every page.
      // Keep it short + low-entropy (avoid capturing personal data).
      const clean = (s) => String(s || '')
        .replace(/\s+/g, ' ')
        .trim()
        .slice(0, 60);

      const context = (() => {
        if (a.id) return `id:${clean(a.id)}`;
        if (a.closest && a.closest('nav')) return 'nav';
        if (a.closest && a.closest('header')) return 'header';
        if (a.closest && a.closest('footer')) return 'footer';
        if (a.closest && a.closest('main')) return 'main';
        return 'body';
      })();

      const text = clean(a.textContent);
      const auto = text ? `auto:${context}:${text}` : `auto:${context}`;
      const label = explicit || auto;

      sendTrack('app_store_click', `${label}|${href}`);
    }
  }, { capture: true });

  // ----------------------
  // Inline top-of-page download banner (all content pages)
  // ----------------------
  // Goal: increase App Store clicks from SEO pages without editing every HTML file.
  // Shows once per 7 days per device (dismissible).
  try {
    const path = location.pathname || '/';
    const isHome = path === '/' || /\/index\.html$/i.test(path);
    const isLegal = path.startsWith('/privacy') || path.startsWith('/terms');

    const DISMISS_KEY = 'jabbit_inline_banner_dismissed_at';
    const dismissedAt = Number(localStorage.getItem(DISMISS_KEY) || '0');
    const weekMs = 7 * 24 * 60 * 60 * 1000;
    const isDismissed = dismissedAt && (Date.now() - dismissedAt) < weekMs;

    if (!isHome && !isLegal && !isDismissed && document && document.body) {
      const wrap = document.createElement('div');
      wrap.setAttribute('role', 'region');
      wrap.setAttribute('aria-label', 'Download Jabbit');
      wrap.style.margin = '14px auto 16px';
      wrap.style.maxWidth = '980px';
      wrap.style.padding = '0 12px';

      const bar = document.createElement('div');
      bar.style.display = 'flex';
      bar.style.flexWrap = 'wrap';
      bar.style.alignItems = 'center';
      bar.style.gap = '10px';
      bar.style.background = 'rgba(240, 253, 250, 0.9)';
      bar.style.border = '1px solid rgba(20, 184, 166, 0.25)';
      bar.style.borderRadius = '16px';
      bar.style.boxShadow = '0 10px 30px rgba(2,6,23,0.06)';
      bar.style.padding = '12px 12px';

      const text = document.createElement('div');
      text.style.flex = '1';
      text.style.minWidth = '220px';

      const title = document.createElement('div');
      title.textContent = 'Track GLP-1 doses + symptoms privately on iPhone';
      title.style.fontWeight = '750';
      title.style.color = '#0f172a';

      const sub = document.createElement('div');
      sub.textContent = 'Dose log, side effects, progress, and reminders in one place. No account. Syncs through your iCloud.';
      sub.style.fontSize = '13px';
      sub.style.color = '#334155';
      sub.style.marginTop = '2px';

      text.appendChild(title);
      text.appendChild(sub);

      const cta = document.createElement('a');
      cta.href = 'https://apps.apple.com/app/id6756848719';
      cta.target = '_blank';
      cta.rel = 'noopener noreferrer';
      cta.dataset.track = 'inline_top_banner';
      cta.textContent = 'Start free trial';
      cta.style.display = 'inline-flex';
      cta.style.alignItems = 'center';
      cta.style.justifyContent = 'center';
      cta.style.padding = '10px 12px';
      cta.style.borderRadius = '14px';
      cta.style.fontWeight = '800';
      cta.style.background = '#14b8a6';
      cta.style.color = '#062a27';
      cta.style.textDecoration = 'none';

      const links = document.createElement('div');
      links.style.display = 'flex';
      links.style.flexWrap = 'wrap';
      links.style.gap = '8px';
      links.style.alignItems = 'center';
      links.style.fontSize = '13px';
      links.style.color = '#0f766e';

      const mkLink = (label, href) => {
        const a = document.createElement('a');
        a.href = href;
        a.textContent = label;
        a.style.fontWeight = '700';
        a.style.color = '#0f766e';
        a.style.textDecoration = 'none';
        a.setAttribute('data-track-internal', 'inline_banner_popular_tracker');
        return a;
      };

      const linksLabel = document.createElement('span');
      linksLabel.textContent = 'Popular trackers:';
      linksLabel.style.color = '#475569';
      linksLabel.style.fontWeight = '600';

      links.appendChild(linksLabel);
      links.appendChild(mkLink('Ozempic', '/ozempic-injection-tracker.html'));
      links.appendChild(mkLink('Wegovy', '/wegovy-injection-tracker.html'));
      links.appendChild(mkLink('Mounjaro', '/mounjaro-injection-tracker.html'));
      links.appendChild(mkLink('Zepbound', '/zepbound-injection-tracker.html'));

      const close = document.createElement('button');
      close.type = 'button';
      close.setAttribute('aria-label', 'Dismiss');
      close.textContent = '×';
      close.style.width = '38px';
      close.style.height = '38px';
      close.style.borderRadius = '12px';
      close.style.border = '1px solid rgba(15, 23, 42, 0.12)';
      close.style.background = 'rgba(255,255,255,0.6)';
      close.style.color = '#0f172a';
      close.style.fontSize = '22px';
      close.style.lineHeight = '1';
      close.style.cursor = 'pointer';

      close.addEventListener('click', () => {
        localStorage.setItem(DISMISS_KEY, String(Date.now()));
        wrap.remove();
        sendTrack('inline_banner_dismiss');
      });

      bar.appendChild(text);
      bar.appendChild(cta);
      bar.appendChild(close);
      wrap.appendChild(bar);
      wrap.appendChild(links);

      // Insert early in body so it appears above the fold on content pages.
      const first = document.body.firstElementChild;
      if (first) document.body.insertBefore(wrap, first);
      else document.body.appendChild(wrap);

      sendTrack('inline_banner_shown');
    }
  } catch (_) {}

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

    const shouldEnable = !isLegal && isSmallScreen && !isDismissed;

    // On content pages: show immediately.
    // On home: wait until the user scrolls a bit so we don't compete with the hero CTA.
    const HOME_SCROLL_TRIGGER_PX = 520;

    if (shouldEnable) {
      let shown = false;

      const showBar = () => {
        if (shown) return;
        shown = true;

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
        cta.href = 'https://apps.apple.com/app/id6756848719';
        cta.target = '_blank';
        cta.rel = 'noopener noreferrer';
        cta.dataset.track = isHome ? 'sticky_cta_home' : 'sticky_cta';
        cta.textContent = isHome ? 'Start tracking on iPhone' : 'Track this in Jabbit';
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
      };

      if (!isHome) {
        showBar();
      } else {
        const onScroll = () => {
          if (window.scrollY > HOME_SCROLL_TRIGGER_PX) {
            window.removeEventListener('scroll', onScroll);
            showBar();
          }
        };

        window.addEventListener('scroll', onScroll, { passive: true });
        onScroll();
      }
    }
  } catch (_) {}
})();
