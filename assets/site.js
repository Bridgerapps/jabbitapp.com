// Shared JS: mobile nav toggle
(() => {
  const btn = document.getElementById('mobile-menu-btn');
  const menu = document.getElementById('mobile-menu');
  const icon = document.getElementById('menu-icon');

  if (!btn || !menu || !icon) return;

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
})();
