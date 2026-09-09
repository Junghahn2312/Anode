(() => {
  // Always start at top on page load/reload
  if ('scrollRestoration' in history) history.scrollRestoration = 'manual';
  scrollTo(0, 0);
  addEventListener('load', () => scrollTo(0, 0));
  addEventListener('pageshow', () => scrollTo(0, 0));

  const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const smooth = x => x * x * (3 - 2 * x);
  const lerp = (a, b, t) => a + (b - a) * t;

  /* Header scroll state */
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
  let px = -1e4, py = -1e4;

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

  /* ---------- 3D Striped Sphere Particle & Dispersion Engine ---------- */
  const cv = document.getElementById('dust');
  const ctx = cv.getContext('2d');
  const stage1 = document.getElementById('stage');
  const stage2 = document.getElementById('stage2');
  const mark = document.getElementById('mark');

  let W = 0, H = 0, DPR = 1, P = [];
  let ready = false, t0 = 0;
  let markOn = false;

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
    im.style.cssText = 'position:absolute;inset:0;width:100%;height:100%;display:block;will-change:opacity;';
    st.style.position = 'relative';
    st.appendChild(im);
    return {
      setOpacity: o => { im.style.opacity = o; }
    };
  };

  const L1 = plainLogo(stage1);
  const L2 = plainLogo(stage2);

  const N = () => innerWidth < 700 ? 100 : 128;

  /* Hover state on logo stages */
  let M = 0, Mt = 0, noiseOff = 0;

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
    o.drawImage(img, 0, 0, n, n);
    const d = o.getImageData(0, 0, n, n).data;
    o.clearRect(0, 0, n, n);
    o.drawImage(maskImg, 0, 0, n, n);
    const m = o.getImageData(0, 0, n, n).data;

    P = [];
    for (let y = 0; y < n; y++) {
      for (let x = 0; x < n; x++) {
        const idx = (y * n + x) * 4;
        const a = d[idx + 3] / 255;
        const inside = m[idx + 3] > 128;
        if (a < 0.05 && !inside) continue;
        const solid = inside || a > 0.45;
        
        // Scatter angles & radial distance for dispersion
        const ang = Math.random() * Math.PI * 2;
        const dist = 0.6 + Math.random() * 0.9;
        
        P.push({
          u: (x + 0.5) / n - 0.5,
          v: (y + 0.5) / n - 0.5,
          a,
          sx: Math.cos(ang) * dist,
          sy: Math.sin(ang) * dist * 0.85,
          x: 0,
          y: 0,
          vx: (Math.random() - 0.5) * 2,
          vy: (Math.random() - 0.5) * 2,
          n: Math.random(),
          solid,
          seed: Math.random() * 100,
          spin: (Math.random() - 0.5) * 1.5,
          twinkle: Math.random() * Math.PI * 2
        });
      }
    }

    // Initialize particle positions at stage 1
    const r1 = stage1.getBoundingClientRect();
    const S = r1.width || 320;
    const cx = r1.left + S / 2 || W / 2;
    const cy = r1.top + S / 2 || H * 0.35;
    P.forEach(p => {
      p.x = cx + p.u * S;
      p.y = cy + p.v * S;
    });
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

  const frame = now => {
    requestAnimationFrame(frame);
    if (!t0) t0 = now;
    const t = (now - t0) / 1000;
    if (!ready) return;

    if (cv.clientWidth * DPR !== cv.width || cv.clientHeight * DPR !== cv.height) {
      resize();
    }

    // Stages bounding boxes in current viewport
    const r1 = stage1.getBoundingClientRect();
    const r2 = stage2.getBoundingClientRect();

    const S1 = r1.width;
    const c1x = r1.left + S1 / 2;
    const c1y = r1.top + S1 / 2;

    const S2 = r2.width;
    const c2x = r2.left + S2 / 2;
    const c2y = r2.top + S2 / 2;

    // --- CONTINUOUS SCROLL PROGRESSION & DISPERSION LOGIC ---
    // 1) Top assembly factor: 1 at scrollY=0, dissolves to 0 as you scroll past hero
    const topAssembly = smooth(clamp(1 - scrollY / 240, 0, 1));
    const topImgA = smooth(clamp((topAssembly - 0.45) / 0.55, 0, 1));

    // 2) Bottom assembly factor: 0 in mid-page, rises to 1 as stage2 enters viewport center
    const bottomAssembly = smooth(clamp((H * 0.88 - c2y) / (H * 0.42), 0, 1));
    const bottomImgA = smooth(clamp((bottomAssembly - 0.55) / 0.45, 0, 1));

    // Crisp stage logos opacity
    L1.setOpacity(topImgA);
    L2.setOpacity(bottomImgA);

    // Dock mini mark in navbar once hero logo begins dissolving
    const shouldDock = topAssembly < 0.45;
    if (shouldDock !== markOn) {
      markOn = shouldDock;
      mark.classList.toggle('is-on', shouldDock);
    }

    // Hover quantum noise state
    M += (Mt - M) * 0.08;
    const ME = smooth(M);

    // Current primary stage / interpolation center
    // As you scroll down from hero, center gracefully transitions from stage1 to mid-screen, then to stage2
    const midY = H * 0.5;
    const midX = W * 0.5;

    let targetCx, targetCy, targetS, assembly;
    if (bottomAssembly > 0.01) {
      // Transitioning toward or at bottom stage
      assembly = bottomAssembly;
      const tMid = smooth(bottomAssembly);
      targetCx = lerp(midX, c2x, tMid);
      targetCy = lerp(midY, c2y, tMid);
      targetS = lerp(S1, S2, tMid);
    } else if (topAssembly > 0.01) {
      // Transitioning from top stage into dispersion
      assembly = topAssembly;
      const tMid = smooth(topAssembly);
      targetCx = lerp(midX, c1x, tMid);
      targetCy = lerp(midY, c1y, tMid);
      targetS = S1;
    } else {
      // Fully dispersed in mid-page viewport
      assembly = 0;
      targetCx = midX;
      targetCy = midY;
      targetS = S1;
    }

    // Dispersion factor: 0 when assembled at either stage, 1 when freely floating in mid-page
    const disp = 1 - assembly;
    const spreadX = targetS * 0.6 + W * 0.35;
    const spreadY = targetS * 0.6 + H * 0.32;

    ctx.clearRect(0, 0, W, H);

    // Noise offset for rolling refresh
    for (let i = 0, n = P.length; i < n; i += 3) {
      P[(i + noiseOff) % n].n = Math.random();
    }
    noiseOff = (noiseOff + 1) % 3;

    const baseSize = Math.max(1.3, (targetS / N()) * 1.05);

    for (let i = 0; i < P.length; i++) {
      const p = P[i];

      // Assembled home coordinate
      const hx = targetCx + p.u * targetS;
      const hy = targetCy + p.v * targetS;

      // Dispersed floating coordinate across viewport
      const wob = Math.sin(t * 0.85 + p.seed) * 14 * disp;
      const scx = targetCx + p.sx * spreadX + wob;
      const scy = targetCy + p.sy * spreadY + Math.cos(t * 0.75 + p.seed) * 14 * disp + t * p.spin * 6;

      // Target position blends seamlessly between home and dispersed
      const tx = hx * (1 - disp) + scx * disp;
      const ty = hy * (1 - disp) + scy * disp;

      // Spring physics toward target
      const spring = 0.045 + 0.075 * assembly;
      p.vx = (p.vx + (tx - p.x) * spring) * 0.78;
      p.vy = (p.vy + (ty - p.y) * spring) * 0.78;

      // Pointer avoidance: push floating grains away dynamically
      const ddx = p.x - px;
      const ddy = p.y - py;
      const dd = ddx * ddx + ddy * ddy;
      const repelDist = 135;
      if (dd < repelDist * repelDist) {
        const d = Math.sqrt(dd) || 1;
        const f = (1 - d / repelDist) * 3.4 * (0.4 + 0.6 * disp);
        p.vx += (ddx / d) * f;
        p.vy += (ddy / d) * f;
      }

      p.x += p.vx;
      p.y += p.vy;

      // Hover static noise when hovering assembled logo
      if (ME > 0.01 && assembly > 0.75) {
        const R = targetS * 0.42;
        const dpx = p.x - px;
        const dpy = p.y - py;
        const d2 = dpx * dpx + dpy * dpy;
        if (p.solid && d2 <= R * R) {
          const q = 1 - Math.sqrt(d2) / R;
          const str = q * q * ME;
          const g = Math.floor(p.n * p.n * 200 + 40);
          ctx.fillStyle = `rgb(${g},${g},${g})`;
          ctx.globalAlpha = str * 0.95;
          ctx.fillRect(p.x - baseSize / 2, p.y - baseSize / 2, baseSize, baseSize);
          continue;
        }
      }

      // Draw particle dot
      if (p.x < -30 || p.x > W + 30 || p.y < -30 || p.y > H + 30) continue;

      // Alpha calculations:
      // When dispersed in mid-page: bright and crisp (0.75-0.95 alpha)
      // When assembled: blends with the solid image
      const activeImgA = Math.max(topImgA, bottomImgA);
      const dotAlpha = (1 - activeImgA * 0.9) * (0.68 + 0.32 * Math.sin(t * 1.6 + p.twinkle));

      if (dotAlpha < 0.02) continue;

      ctx.fillStyle = '#ffffff';
      ctx.globalAlpha = dotAlpha;
      const s = baseSize * (0.8 + 0.25 * disp);
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
})();
