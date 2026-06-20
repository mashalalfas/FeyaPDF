/* =====================================================================
   Freya PDF — The Apprentice's Desk
   Main entry: Lenis smooth scroll, GSAP ScrollTrigger page turns,
   all interactions, easter eggs, search palette, zoom, etc.
   Upgraded: scroll-pinned section transitions, drag-to-draw ink mode,
   multi-stage discard, touch swipe nav, vibration, real-looking QR.
   ===================================================================== */

import './style.css';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import Lenis from 'lenis';
import { DeskScene } from './scene.js';

gsap.registerPlugin(ScrollTrigger);

const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
const isTouch = 'ontouchstart' in window || navigator.maxTouchPoints > 0;

/* ---------------- Helpers ---------------- */
const $  = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => Array.from(r.querySelectorAll(s));

/* ---------------- Loader hide ---------------- */
const loader = $('#loader');
const hideLoader = () => {
  if (!loader) return;
  loader.classList.add('is-hidden');
  setTimeout(() => loader.remove(), 700);
};

/* =====================================================================
   Desk scene (Three.js)
   ===================================================================== */
let scene = null;
const canvas = $('#scene');
if (canvas) {
  try {
    scene = new DeskScene(canvas);
    window.__deskScene = scene; // for debugging
  } catch (err) {
    console.error('DeskScene init failed:', err);
  }
}

/* =====================================================================
   Lenis smooth scroll
   ===================================================================== */
let lenis = null;
if (!reducedMotion) {
  lenis = new Lenis({
    duration: 1.2,
    easing: (t) => Math.min(1, 1.001 - Math.pow(2, -10 * t)),
    smoothWheel: true,
    smoothTouch: false,
    touchMultiplier: 2,
  });

  lenis.on('scroll', ScrollTrigger.update);

  gsap.ticker.add((time) => {
    lenis.raf(time * 1000);
  });
  gsap.ticker.lagSmoothing(0);
} else {
  ScrollTrigger.refresh();
}

/* =====================================================================
   Page-turn ScrollTrigger — reveal each section's contents
   ===================================================================== */
const sections = $$('.page');
const pageCurrent = $('#page-current');
let currentPageIndex = 0;

function setPageIndicator(idx) {
  if (!pageCurrent) return;
  const num = String(idx + 1).padStart(2, '0');
  if (pageCurrent.textContent !== num) pageCurrent.textContent = num;
}

sections.forEach((section, i) => {
  const revealTargets = section.querySelectorAll(
    '.eyebrow, .section-title, .lede, .body-text, .feature-list, ' +
    '.ink-palette, .mark-doc, .flipbook, .discard-stage, .e2e-grid, ' +
    '.wax-seal, .download-card, .desk-overlay, .margin-note, ' +
    '.ember, .ember-hint, .footer, .e2e-step'
  );

  if (revealTargets.length) {
    gsap.set(revealTargets, { opacity: 0, y: 30 });
    if (i === 0) {
      const revealFirstPage = () => {
        gsap.to(revealTargets, {
          opacity: 1, y: 0,
          duration: 0.9,
          ease: 'power3.out',
          stagger: 0.06,
          overwrite: 'auto',
        });
      };
      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => setTimeout(revealFirstPage, 100));
      } else {
        setTimeout(revealFirstPage, 100);
      }
    }
  }

  ScrollTrigger.create({
    trigger: section,
    start: 'top 80%',
    end: 'bottom 20%',
    onEnter: () => {
      currentPageIndex = i;
      setPageIndicator(i);
      gsap.to(revealTargets, {
        opacity: 1, y: 0,
        duration: 0.9,
        ease: 'power3.out',
        stagger: 0.05,
        overwrite: 'auto',
      });
    },
    onEnterBack: () => {
      currentPageIndex = i;
      setPageIndicator(i);
      gsap.to(revealTargets, {
        opacity: 1, y: 0,
        duration: 0.6,
        ease: 'power3.out',
        stagger: 0.03,
        overwrite: 'auto',
      });
    },
  });
});

/* =====================================================================
   Section-specific animations
   ===================================================================== */

/* Page 1 — Desk */
const deskSection = $('.page--desk');
if (deskSection) {
  const titleLines = deskSection.querySelectorAll('.title__line');
  if (titleLines.length && !reducedMotion) {
    gsap.fromTo(
      titleLines,
      { yPercent: 110, opacity: 0 },
      {
        yPercent: 0, opacity: 1,
        duration: 1.1, stagger: 0.12,
        ease: 'power3.out', delay: 0.3,
      }
    );
  }

  const marginNotes = deskSection.querySelectorAll('.margin-note');
  if (marginNotes.length && !reducedMotion) {
    gsap.fromTo(
      marginNotes,
      { opacity: 0, y: 10 },
      {
        opacity: 1, y: 0,
        duration: 0.8,
        ease: 'power2.out',
        delay: 1.4,
        stagger: 0.2,
      }
    );
  }

  // Hide hint when user starts scrolling
  const scrollHint = deskSection.querySelector('.scroll-hint');
  if (scrollHint) {
    ScrollTrigger.create({
      trigger: deskSection,
      start: 'top top',
      end: '+=200',
      onUpdate: (self) => {
        gsap.to(scrollHint, { opacity: 1 - self.progress * 1.6, duration: 0.2 });
      },
    });
  }

  // Feed scroll progress to the scene
  ScrollTrigger.create({
    trigger: deskSection,
    start: 'top top',
    end: 'bottom top',
    scrub: true,
    onUpdate: (self) => {
      if (scene) scene.setScrollProgress(self.progress);
    },
  });
}

/* Page 2 — Open: flipbook + lines */
const flipbook = $('#flipbook');
if (flipbook && !reducedMotion) {
  ScrollTrigger.create({
    trigger: flipbook,
    start: 'top 70%',
    onEnter: () => flipbook.classList.add('is-flipped'),
    onLeaveBack: () => flipbook.classList.remove('is-flipped'),
  });

  const frontLines = $$('.flipbook__page--front .flipbook__lines span', flipbook);
  gsap.fromTo(
    frontLines,
    { scaleX: 0, transformOrigin: 'left center' },
    {
      scaleX: 1,
      duration: 0.6, stagger: 0.05,
      ease: 'power2.out',
      scrollTrigger: {
        trigger: flipbook,
        start: 'top 80%',
        toggleActions: 'play none none reverse',
      },
    }
  );

  // Feature-list dots pop in
  const dots = $$('.feature-list .dot');
  dots.forEach((d, i) => {
    ScrollTrigger.create({
      trigger: d,
      start: 'top 85%',
      onEnter: () => gsap.fromTo(d, { scale: 0 }, { scale: 1, duration: 0.5, ease: 'back.out(4)' }),
    });
  });
}

/* Page 3 — Mark: ink-draw path + interactive freehand mode */
const inkPath = document.querySelector('.ink-path');
if (inkPath && !reducedMotion) {
  gsap.to(inkPath, {
    strokeDashoffset: 0,
    duration: 2.4,
    ease: 'power2.inOut',
    scrollTrigger: {
      trigger: inkPath,
      start: 'top 80%',
      toggleActions: 'play none none reverse',
    },
  });
}

// Freehand ink mode: click the brush icon to draw your own path
const freehandBtn = $('#freehand-toggle');
const freehandCanvas = $('#freehand-canvas');
if (freehandBtn && freehandCanvas) {
  const fhCtx = freehandCanvas.getContext('2d');
  // Size canvas to its container
  const sizeCanvas = () => {
    const r = freehandCanvas.getBoundingClientRect();
    freehandCanvas.width  = r.width  * (window.devicePixelRatio || 1);
    freehandCanvas.height = r.height * (window.devicePixelRatio || 1);
    fhCtx.scale(window.devicePixelRatio || 1, window.devicePixelRatio || 1);
    fhCtx.lineCap = 'round';
    fhCtx.lineJoin = 'round';
    fhCtx.lineWidth = 3;
    fhCtx.strokeStyle = '#B85C38';
  };
  sizeCanvas();
  window.addEventListener('resize', sizeCanvas);

  let drawing = false;
  let lastPt = null;

  const getPos = (e) => {
    const r = freehandCanvas.getBoundingClientRect();
    const t = e.touches ? e.touches[0] : e;
    return { x: t.clientX - r.left, y: t.clientY - r.top };
  };
  const start = (e) => {
    e.preventDefault();
    drawing = true;
    lastPt = getPos(e);
    fhCtx.beginPath();
    fhCtx.moveTo(lastPt.x, lastPt.y);
  };
  const move = (e) => {
    if (!drawing) return;
    e.preventDefault();
    const p = getPos(e);
    fhCtx.lineTo(p.x, p.y);
    fhCtx.stroke();
    lastPt = p;
  };
  const end = () => { drawing = false; };

  freehandBtn.addEventListener('click', () => {
    const isActive = freehandCanvas.classList.toggle('is-active');
    freehandBtn.classList.toggle('is-on', isActive);
    if (isActive) {
      fhCtx.clearRect(0, 0, freehandCanvas.width, freehandCanvas.height);
    }
    vibrate(8);
  });

  freehandCanvas.addEventListener('mousedown', start);
  freehandCanvas.addEventListener('mousemove', move);
  window.addEventListener('mouseup', end);
  freehandCanvas.addEventListener('touchstart', start, { passive: false });
  freehandCanvas.addEventListener('touchmove', move, { passive: false });
  window.addEventListener('touchend', end);
}

const inkPalette = $('#ink-palette');
const markDoc = $('#mark-doc');
let currentInk = localStorage.getItem('freya:ink') || '#C4A962';

function applyInkToHighlights(color) {
  if (!markDoc) return;
  markDoc.style.setProperty('--hl', color);
  $$('.hl', markDoc).forEach((el) => el.style.setProperty('--hl', color));
}

if (inkPalette) {
  const inks = $$('.ink', inkPalette);
  inks.forEach((btn) => {
    const c = btn.dataset.ink;
    btn.setAttribute('aria-pressed', String(c === currentInk));
  });
  applyInkToHighlights(currentInk);

  inks.forEach((btn) => {
    btn.addEventListener('click', () => {
      currentInk = btn.dataset.ink;
      localStorage.setItem('freya:ink', currentInk);
      inks.forEach((b) => b.setAttribute('aria-pressed', String(b === btn)));
      applyInkToHighlights(currentInk);
      gsap.fromTo(btn, { scale: 1.2 }, { scale: 1, duration: 0.4, ease: 'back.out(3)' });
      vibrate(6);
    });
  });
}

/* Page 4 — Discard: multi-stage effect */
const eraseBtn = $('#erase-btn');
const scribble = $('#discard-scribble');
const discardStage = $('#discard-stage');
const discardText = $('.discard-text', discardStage);

function burstDust(originX, originY, count = 55, opts = {}) {
  if (!discardStage) return;
  const rect = discardStage.getBoundingClientRect();
  const cx = originX - rect.left;
  const cy = originY - rect.top;
  const colors = opts.colors || ['var(--ink-3)', 'var(--rust)', 'var(--accent-2)', 'var(--primary)'];
  for (let i = 0; i < count; i++) {
    const dust = document.createElement('span');
    dust.className = 'dust';
    dust.style.left = `${cx}px`;
    dust.style.top  = `${cy}px`;
    const size = 3 + Math.random() * 9;
    dust.style.width  = `${size}px`;
    dust.style.height = `${size}px`;
    dust.style.background = colors[Math.floor(Math.random() * colors.length)];
    // Some dust is rectangular (paper flecks)
    if (Math.random() > 0.7) {
      dust.style.borderRadius = '1px';
      dust.style.width  = `${size * 0.4}px`;
      dust.style.height = `${size * 0.15}px`;
    }
    discardStage.appendChild(dust);

    const angle = Math.random() * Math.PI * 2;
    const dist = 100 + Math.random() * 300;
    const dx = Math.cos(angle) * dist;
    const dy = Math.sin(angle) * dist - 60; // bias upward
    const rot = (Math.random() - 0.5) * 1200;
    const dur = 0.9 + Math.random() * 1.0;
    gsap.to(dust, {
      x: dx, y: dy, rotation: rot,
      opacity: 0,
      duration: dur,
      ease: 'power2.out',
      onComplete: () => dust.remove(),
    });
  }
}

if (eraseBtn) {
  eraseBtn.addEventListener('click', (e) => {
    vibrate(15);

    // Stage 1: shake the stage
    gsap.fromTo(
      discardStage,
      { x: 0, y: 0 },
      { x: 4, y: -2, duration: 0.05, yoyo: true, repeat: 5, ease: 'power2.inOut' }
    );

    // Stage 2: scribble cracks then crumbles
    if (scribble) {
      gsap.timeline()
        .to(scribble, { rotation: 6, scale: 1.05, duration: 0.15, ease: 'power2.out' })
        .to(scribble, { rotation: -10, scale: 0.95, duration: 0.12, ease: 'power2.in' })
        .to(scribble, { opacity: 0, scale: 0.4, rotation: 20, y: -20, duration: 0.5, ease: 'back.in(2)' }, '+=0.05')
        .add(() => scribble.classList.add('is-erased'));
    }

    // Stage 3: dust burst from the scribble position (above the button is more natural)
    const r = eraseBtn.getBoundingClientRect();
    burstDust(
      r.left + r.width * (0.2 + Math.random() * 0.6),
      r.top - 60,
      80,
      { colors: ['var(--ink-3)', 'var(--rust)', 'var(--accent-2)', 'var(--primary)'] }
    );

    // Stage 4: subtle paper rustle (the discard text)
    if (discardText) {
      gsap.fromTo(
        discardText,
        { x: -2 },
        { x: 0, duration: 0.4, ease: 'elastic.out(1, 0.4)' }
      );
    }

    // Stage 5: change button text
    eraseBtn.querySelector('span:last-child').textContent = 'Erased';
    eraseBtn.disabled = true;
    gsap.to(eraseBtn, { opacity: 0.6, duration: 0.3 });
  });
}

/* Page 5 — Wax seal stamp */
const waxSeal = $('#wax-seal');
if (waxSeal) {
  waxSeal.addEventListener('click', () => {
    vibrate(20);
    waxSeal.classList.remove('is-stamped');
    void waxSeal.offsetWidth; // restart animation
    waxSeal.classList.add('is-stamped');
    const r = waxSeal.getBoundingClientRect();
    burstDust(
      r.left + r.width / 2,
      r.top + r.height / 2,
      32,
      { colors: ['var(--rust)', 'var(--rust)', 'var(--accent-2)', 'var(--ink-3)'] }
    );
    // Secondary stamp pop effect
    gsap.fromTo(waxSeal,
      { scale: 1.2, opacity: 0.5 },
      { scale: 1, opacity: 1, duration: 0.5, ease: 'back.out(2)', delay: 0.6 }
    );
  });
}

/* Page 7 — Ember relight */
const ember = $('#ember');
if (ember) {
  ember.addEventListener('click', () => {
    vibrate(25);
    ember.classList.add('is-lit');
    if (scene) scene.relightLamp();
    const r = ember.getBoundingClientRect();
    burstDust(
      r.left + r.width / 2,
      r.top + r.height / 2,
      40,
      { colors: ['var(--accent)', 'var(--rust)', 'var(--accent-2)'] }
    );
  });
}

/* =====================================================================
   Page 1: hero text parallax
   ===================================================================== */
const heroOverlay = $('.desk-overlay');
if (heroOverlay && !reducedMotion) {
  window.addEventListener('mousemove', (e) => {
    const nx = (e.clientX / window.innerWidth - 0.5);
    const ny = (e.clientY / window.innerHeight - 0.5);
    gsap.to(heroOverlay, {
      x: nx * 8,
      y: ny * 4,
      duration: 1.2,
      ease: 'power3.out',
    });
  }, { passive: true });
}

/* =====================================================================
   Ghost cursor trail
   ===================================================================== */
const trailContainer = $('#cursor-trail');
const TRAIL_MAX = 12;
const trail = [];
if (trailContainer && !isTouch) {
  for (let i = 0; i < TRAIL_MAX; i++) {
    const dot = document.createElement('span');
    dot.className = 'cursor-trail__dot';
    dot.style.opacity = '0';
    trailContainer.appendChild(dot);
    trail.push({ el: dot, x: 0, y: 0 });
  }

  let lastSpawn = 0;
  window.addEventListener('mousemove', (e) => {
    const now = performance.now();
    if (now - lastSpawn < 32) return;
    lastSpawn = now;
    for (let i = trail.length - 1; i > 0; i--) {
      trail[i].x = trail[i - 1].x;
      trail[i].y = trail[i - 1].y;
    }
    trail[0].x = e.clientX;
    trail[0].y = e.clientY;
    trail.forEach((t, i) => {
      const k = i / trail.length;
      t.el.style.left = `${t.x}px`;
      t.el.style.top  = `${t.y}px`;
      t.el.style.opacity = String(0.6 * (1 - k));
      t.el.style.transform = `translate(-50%, -50%) scale(${1 - k * 0.7})`;
    });
  }, { passive: true });
}

/* =====================================================================
   Double-click highlight (localStorage persisted)
   ===================================================================== */
const HL_KEY = 'freya:highlights';
const loadHighlights = () => { try { return JSON.parse(localStorage.getItem(HL_KEY) || '{}'); } catch { return {}; } };
const saveHighlights = (m)  => { try { localStorage.setItem(HL_KEY, JSON.stringify(m)); } catch {} };
const applyHighlights = () => {
  const map = loadHighlights();
  $$('[data-hl]').forEach((el) => {
    if (map[el.dataset.hl]) el.classList.add('hl-user');
  });
};
applyHighlights();
$$('[data-hl]').forEach((el) => {
  el.addEventListener('dblclick', () => {
    const map = loadHighlights();
    const key = el.dataset.hl;
    if (map[key]) {
      delete map[key];
      el.classList.remove('hl-user');
    } else {
      map[key] = { color: currentInk, t: Date.now() };
      el.classList.add('hl-user');
    }
    saveHighlights(map);
    vibrate(4);
  });
});

/* =====================================================================
   Mode toggle (paper / dark)
   ===================================================================== */
const modeBtn = $('#mode-toggle');
const modeIcon = modeBtn?.querySelector('.mode-icon');
function setMode(mode) {
  document.documentElement.setAttribute('data-mode', mode);
  localStorage.setItem('freya:mode', mode);
  if (modeIcon) modeIcon.textContent = mode === 'dark' ? '☀' : '☾';
  if (scene) scene.setMode(mode);
}
const savedMode = localStorage.getItem('freya:mode') || 'paper';
setMode(savedMode);
if (modeBtn) {
  modeBtn.addEventListener('click', () => {
    const cur = document.documentElement.getAttribute('data-mode');
    setMode(cur === 'dark' ? 'paper' : 'dark');
    vibrate(6);
  });
}

/* =====================================================================
   Zoom controls
   ===================================================================== */
const ZOOM_STEPS = [50, 75, 100, 125, 150, 175, 200];
let zoomIdx = 2;
const zoomLabel = $('#zoom-level');
function applyZoom() {
  const level = ZOOM_STEPS[zoomIdx];
  document.body.classList.remove('zoom-50','zoom-75','zoom-100','zoom-125','zoom-150','zoom-175','zoom-200');
  document.body.classList.add(`zoom-${level}`);
  if (zoomLabel) zoomLabel.textContent = `${level}%`;
}
applyZoom();
$('#zoom-in')?.addEventListener('click', () => {
  if (zoomIdx < ZOOM_STEPS.length - 1) { zoomIdx++; applyZoom(); vibrate(4); }
});
$('#zoom-out')?.addEventListener('click', () => {
  if (zoomIdx > 0) { zoomIdx--; applyZoom(); vibrate(4); }
});

/* =====================================================================
   Touch swipe navigation (mobile)
   ===================================================================== */
let touchStartY = null;
if (isTouch) {
  window.addEventListener('touchstart', (e) => {
    if (e.touches.length === 1) touchStartY = e.touches[0].clientY;
  }, { passive: true });
  window.addEventListener('touchend', (e) => {
    if (touchStartY === null) return;
    const t = e.changedTouches[0];
    const dy = touchStartY - t.clientY;
    touchStartY = null;
    if (Math.abs(dy) < 60) return;
    const dir = dy > 0 ? 1 : -1;
    const next = Math.max(0, Math.min(sections.length - 1, currentPageIndex + dir));
    if (next === currentPageIndex) return;
    const target = sections[next];
    if (target) {
      const top = target.getBoundingClientRect().top + window.scrollY;
      if (lenis) lenis.scrollTo(top, { duration: 1.2 });
      else window.scrollTo({ top, behavior: 'smooth' });
      vibrate(10);
    }
  }, { passive: true });
}

/* =====================================================================
   Search palette
   ===================================================================== */
const palette = $('#search-palette');
const paletteInput = $('#palette-input');
const paletteResults = $('#palette-results');
const PALETTE_ITEMS = [
  { title: 'The Desk', page: '01', section: '.page--desk' },
  { title: 'Open', page: '02', section: '.page--open' },
  { title: 'Mark', page: '03', section: '.page--mark' },
  { title: 'Discard', page: '04', section: '.page--discard' },
  { title: 'Share', page: '05', section: '.page--share' },
  { title: 'Download', page: '06', section: '.page--download' },
  { title: 'Ember', page: '07', section: '.page--ember' },
  { title: 'Highlight (Mark section)', page: '03', section: '.page--mark' },
  { title: 'Erase (Discard section)', page: '04', section: '.page--discard' },
  { title: 'Wax seal (Share section)', page: '05', section: '.page--share' },
  { title: 'Relight lamp (Ember)', page: '07', section: '.page--ember', action: 'relight' },
  { title: 'Keyboard shortcuts', action: 'shortcuts' },
  { title: 'Toggle dark mode', action: 'dark' },
];

let paletteOpen = false;
let paletteIndex = 0;
let paletteFiltered = [];

function openPalette() {
  if (!palette) return;
  palette.hidden = false;
  paletteOpen = true;
  paletteInput.value = '';
  paletteIndex = 0;
  renderPalette('');
  setTimeout(() => paletteInput.focus(), 50);
}
function closePalette() {
  if (!palette) return;
  palette.hidden = true;
  paletteOpen = false;
}
function renderPalette(query) {
  const q = query.trim().toLowerCase();
  paletteFiltered = PALETTE_ITEMS.filter((it) =>
    !q || it.title.toLowerCase().includes(q) || it.page?.includes(q)
  );
  paletteResults.innerHTML = '';
  if (!paletteFiltered.length) {
    const li = document.createElement('li');
    li.className = 'is-empty';
    li.textContent = 'no matches — try "highlight" or "share"';
    paletteResults.appendChild(li);
    return;
  }
  paletteFiltered.forEach((it, i) => {
    const li = document.createElement('li');
    li.setAttribute('role', 'option');
    li.dataset.idx = String(i);
    if (i === paletteIndex) li.setAttribute('aria-selected', 'true');
    const title = document.createElement('span');
    title.innerHTML = highlightMatch(it.title, q);
    li.appendChild(title);
    if (it.page) {
      const badge = document.createElement('span');
      badge.className = 'badge';
      badge.textContent = `page ${it.page}`;
      li.appendChild(badge);
    }
    li.addEventListener('click', () => activatePaletteItem(it));
    paletteResults.appendChild(li);
  });
}
function highlightMatch(text, q) {
  if (!q) return text;
  const idx = text.toLowerCase().indexOf(q);
  if (idx < 0) return text;
  return `${escapeHTML(text.slice(0, idx))}<mark>${escapeHTML(text.slice(idx, idx + q.length))}</mark>${escapeHTML(text.slice(idx + q.length))}`;
}
function escapeHTML(s) {
  return s.replace(/[&<>"']/g, (c) => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
}
function activatePaletteItem(item) {
  closePalette();
  if (item.action === 'shortcuts') {
    $('#shortcuts')?.showModal();
    return;
  }
  if (item.action === 'relight') {
    setTimeout(() => $('#ember')?.click(), 600);
  }
  if (item.action === 'dark') {
    const cur = document.documentElement.getAttribute('data-mode');
    setMode(cur === 'dark' ? 'paper' : 'dark');
  }
  if (item.section) {
    const el = $(item.section);
    if (el) {
      const top = el.getBoundingClientRect().top + window.scrollY;
      if (lenis) lenis.scrollTo(top, { duration: 1.4 });
      else window.scrollTo({ top, behavior: 'smooth' });
    }
  }
}

/* =====================================================================
   Easter eggs
   ===================================================================== */

/* Konami code → crayon mode */
const KONAMI = ['ArrowUp','ArrowUp','ArrowDown','ArrowDown','ArrowLeft','ArrowRight','ArrowLeft','ArrowRight','b','a'];
let konamiIdx = 0;
function checkKonami(e) {
  if (e.key === KONAMI[konamiIdx]) {
    konamiIdx++;
    if (konamiIdx === KONAMI.length) {
      konamiIdx = 0;
      triggerCrayonMode();
    }
  } else {
    konamiIdx = 0;
  }
}
const crayonBanner = $('#crayon-banner');
function triggerCrayonMode() {
  document.body.classList.add('crayon-mode');
  if (crayonBanner) {
    crayonBanner.hidden = false;
    setTimeout(() => { crayonBanner.hidden = true; }, 2200);
  }
  for (let i = 0; i < 42; i++) {
    const c = document.createElement('span');
    c.className = 'dust';
    c.style.left = `${Math.random() * window.innerWidth}px`;
    c.style.top = `-10px`;
    c.style.background = ['#C4A962','#B85C38','#2A5B5C','#7D8B6F','#E8B4BC'][i % 5];
    c.style.position = 'fixed';
    c.style.zIndex = '300';
    document.body.appendChild(c);
    gsap.to(c, {
      y: window.innerHeight + 40,
      x: (Math.random() - 0.5) * 200,
      rotation: (Math.random() - 0.5) * 720,
      duration: 1.6 + Math.random() * 1.2,
      ease: 'power2.in',
      onComplete: () => c.remove(),
    });
  }
}

/* Type "freya" → runic flash */
let freyaBuf = '';
const runicFlash = $('#runic-flash');
function checkFreya(e) {
  if (e.key.length === 1 && /^[a-zA-Z]$/.test(e.key)) {
    freyaBuf = (freyaBuf + e.key.toLowerCase()).slice(-5);
    if (freyaBuf === 'freya') {
      freyaBuf = '';
      triggerRunicFlash();
    }
  } else if (e.key === 'Escape') {
    freyaBuf = '';
  }
}
function triggerRunicFlash() {
  if (!runicFlash) return;
  runicFlash.innerHTML = '<span class="runic-flash__glyph">ᚠᚱᛖᛋᚨ</span>';
  runicFlash.classList.add('is-active');
  setTimeout(() => runicFlash.classList.remove('is-active'), 1200);
  setTimeout(() => { runicFlash.innerHTML = ''; }, 1600);
}

/* Ctrl+Shift+R → Ragnarök shake */
function checkRagnarok(e) {
  if (e.ctrlKey && e.shiftKey && (e.key === 'R' || e.key === 'r')) {
    e.preventDefault();
    document.body.classList.remove('ragnarok');
    void document.body.offsetWidth;
    document.body.classList.add('ragnarok');
    setTimeout(() => document.body.classList.remove('ragnarok'), 900);
  }
}

/* Easter egg: click the "Freya" h1 five times → invoke "freya" rune */
let titleClicks = 0;
let titleClickTimer = null;
const titleEl = $('.title');
if (titleEl) {
  titleEl.addEventListener('click', () => {
    titleClicks++;
    clearTimeout(titleClickTimer);
    titleClickTimer = setTimeout(() => { titleClicks = 0; }, 2000);
    if (titleClicks >= 5) {
      titleClicks = 0;
      triggerRunicFlash();
    }
  });
}

/* =====================================================================
   Vibration helper (mobile)
   ===================================================================== */
function vibrate(ms) {
  if (navigator.vibrate) {
    try { navigator.vibrate(ms); } catch {}
  }
}

/* =====================================================================
   Keyboard shortcuts
   ===================================================================== */
window.addEventListener('keydown', (e) => {
  const target = e.target;
  const isFormField = target instanceof HTMLInputElement || target instanceof HTMLTextAreaElement;

  if (e.key === '/' && !paletteOpen && !isFormField) {
    e.preventDefault();
    openPalette();
    return;
  }
  if (paletteOpen) {
    if (e.key === 'Escape') { closePalette(); return; }
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      paletteIndex = Math.min(paletteFiltered.length - 1, paletteIndex + 1);
      renderPalette(paletteInput.value);
      return;
    }
    if (e.key === 'ArrowUp') {
      e.preventDefault();
      paletteIndex = Math.max(0, paletteIndex - 1);
      renderPalette(paletteInput.value);
      return;
    }
    if (e.key === 'Enter') {
      e.preventDefault();
      if (paletteFiltered[paletteIndex]) activatePaletteItem(paletteFiltered[paletteIndex]);
      return;
    }
  }

  if (!isFormField && (e.key === 'j' || e.key === 'k')) {
    const dir = e.key === 'j' ? 1 : -1;
    const next = Math.max(0, Math.min(sections.length - 1, currentPageIndex + dir));
    const target = sections[next];
    if (target) {
      const top = target.getBoundingClientRect().top + window.scrollY;
      if (lenis) lenis.scrollTo(top, { duration: 1.2 });
      else window.scrollTo({ top, behavior: 'smooth' });
    }
  }

  if ((e.key === '+' || e.key === '=') && !isFormField) {
    e.preventDefault();
    if (zoomIdx < ZOOM_STEPS.length - 1) { zoomIdx++; applyZoom(); }
  }
  if (e.key === '-' && !isFormField) {
    e.preventDefault();
    if (zoomIdx > 0) { zoomIdx--; applyZoom(); }
  }

  if (e.key === 'p' && !isFormField) {
    e.preventDefault();
    window.print();
  }

  if (e.key === 'd' && !isFormField) {
    e.preventDefault();
    const cur = document.documentElement.getAttribute('data-mode');
    setMode(cur === 'dark' ? 'paper' : 'dark');
  }

  checkKonami(e);
  checkFreya(e);
  checkRagnarok(e);
});

if (paletteInput) {
  paletteInput.addEventListener('input', (e) => {
    paletteIndex = 0;
    renderPalette(e.target.value);
  });
}

$$('[data-palette-close]').forEach((el) => el.addEventListener('click', closePalette));
$$('[data-shortcut]').forEach((el) => el.addEventListener('click', (e) => {
  e.preventDefault();
  $('#shortcuts')?.showModal();
}));

/* =====================================================================
   Real-looking QR code (25x25 with proper finder patterns + alignment)
   ===================================================================== */
const qrGrid = $('#qr-grid');
if (qrGrid) {
  const SIZE = 25;
  const seed = (i, j) => {
    // Hash function for deterministic pseudo-random
    const h = ((i * 73 + j * 137 + 11) * 31) % 100;
    return h < 48;
  };

  // Helper: build a finder pattern (7x7 with 3x3 center) at (x, y) of the grid
  const isFinder = (x, y) => {
    if ((x < 7 && y < 7) || (x >= SIZE - 7 && y < 7) || (x < 7 && y >= SIZE - 7)) return true;
    return false;
  };
  const isFinderFill = (x, y) => {
    // 3 finder squares
    const inSquare = (sx, sy) => {
      const dx = x - sx, dy = y - sy;
      if (dx < 0 || dx >= 7 || dy < 0 || dy >= 7) return null;
      // outer ring (border) and inner 3x3 fill
      const border = dx === 0 || dx === 6 || dy === 0 || dy === 6;
      const inner  = dx >= 2 && dx <= 4 && dy >= 2 && dy <= 4;
      const gap    = !border && !inner;
      return border || inner;
    };
    if (x < 7 && y < 7) return inSquare(0, 0);
    if (x >= SIZE - 7 && y < 7) return inSquare(SIZE - 7, 0);
    if (x < 7 && y >= SIZE - 7) return inSquare(0, SIZE - 7);
    return null;
  };
  // Alignment marker at (16, 16) — 5x5
  const isAlignment = (x, y) => {
    if (x < SIZE - 9 || x > SIZE - 5 || y < SIZE - 9 || y > SIZE - 5) return false;
    const dx = x - (SIZE - 7);
    const dy = y - (SIZE - 7);
    const border = dx === 0 || dx === 4 || dy === 0 || dy === 4;
    const center = dx === 2 && dy === 2;
    return border || center;
  };
  // Timing patterns: alternating cells on row 6 and col 6
  const isTiming = (x, y) => {
    if (x === 6 && y >= 8 && y < SIZE - 8) return y % 2 === 0;
    if (y === 6 && x >= 8 && x < SIZE - 8) return x % 2 === 0;
    return false;
  };

  for (let i = 0; i < SIZE * SIZE; i++) {
    const x = i % SIZE;
    const y = Math.floor(i / SIZE);
    const cell = document.createElement('span');
    let filled = false;
    const ff = isFinderFill(x, y);
    if (ff !== null) {
      filled = ff;
    } else if (isAlignment(x, y)) {
      filled = true;
    } else if (isTiming(x, y)) {
      filled = true;
    } else {
      filled = seed(x, y);
    }
    cell.className = filled ? 'qr__cell' : 'qr__cell qr__cell--off';
    qrGrid.appendChild(cell);
  }
  // Set grid template dynamically
  qrGrid.style.gridTemplateColumns = `repeat(${SIZE}, 1fr)`;
  qrGrid.style.gridTemplateRows    = `repeat(${SIZE}, 1fr)`;
}

/* =====================================================================
   Initial reveal of loader + ScrollTrigger refresh after fonts load
   ===================================================================== */
window.addEventListener('load', () => {
  setTimeout(() => {
    hideLoader();
    ScrollTrigger.refresh();
    if (lenis) lenis.scrollTo(0, { immediate: true });
  }, 700);
});

if (document.fonts && document.fonts.ready) {
  document.fonts.ready.then(() => ScrollTrigger.refresh());
}

let resizeTO;
window.addEventListener('resize', () => {
  clearTimeout(resizeTO);
  resizeTO = setTimeout(() => ScrollTrigger.refresh(), 150);
});
