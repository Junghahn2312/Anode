(() => {
  // Always start at top, even on reload
  if ('scrollRestoration' in history) history.scrollRestoration = 'manual';
  scrollTo(0, 0);
  addEventListener('load', () => scrollTo(0, 0));
  addEventListener('pageshow', () => scrollTo(0, 0));

  const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const smooth = x => x * x * (3 - 2 * x);
  const lerp = (a, b, t) => a + (b - a) * t;

  /* Header state */
  const topNav = document.querySelector('.top');
  addEventListener('scroll', () => {
    topNav.classList.toggle('is-scrolled', scrollY > 40);
  }, { passive: true });

  /* Decode text animation: headings scramble through glyphs and settle left -> right */
  const GLYPHS = '▓▒░█▌▐│┃0123456789ABCDEFXK#%&*+';
  const decode = (el, ms = 800) => {
    if (reduced) return;
    const text = el.dataset.text || el.textContent;
    const t0 = performance.now();
    const tick = now => {
      const p = Math.min(1, (now - t0) / ms);
      const settled = Math.floor(p * text.length);
      let out = '';
      for (let i = 0; i < text.length; i++) {
        out += (i < settled || text[i] === ' ')
          ? text[i]
          : `<span class="g">${GLYPHS[Math.floor(Math.random() * GLYPHS.length)]}</span>`;
      }
      el.innerHTML = out;
      if (p < 1) requestAnimationFrame(tick);
      else el.textContent = text;
    };
    requestAnimationFrame(tick);
  };

  /* Cursor light + pointer state */
  const light = document.querySelector('.light');
  let px = -1e4, py = -1e4, lx = innerWidth / 2, ly = innerHeight / 2;

  addEventListener('pointermove', e => {
    if (e.pointerType !== 'mouse') return;
    px = e.clientX;
    py = e.clientY;
    document.body.classList.add('has-pointer');
    if (light) {
      light.style.transform = `translate(${px}px, ${py}px)`;
    }
  }, { passive: true });

  addEventListener('pointerleave', () => {
    px = py = -1e4;
    document.body.classList.remove('has-pointer');
  });

  addEventListener('pointercancel', () => {
    px = py = -1e4;
    document.body.classList.remove('has-pointer');
  });

  /* IntersectionObserver for section reveals */
  const io = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (!entry.isIntersecting) return;
      entry.target.classList.add('is-in');
      entry.target.querySelectorAll('.decode:not(.is-done)').forEach(d => {
        d.classList.add('is-done');
        decode(d);
      });
    });
  }, { threshold: 0.15 });

  document.querySelectorAll('.hero, .sec').forEach(s => io.observe(s));

  /* ---------- Interactive Logo & Particle Engine (Odin Logic + Anode Custom Shape) ---------- */
  const cv = document.getElementById('dust');
  const ctx = cv.getContext('2d');
  const stage1 = document.getElementById('stage');
  const stage2 = document.getElementById('stage2');
  const mark = document.getElementById('mark');

  let W = 0, H = 0, DPR = 1, P = [];
  let ready = false, t0 = 0, sY = 0;
  let markOn = false;

  const mouse = { x: -1e4, y: -1e4 };
  const img = new Image();
  img.src = 'logo-alpha.png';
  const maskImg = new Image();
  maskImg.src = 'logo-mask.png';

  const plainLogo = st => {
    const im = new Image();
    im.src = 'logo-alpha.png';
    im.alt = 'Anode';
    im.width = 1254;
    im.height = 1254;
    im.style.cssText = 'position:absolute;inset:0;width:100%;height:100%;display:block;will-change:opacity;pointer-events:none;';
    st.style.position = 'relative';
    st.appendChild(im);
    return {
      setOpacity: o => { im.style.opacity = o; }
    };
  };

  const L1 = plainLogo(stage1);
  const L2 = plainLogo(stage2);

  const N = () => innerWidth < 700 ? 96 : 128;

  /* Hover state: the logo reacts with dynamic static noise and breathing */
  let M = 0, Mt = 0, noiseOff = 0, prevTop = true, fade = 1, lastL = 0, lastT = 0;

  [stage1, stage2].forEach(st => {
    st.addEventListener('pointerenter', e => {
      if (e.pointerType === 'mouse') {
        Mt = 1;
        st.classList.add('is-live');
      }
    });
    st.addEventListener('pointerleave', () => {
      Mt = 0;
      st.classList.remove('is-live');
    });
    st.addEventListener('pointercancel', () => {
      Mt = 0;
      st.classList.remove('is-live');
    });
    st.addEventListener('pointerup', e => {
      if (e.pointerType !== 'mouse') {
        Mt = 0;
        st.classList.remove('is-live');
      }
    });
  });

  const sample = () => {
    const n = N();
    const off = document.createElement('canvas');
    off.width = n;
    off.height = n;
    const o = off.getContext('2d', { willReadFrequently: true });

    // Read alpha channel for shape luminance
    o.drawImage(img, 0, 0, n, n);
    const d = o.getImageData(0, 0, n, n).data;

    // Read mask channel for solid bands
    o.clearRect(0, 0, n, n);
    o.drawImage(maskImg, 0, 0, n, n);
    const m = o.getImageData(0, 0, n, n).data;

    P = [];
    for (let y = 0; y < n; y++) {
      for (let x = 0; x < n; x++) {
        const a = d[(y * n + x) * 4 + 3] / 255;
        const inside = m[(y * n + x) * 4 + 3] > 120;
        if (a < 0.05 && !inside) continue;

        const solid = inside || a > 0.45;
        const ang = Math.random() * Math.PI * 2;
        const dist = 0.5 + Math.random() * 0.9;

        P.push({
          u: (x + 0.5) / n - 0.5,
          v: (y + 0.5) / n - 0.5,
          a,
          sx: Math.cos(ang) * dist,
          sy: Math.sin(ang) * dist * 0.7 - 0.25,
          x: 0,
          y: 0,
          vx: 0,
          vy: 0,
          n: Math.random(),
          solid,
          fall: Math.pow(Math.random(), 1.4),
          seed: Math.random() * 100,
          spin: Math.random() - 0.5,
          oa: Math.random() * Math.PI * 2,
          or: 0.25 + Math.pow(Math.random(), 1.6) * 1.1,
          os: (0.4 + Math.random() * 0.8) * (Math.random() < 0.5 ? 1 : -1)
        });
      }
    }

    P.forEach(p => {
      p.x = W / 2 + p.sx * W * 1.3;
      p.y = H * 0.4 + p.sy * H * 1.3;
    });

    const r0 = (prevTop ? stage1 : stage2).getBoundingClientRect();
    lastL = r0.left;
    lastT = r0.top;
  };

  const resize = () => {
    const w = cv.clientWidth || document.documentElement.clientWidth;
    const h = cv.clientHeight || innerHeight;
    const dpr = Math.min(devicePixelRatio || 1, 2);
    const relayout = w !== W || dpr !== DPR;

    W = w;
    H = h;
    DPR = dpr;
    cv.width = W * DPR;
    cv.height = H * DPR;
    ctx.setTransform(DPR, 0, 0, DPR, 0, 0);

    if (ready && relayout) sample();
  };

  addEventListener('pointermove', e => {
    mouse.x = e.clientX;
    mouse.y = e.clientY;
  }, { passive: true });

  addEventListener('pointerleave', () => {
    mouse.x = mouse.y = -1e4;
  });

  addEventListener('touchend', () => {
    mouse.x = mouse.y = -1e4;
  }, { passive: true });

  const frame = now => {
    requestAnimationFrame(frame);
    if (!t0) t0 = now;
    const t = (now - t0) / 1000;
    if (!ready) return;

    const intro = reduced ? 1 : smooth(clamp((t - 0.15) / 1.9, 0, 1));
    sY = lerp(sY, scrollY, 0.12);

    if (cv.clientWidth * DPR !== cv.width || cv.clientHeight * DPR !== cv.height) {
      resize();
    }

    lx += (px - lx) * 0.08;
    ly += (py - ly) * 0.08;

    // Stages: actual rects for crisp image, smoothed rects for dust
    const r1 = stage1.getBoundingClientRect();
    const r2 = stage2.getBoundingClientRect();
    const lag = scrollY - sY;
    const c1 = r1.top + r1.height / 2 + lag;
    const c2 = r2.top + r2.height / 2 + lag;

    const a1 = 1 - Math.pow(clamp(scrollY / 300, 0, 1), 1.15);
    const a2 = smooth(clamp((H * 1.2 - c2) / (H * 0.42), 0, 1));
    const useTop = c1 > -r1.height * 0.5 && a1 > 0.001 && (a1 >= a2 || c2 > H);
    const rect = useTop ? r1 : r2;

    if (useTop === prevTop) {
      const dx = rect.left - lastL;
      const dy = rect.top - lastT;
      if (dx || dy) {
        for (let i = 0; i < P.length; i++) {
          P[i].x += dx;
          P[i].y += dy;
        }
      }
    }
    lastL = rect.left;
    lastT = rect.top;

    if (useTop !== prevTop) {
      prevTop = useTop;
      fade = 0;
      const S2 = rect.width;
      const cx2 = rect.left + S2 / 2;
      const cy2 = rect.top + S2 / 2;
      const sp2 = S2 * 1.3 + W * 0.3;
      for (let i = 0; i < P.length; i++) {
        const p = P[i];
        p.x = cx2 + p.u * S2 + p.sx * sp2;
        p.y = cy2 + p.v * S2 + p.sy * sp2;
        p.vx = p.vy = 0;
      }
    }

    fade = Math.min(1, fade + 0.03);
    const A0 = (useTop ? a1 : a2) * intro;
    const A = A0;
    const AE = smooth(A);
    const S = rect.width;
    const cx = rect.left + S / 2;
    const cyImg = rect.top + S / 2;

    M += (Mt - M) * 0.07;
    const ME = smooth(M);
    const imgA = smooth(clamp((A - 0.86) / 0.14, 0, 1));
    const partA = 1 - imgA;

    // Rolling refresh: update noise on 1/3 of the grains per frame
    for (let i = 0, n = P.length; i < n; i += 3) {
      P[(i + noiseOff) % n].n = Math.random();
    }
    noiseOff = (noiseOff + 1) % 3;

    ctx.clearRect(0, 0, W, H);

    // 1) The crisp solid logo in stage: cross-fade with scroll
    L1.setOpacity(useTop ? imgA : 0);
    L2.setOpacity(useTop ? 0 : imgA);

    // Mini-mark in navbar
    const dock = !useTop || a1 < 0.35;
    if (dock !== markOn) {
      markOn = dock;
      mark.classList.toggle('is-on', dock);
    }

    // 2) Dust simulation & Interactive hover
    ctx.fillStyle = '#fff';
    const size = Math.max(1.2, (S / N()) * 0.95);
    const L = Math.pow(clamp((0.97 - AE) / 0.97, 0, 1), 1.3);
    const cyHome = cyImg;
    const spread = S * 0.55 + W * 0.22;

    for (let i = 0; i < P.length; i++) {
      const p = P[i];
      const hx = cx + p.u * S;
      const hy = cyHome + p.v * S;

      const wob = Math.sin(t * 0.8 + p.seed) * 6 * L;
      const scx = hx + p.sx * spread + wob;
      const scy = hy + p.sy * spread + t * p.spin * 10 + wob;
      const tx = hx * (1 - L) + scx * L;
      const ty = hy * (1 - L) + scy * L;

      const k = 0.05 + 0.06 * AE;
      p.vx = (p.vx + (tx - p.x) * k) * 0.76;
      p.vy = (p.vy + (ty - p.y) * k) * 0.76;

      // Pointer interaction: gently repel floating dust particles
      const ddx = p.x - px;
      const ddy = p.y - py;
      const dd = ddx * ddx + ddy * ddy;
      if (ME < 0.01 && dd < 120 * 120 && AE < 0.98) {
        const d = Math.sqrt(dd) || 1;
        const f = (1 - d / 120) * 2.6 * (1 - AE * 0.6);
        p.vx += (ddx / d) * f;
        p.vy += (ddy / d) * f;
      }

      p.x += p.vx;
      p.y += p.vy;

      // Interactive hover on logo: creates dynamic static noise patch under the cursor
      if (ME > 0.01 && imgA > 0.5) {
        const R = S * 0.36;
        const dpx = p.x - px;
        const dpy = p.y - py;
        const d2 = dpx * dpx + dpy * dpy;
        if (!p.solid || d2 > R * R) continue;

        const q = 1 - Math.sqrt(d2) / R;
        const str = q * q * ME;
        const g = Math.floor(p.n * p.n * 190 + 20);
        ctx.fillStyle = `rgb(${g},${g},${g})`;
        ctx.globalAlpha = str * 0.95;
        ctx.fillRect(p.x - size / 2, p.y - size / 2, size, size);
        continue;
      }

      // Dispersed dust particles
      const vis = partA;
      if (vis < 0.02) continue;
      if (p.y < -20 || p.y > H + 20 || p.x < -20 || p.x > W + 20) continue;

      const tw = 0.85 + 0.15 * p.n;
      ctx.fillStyle = '#fff';
      const a = p.a + (p.solid ? 0.16 : 0) * L;
      ctx.globalAlpha = a * vis * (0.55 + 0.45 * AE) * (0.3 + 0.7 * intro) * tw * smooth(fade);
      const s = size * (0.75 + 0.25 * AE);
      ctx.fillRect(p.x - s / 2, p.y - s / 2, s, s);
    }
    ctx.globalAlpha = 1;
  };

  let loaded = 0;
  const go = () => {
    if (++loaded < 2) return;
    resize();
    sample();
    ready = true;
  };

  img.onload = go;
  maskImg.onload = go;
  addEventListener('resize', resize);
  resize();
  requestAnimationFrame(frame);

  /* Dynamic favicon refresher: ensures URL bar / tab icon immediately updates */
  try {
    const existing = document.querySelector('link[rel="icon"][type="image/svg+xml"]');
    if (existing) {
      existing.href = 'favicon.svg?v=' + Date.now();
    }
  } catch (_) {}
})();
