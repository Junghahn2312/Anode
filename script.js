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

  /* ---------- 3D Striped Sphere Particle Engine ---------- */
  // The dots THEMSELVES form the ball logo.
  // There is NO static image underneath. When the dots disperse, the ball disappears.
  // When you scroll to the bottom, the dots assemble to form the bottom ball logo.

  const cv = document.getElementById('dust');
  const ctx = cv.getContext('2d');
  const stage1 = document.getElementById('stage');
  const stage2 = document.getElementById('stage2');
  const mark = document.getElementById('mark');

  let W = 0, H = 0, DPR = 1, P = [];
  let ready = false, t0 = 0;
  let markOn = false;

  const maskImg = new Image();
  maskImg.src = 'logo-mask.png';
  const alphaImg = new Image();
  alphaImg.src = 'logo-alpha.png';

  // Smooth circular dot sprite for calm, high-precision antialiased rendering
  const makeDotSprite = size => {
    const c = document.createElement('canvas');
    c.width = size;
    c.height = size;
    const cx = c.getContext('2d');
    const r = size / 2;
    const grad = cx.createRadialGradient(r, r, 0, r, r, r);
    grad.addColorStop(0, 'rgba(255, 255, 255, 1)');
    grad.addColorStop(0.72, 'rgba(255, 255, 255, 0.95)');
    grad.addColorStop(1, 'rgba(255, 255, 255, 0)');
    cx.fillStyle = grad;
    cx.beginPath();
    cx.arc(r, r, r, 0, Math.PI * 2);
    cx.fill();
    return c;
  };
  const dotSprite = makeDotSprite(32);

  const N = () => innerWidth < 700 ? 96 : 116;

  /* Hover state on logo stages */
  let M = 0, Mt = 0;

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
    
    // Sample mask for lattice points
    o.drawImage(maskImg, 0, 0, n, n);
    const m = o.getImageData(0, 0, n, n).data;

    // Sample alpha for 3D luminance shading
    o.clearRect(0, 0, n, n);
    o.drawImage(alphaImg, 0, 0, n, n);
    const aData = o.getImageData(0, 0, n, n).data;

    P = [];
    for (let y = 0; y < n; y++) {
      for (let x = 0; x < n; x++) {
        const idx = (y * n + x) * 4;
        const inside = m[idx + 3] > 120;
        if (!inside) continue;

        // Normalized coordinate relative to sphere center (-0.5 to 0.5)
        const u = (x + 0.5) / n - 0.5;
        const v = (y + 0.5) / n - 0.5;

        // 3D brightness from alpha channel
        const lum = aData[idx + 3] / 255;

        // Calm, elegant dispersion angles and outward spread
        const ang = Math.random() * Math.PI * 2;
        const dist = 0.5 + Math.random() * 0.85;

        P.push({
          u,
          v,
          lum: Math.max(0.45, lum),
          sx: Math.cos(ang) * dist,
          sy: Math.sin(ang) * dist * 0.8,
          x: 0,
          y: 0,
          vx: 0,
          vy: 0,
          seed: Math.random() * 100,
          spin: (Math.random() - 0.5) * 0.8,
          phase: Math.random() * Math.PI * 2
        });
      }
    }

    // Initialize positions at top stage
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

    // Stage bounding boxes in current viewport
    const r1 = stage1.getBoundingClientRect();
    const r2 = stage2.getBoundingClientRect();

    const S1 = r1.width;
    const c1x = r1.left + S1 / 2;
    const c1y = r1.top + S1 / 2;

    const S2 = r2.width;
    const c2x = r2.left + S2 / 2;
    const c2y = r2.top + S2 / 2;

    // --- CONTINUOUS SCROLL-BASED DISPERSAL & ASSEMBLY ---
    // 1) Top assembly: 1 at scrollY=0 (dots form top ball), smoothly drops to 0 as you scroll down
    const topAssembly = smooth(clamp(1 - scrollY / 260, 0, 1));

    // 2) Bottom assembly: 0 until stage2 approaches viewport, smoothly rises to 1 as it centers
    const bottomAssembly = smooth(clamp((H * 0.86 - c2y) / (H * 0.42), 0, 1));

    // Dock mini mark in navbar when hero ball dissolves
    const shouldDock = topAssembly < 0.4;
    if (shouldDock !== markOn) {
      markOn = shouldDock;
      mark.classList.toggle('is-on', shouldDock);
    }

    // Hover state easing
    M += (Mt - M) * 0.06;
    const ME = smooth(M);

    // Dynamic Swarm Target Center
    const midX = W * 0.5;
    const midY = H * 0.5;

    let targetCx, targetCy, targetS, assembly;
    if (bottomAssembly > 0.01) {
      // Transitioning toward bottom stage or fully assembled at bottom
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

    // Dispersion factor: 0 when assembled at either stage, 1 when floating in mid-page
    const disp = 1 - assembly;
    const spreadX = targetS * 0.55 + W * 0.32;
    const spreadY = targetS * 0.55 + H * 0.28;

    ctx.clearRect(0, 0, W, H);

    // Calmer dot sizing: ~1.4px when assembled, ~1.8px when floating
    const baseRadius = Math.max(1.3, (targetS / N()) * 0.52);

    for (let i = 0; i < P.length; i++) {
      const p = P[i];

      // Exact assembled home coordinate inside the 3D striped sphere
      const hx = targetCx + p.u * targetS;
      const hy = targetCy + p.v * targetS;

      // Calm, organic floating drift when dispersed across viewport
      const driftX = Math.sin(t * 0.35 + p.seed) * 8 * disp;
      const driftY = Math.cos(t * 0.30 + p.seed * 1.2) * 8 * disp;
      const scx = targetCx + p.sx * spreadX + driftX;
      const scy = targetCy + p.sy * spreadY + driftY + t * p.spin * 3.5;

      // Target position blends smoothly between assembled sphere lattice and floating stardust
      const tx = hx * (1 - disp) + scx * disp;
      const ty = hy * (1 - disp) + scy * disp;

      // Smooth, calm spring physics
      const spring = 0.038 + 0.07 * assembly;
      p.vx = (p.vx + (tx - p.x) * spring) * 0.82;
      p.vy = (p.vy + (ty - p.y) * spring) * 0.82;

      // Calmer, gentle pointer interaction: soft repulsion without violent snapping
      const ddx = p.x - px;
      const ddy = p.y - py;
      const dd = ddx * ddx + ddy * ddy;
      const repelDist = 120;
      if (dd < repelDist * repelDist) {
        const d = Math.sqrt(dd) || 1;
        // Soft quadratic falloff for serene, fluid gliding
        const factor = Math.pow(1 - d / repelDist, 1.8) * 2.2 * (0.35 + 0.65 * disp);
        p.vx += (ddx / d) * factor;
        p.vy += (ddy / d) * factor;
      }

      p.x += p.vx;
      p.y += p.vy;

      if (p.x < -30 || p.x > W + 30 || p.y < -30 || p.y > H + 30) continue;

      // Calmer, soothing luminosity:
      // When assembled: steady 3D volume lighting (0.75-0.95 alpha), no harsh flickering
      // When dispersed: soft, ambient floating glow (0.50-0.70 alpha) with calm breathing
      let dotAlpha;
      if (assembly > 0.8) {
        // Assembled ball: 3D shaded by surface normal
        dotAlpha = p.lum * 0.88 + 0.12;
      } else {
        // Dispersed / transitioning: calm, soft stardust
        const calmPulse = 0.58 + 0.12 * Math.sin(t * 0.5 + p.phase);
        dotAlpha = lerp(calmPulse, p.lum * 0.88 + 0.12, assembly);
      }

      // Gentle hover static glow over the assembled ball
      if (ME > 0.01 && assembly > 0.7) {
        const R = targetS * 0.38;
        const dpx = p.x - px;
        const dpy = p.y - py;
        if (dpx * dpx + dpy * dpy < R * R) {
          dotAlpha = Math.min(1.0, dotAlpha + ME * 0.25);
        }
      }

      ctx.globalAlpha = clamp(dotAlpha, 0.05, 1.0);
      const rad = baseRadius * (assembly > 0.5 ? 1.0 : 1.15);
      ctx.drawImage(dotSprite, p.x - rad, p.y - rad, rad * 2, rad * 2);
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

  maskImg.onload = go;
  alphaImg.onload = go;
  addEventListener('resize', resize);
  resize();
  requestAnimationFrame(frame);
})();
