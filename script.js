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

  /* ---------- Solid Logo Images + Particle Dispersion Engine ---------- */
  const cv = document.getElementById('dust');
  const ctx = cv.getContext('2d');
  const stage1 = document.getElementById('stage');
  const stage2 = document.getElementById('stage2');
  const mark = document.getElementById('mark');

  let W = 0, H = 0, DPR = 1, P = [];
  let ready = false, t0 = 0;
  let markOn = false;

  // Render solid logos inside the stages
  const createSolidLogo = st => {
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

  const L1 = createSolidLogo(stage1);
  const L2 = createSolidLogo(stage2);

  const maskImg = new Image();
  maskImg.src = 'logo-mask.png';
  const alphaImg = new Image();
  alphaImg.src = 'logo-alpha.png';

  // Soft circular antialiased dot sprite
  const makeDotSprite = size => {
    const c = document.createElement('canvas');
    c.width = size;
    c.height = size;
    const cx = c.getContext('2d');
    const r = size / 2;
    const grad = cx.createRadialGradient(r, r, 0, r, r, r);
    grad.addColorStop(0, 'rgba(255, 255, 255, 1)');
    grad.addColorStop(0.65, 'rgba(255, 255, 255, 0.85)');
    grad.addColorStop(1, 'rgba(255, 255, 255, 0)');
    cx.fillStyle = grad;
    cx.beginPath();
    cx.arc(r, r, r, 0, Math.PI * 2);
    cx.fill();
    return c;
  };
  const dotSprite = makeDotSprite(32);

  const N = () => innerWidth < 700 ? 90 : 110;

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
    
    // Sample mask for points inside bands
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

        // Normalized coordinate inside the sphere (-0.5 to 0.5)
        const u = (x + 0.5) / n - 0.5;
        const v = (y + 0.5) / n - 0.5;

        // 3D brightness
        const lum = aData[idx + 3] / 255;

        P.push({
          u,
          v,
          lum: Math.max(0.5, lum),
          x: 0,
          y: 0,
          vx: 0,
          vy: 0,
          seed: Math.random() * 100,
          phase: Math.random() * Math.PI * 2
        });
      }
    }

    // Assign every particle an EVEN target across the screen
    // Low-discrepancy 2D grid covering [0.03*W, 0.97*W] and [0.03*H, 0.97*H]
    const count = P.length;
    const aspect = (W || innerWidth) / (H || innerHeight);
    const cols = Math.ceil(Math.sqrt(count * aspect));
    const rows = Math.ceil(count / cols);

    // Shuffle indices slightly so adjacent sphere points disperse across different areas
    const indices = Array.from({ length: count }, (_, i) => i);
    for (let i = count - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [indices[i], indices[j]] = [indices[j], indices[i]];
    }

    for (let i = 0; i < count; i++) {
      const pIdx = indices[i];
      const col = i % cols;
      const row = Math.floor(i / cols);
      // Normalized grid positions evenly across the viewport
      P[pIdx].gx = 0.03 + 0.94 * ((col + 0.5) / cols);
      P[pIdx].gy = 0.03 + 0.94 * ((row + 0.5) / rows);
      // Subtle organic jitter
      P[pIdx].jx = (Math.random() - 0.5) * (1.0 / cols) * 0.7;
      P[pIdx].jy = (Math.random() - 0.5) * (1.0 / rows) * 0.7;
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

    const r1 = stage1.getBoundingClientRect();
    const r2 = stage2.getBoundingClientRect();

    const S1 = r1.width;
    const c1x = r1.left + S1 / 2;
    const c1y = r1.top + S1 / 2;

    const S2 = r2.width;
    const c2x = r2.left + S2 / 2;
    const c2y = r2.top + S2 / 2;

    // --- TRANSITION LOGIC ---
    // At scrollY == 0: Solid logo is 100% visible (no dots).
    // The moment scrolling begins (0 -> 70px): Solid logo cross-fades into individual dots, which disperse evenly.
    const topSolidOpacity = smooth(clamp(1 - scrollY / 65, 0, 1));
    const topDotReveal = smooth(clamp(scrollY / 35, 0, 1));

    // Top dispersion factor: 0 at top, ramps to 1 as you scroll past hero
    const topAssembly = smooth(clamp(1 - scrollY / 240, 0, 1));

    // Bottom assembly factor: 0 in mid-page, rises to 1 as stage2 centers in viewport
    const bottomAssembly = smooth(clamp((H * 0.88 - c2y) / (H * 0.42), 0, 1));
    const bottomSolidOpacity = smooth(clamp((bottomAssembly - 0.78) / 0.22, 0, 1));

    // Update solid logo elements opacity
    L1.setOpacity(topSolidOpacity);
    L2.setOpacity(bottomSolidOpacity);

    // Mini mark in navbar
    const shouldDock = topSolidOpacity < 0.2;
    if (shouldDock !== markOn) {
      markOn = shouldDock;
      mark.classList.toggle('is-on', shouldDock);
    }

    // Swarm target assembly & center
    let assembly, targetCx, targetCy, targetS;
    if (bottomAssembly > 0.01) {
      assembly = bottomAssembly;
      targetCx = c2x;
      targetCy = c2y;
      targetS = S2;
    } else {
      assembly = topAssembly;
      targetCx = c1x;
      targetCy = c1y;
      targetS = S1;
    }

    // Dispersion factor: 0 when assembled at either stage, 1 when freely floating in mid-page
    const disp = 1 - assembly;

    ctx.clearRect(0, 0, W, H);

    // If completely at top and solid logo is 100% visible, skip drawing dots
    if (topSolidOpacity >= 0.999 && scrollY === 0) {
      return;
    }

    // Dot sizing: delicate stardust points (~1.1px radius on high-DPR)
    const baseRadius = Math.max(1.1, (targetS / N()) * 0.46);

    for (let i = 0; i < P.length; i++) {
      const p = P[i];

      // Assembled slot in the 3D striped sphere
      const hx = targetCx + p.u * targetS;
      const hy = targetCy + p.v * targetS;

      // Evenly distributed screen position across the viewport
      const driftX = Math.sin(t * 0.25 + p.seed) * 6 * disp;
      const driftY = Math.cos(t * 0.20 + p.seed * 1.3) * 6 * disp;
      const sx = (p.gx + p.jx) * W + driftX;
      const sy = (p.gy + p.jy) * H + driftY;

      // Smoothly blend between assembled sphere and even screen distribution
      const tx = hx * (1 - disp) + sx * disp;
      const ty = hy * (1 - disp) + sy * disp;

      // Calm spring dynamics
      const spring = 0.04 + 0.06 * assembly;
      p.vx = (p.vx + (tx - p.x) * spring) * 0.84;
      p.vy = (p.vy + (ty - p.y) * spring) * 0.84;

      // Gentle, serene mouse interaction (parts the dots softly like zero-g air)
      const ddx = p.x - px;
      const ddy = p.y - py;
      const dd = ddx * ddx + ddy * ddy;
      const repelDist = 110;
      if (dd < repelDist * repelDist) {
        const d = Math.sqrt(dd) || 1;
        const factor = Math.pow(1 - d / repelDist, 2.0) * 1.6 * (0.3 + 0.7 * disp);
        p.vx += (ddx / d) * factor;
        p.vy += (ddy / d) * factor;
      }

      p.x += p.vx;
      p.y += p.vy;

      if (p.x < -20 || p.x > W + 20 || p.y < -20 || p.y > H + 20) continue;

      // Light, calm dot opacity:
      // When dispersed: soft, airy, serene stardust (~0.32 - 0.44 alpha)
      // When assembling at bottom: blends with solid bottom logo
      let alpha;
      if (assembly > 0.8) {
        // Assembling at bottom: 3D normal shading, fades as solid logo takes over
        alpha = (p.lum * 0.85 + 0.15) * (1 - bottomSolidOpacity * 0.95);
      } else {
        // Dispersed in mid-page: calm, light, weightless breathing
        const calmBreath = 0.35 + 0.08 * Math.sin(t * 0.4 + p.phase);
        alpha = calmBreath * topDotReveal;
      }

      if (alpha < 0.02) continue;

      ctx.globalAlpha = clamp(alpha, 0.02, 0.9);
      const rad = baseRadius;
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
