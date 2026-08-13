document.addEventListener('DOMContentLoaded', () => {
  initGate();
  initScrollProgress();
  initReveals();
  initTabs();
  initCopyButtons();
  initTypewriter();
  initStatCounters();
  initParallax();
  initMouseGlow();
  initTiltCards();
  initKonami();
  initCommandPalette();
  initDynamicFavicon();
  initTimeOfDay();
});

function initGate() {
  const gate = document.querySelector('.gate');
  if (!gate) return;
  const btn = gate.querySelector('.gate-enter');
  if (!btn) return;

  document.body.style.overflow = 'hidden';
  btn.addEventListener('click', () => {
    gate.classList.add('is-open');
    document.body.style.overflow = '';
  });
}

function initScrollProgress() {
  const bar = document.querySelector('.scroll-progress');
  if (!bar) return;

  function update() {
    const h = document.documentElement.scrollHeight - window.innerHeight;
    if (h <= 0) { bar.style.width = '0%'; return; }
    bar.style.width = (window.scrollY / h * 100) + '%';
  }

  window.addEventListener('scroll', update, { passive: true });
  update();
}

function initReveals() {
  const els = document.querySelectorAll('.reveal');
  if (!els.length) return;

  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    els.forEach(el => el.classList.add('is-visible'));
    return;
  }

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-visible');
          observer.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.15, rootMargin: '0px 0px -40px 0px' }
  );

  els.forEach(el => observer.observe(el));
}

function initTabs() {
  const tablist = document.querySelector('[role="tablist"]');
  if (!tablist) return;

  const tabs = Array.from(tablist.querySelectorAll('[role="tab"]'));
  const panels = tabs.map(tab =>
    document.getElementById(tab.getAttribute('aria-controls'))
  );

  function activateTab(tab) {
    tabs.forEach((t, i) => {
      t.setAttribute('aria-selected', 'false');
      t.setAttribute('tabindex', '-1');
      panels[i].classList.remove('active');
    });
    tab.setAttribute('aria-selected', 'true');
    tab.setAttribute('tabindex', '0');
    tab.focus();
    document.getElementById(tab.getAttribute('aria-controls')).classList.add('active');
  }

  tabs.forEach(tab => {
    tab.addEventListener('click', () => activateTab(tab));
  });

  tablist.addEventListener('keydown', (e) => {
    const idx = tabs.indexOf(document.activeElement);
    if (idx === -1) return;

    let next;
    if (e.key === 'ArrowRight' || e.key === 'ArrowDown') {
      e.preventDefault();
      next = tabs[(idx + 1) % tabs.length];
    } else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') {
      e.preventDefault();
      next = tabs[(idx - 1 + tabs.length) % tabs.length];
    } else if (e.key === 'Home') {
      e.preventDefault();
      next = tabs[0];
    } else if (e.key === 'End') {
      e.preventDefault();
      next = tabs[tabs.length - 1];
    }
    if (next) activateTab(next);
  });
}

function initCopyButtons() {
  document.querySelectorAll('[data-copy]').forEach(btn => {
    btn.addEventListener('click', async () => {
      const text = btn.getAttribute('data-copy');
      const original = btn.textContent;
      try {
        await navigator.clipboard.writeText(text);
      } catch {
        const input = document.createElement('input');
        input.value = text;
        document.body.appendChild(input);
        input.select();
        document.execCommand('copy');
        document.body.removeChild(input);
      }
      btn.textContent = 'Copied';
      setTimeout(() => { btn.textContent = original; }, 1500);
    });
  });
}

function initTypewriter() {
  const el = document.querySelector('[data-typewriter]');
  if (!el) return;
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

  const text = el.getAttribute('data-typewriter');
  el.textContent = '';

  const cursor = document.createElement('span');
  cursor.className = 'typewriter-cursor';
  el.appendChild(cursor);

  let i = 0;
  function type() {
    if (i < text.length) {
      el.insertBefore(document.createTextNode(text[i]), cursor);
      i++;
      setTimeout(type, 70 + Math.floor(Math.random() * 40));
    }
  }

  setTimeout(type, 800);
}

function initStatCounters() {
  const numbers = document.querySelectorAll('[data-count]');
  if (!numbers.length) return;
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    numbers.forEach(el => { el.textContent = el.getAttribute('data-count'); });
    return;
  }

  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (!entry.isIntersecting) return;
      const el = entry.target;
      const target = parseInt(el.getAttribute('data-count'), 10);
      observer.unobserve(el);
      animateCount(el, target);
    });
  }, { threshold: 0.5 });

  numbers.forEach(el => {
    el.textContent = '0';
    observer.observe(el);
  });
}

function animateCount(el, target) {
  const duration = 2000;
  const start = performance.now();

  function step(now) {
    const t = Math.min((now - start) / duration, 1);
    const eased = 1 - Math.pow(1 - t, 3);
    el.textContent = Math.round(eased * target);
    if (t < 1) requestAnimationFrame(step);
  }

  requestAnimationFrame(step);
}

function initParallax() {
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

  const particles = document.querySelector('.particles');
  if (!particles) return;

  window.addEventListener('scroll', () => {
    const y = window.scrollY;
    particles.style.transform = 'translateY(' + (y * 0.3) + 'px)';
  }, { passive: true });
}

function initMouseGlow() {
  const glow = document.querySelector('.mouse-glow');
  if (!glow) return;
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
  if ('ontouchstart' in window) { glow.style.display = 'none'; return; }

  document.addEventListener('mousemove', (e) => {
    glow.style.left = e.clientX + 'px';
    glow.style.top = e.clientY + 'px';
  }, { passive: true });
}

function initTiltCards() {
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
  if ('ontouchstart' in window) return;

  document.querySelectorAll('.tilt-card').forEach(card => {
    card.addEventListener('mousemove', (e) => {
      const rect = card.getBoundingClientRect();
      const x = (e.clientX - rect.left) / rect.width - 0.5;
      const y = (e.clientY - rect.top) / rect.height - 0.5;
      card.style.transform =
        'perspective(800px) rotateY(' + (x * 8) + 'deg) rotateX(' + (-y * 8) + 'deg)';
    });

    card.addEventListener('mouseleave', () => {
      card.style.transform = 'perspective(800px) rotateY(0deg) rotateX(0deg)';
    });
  });
}

function initKonami() {
  const code = ['ArrowUp','ArrowUp','ArrowDown','ArrowDown','ArrowLeft','ArrowRight','ArrowLeft','ArrowRight','b','a'];
  let pos = 0;

  document.addEventListener('keydown', (e) => {
    if (e.key === code[pos]) {
      pos++;
      if (pos === code.length) {
        pos = 0;
        triggerKonami();
      }
    } else {
      pos = 0;
    }
  });
}

function triggerKonami() {
  document.body.classList.add('konami-active');
  setTimeout(() => document.body.classList.remove('konami-active'), 600);

  let toast = document.querySelector('.konami-toast');
  if (!toast) {
    toast = document.createElement('div');
    toast.className = 'konami-toast';
    toast.textContent = 'Achievement unlocked: You found the secret. Welcome home.';
    document.body.appendChild(toast);
  }

  requestAnimationFrame(() => {
    toast.classList.add('is-visible');
    setTimeout(() => toast.classList.remove('is-visible'), 3000);
  });
}

function initCommandPalette() {
  const overlay = document.querySelector('.palette-overlay');
  if (!overlay) return;

  const input = overlay.querySelector('.palette-input');
  const results = overlay.querySelector('.palette-results');

  const items = [
    { icon: '🟢', label: 'Server Status', hint: 'Home', href: '/' },
    { icon: '📖', label: 'Getting Started', hint: 'Guide', href: '/guide.html' },
    { icon: '📋', label: 'Changelog', hint: 'Updates', href: '/changelog.html' },
    { icon: '🛡️', label: 'Ops & Security', hint: 'SDLC', href: '/ops.html' },
    { icon: '🗺️', label: 'Live Map', hint: 'External', href: 'https://map.geigercapital.us' },
    { icon: '📦', label: 'Modpack', hint: 'CurseForge', href: 'https://www.curseforge.com/minecraft/modpacks/homestead-cozy' },
    { icon: '💬', label: 'Community', hint: 'Coming Soon', href: '#' },
    { icon: '#', label: 'Stats', hint: 'Section', action: () => scrollToSelector('.stats') },
    { icon: '🏗️', label: 'Featured Build', hint: 'Section', action: () => scrollToSelector('.spotlight') },
    { icon: '🖼️', label: 'Gallery', hint: 'Section', action: () => scrollToSelector('.gallery') },
    { icon: '👥', label: 'Community', hint: 'Section', action: () => scrollToSelector('.roster') },
  ];

  function scrollToSelector(sel) {
    const el = document.querySelector(sel);
    if (el) el.scrollIntoView({ behavior: 'smooth', block: 'center' });
  }

  function render(query) {
    const q = query.toLowerCase().trim();
    const filtered = q ? items.filter(i => i.label.toLowerCase().includes(q)) : items;

    results.innerHTML = filtered.map((item, i) =>
      '<a class="palette-item' + (i === 0 ? ' is-active' : '') + '" ' +
      (item.href ? 'href="' + item.href + '"' : 'data-action="' + i + '"') + '>' +
      '<span class="palette-item-icon">' + item.icon + '</span>' +
      '<span class="palette-item-label">' + item.label + '</span>' +
      '<span class="palette-item-hint">' + item.hint + '</span></a>'
    ).join('');

    results.querySelectorAll('[data-action]').forEach(el => {
      el.addEventListener('click', (e) => {
        e.preventDefault();
        const idx = parseInt(el.getAttribute('data-action'), 10);
        const match = filtered[idx];
        if (match && match.action) match.action();
        closePalette();
      });
    });
  }

  function openPalette() {
    overlay.classList.add('is-open');
    input.value = '';
    render('');
    setTimeout(() => input.focus(), 50);
  }

  function closePalette() {
    overlay.classList.remove('is-open');
  }

  document.addEventListener('keydown', (e) => {
    if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
      e.preventDefault();
      if (overlay.classList.contains('is-open')) closePalette();
      else openPalette();
    }
    if (e.key === 'Escape' && overlay.classList.contains('is-open')) {
      closePalette();
    }
  });

  overlay.addEventListener('click', (e) => {
    if (e.target === overlay) closePalette();
  });

  input.addEventListener('input', () => render(input.value));

  input.addEventListener('keydown', (e) => {
    const active = results.querySelector('.is-active');
    if (e.key === 'Enter' && active) {
      e.preventDefault();
      active.click();
      closePalette();
    }
    if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      e.preventDefault();
      const all = Array.from(results.querySelectorAll('.palette-item'));
      if (!all.length) return;
      const idx = all.indexOf(active);
      if (active) active.classList.remove('is-active');
      const next = e.key === 'ArrowDown'
        ? all[(idx + 1) % all.length]
        : all[(idx - 1 + all.length) % all.length];
      next.classList.add('is-active');
      next.scrollIntoView({ block: 'nearest' });
    }
  });
}

function initDynamicFavicon() {
  const canvas = document.createElement('canvas');
  canvas.width = 32;
  canvas.height = 32;
  const ctx = canvas.getContext('2d');

  const existingLink = document.querySelector('link[rel="icon"][sizes="32x32"]');

  window.addEventListener('server-status', (e) => {
    ctx.clearRect(0, 0, 32, 32);

    const img = new Image();
    img.onload = () => {
      ctx.drawImage(img, 0, 0, 32, 32);
      ctx.beginPath();
      ctx.arc(26, 26, 5, 0, Math.PI * 2);
      ctx.fillStyle = e.detail.online ? '#22c55e' : '#ef4444';
      ctx.fill();
      ctx.strokeStyle = '#0a0a0a';
      ctx.lineWidth = 2;
      ctx.stroke();

      if (existingLink) {
        existingLink.href = canvas.toDataURL('image/png');
      }
    };
    if (existingLink) img.src = existingLink.href.split('?')[0];
  });
}

function initTimeOfDay() {
  function apply() {
    const hour = new Date().getHours();
    document.body.classList.remove('time-dawn', 'time-day', 'time-dusk', 'time-night');

    if (hour >= 5 && hour < 8) document.body.classList.add('time-dawn');
    else if (hour >= 8 && hour < 17) document.body.classList.add('time-day');
    else if (hour >= 17 && hour < 20) document.body.classList.add('time-dusk');
    else document.body.classList.add('time-night');
  }

  apply();
  setInterval(apply, 60000);
}
