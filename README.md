# Anode

A minimalist, high-performance website inspired by the design, typography, particle physics simulation, and aesthetic of [odinapp.dev](https://odinapp.dev).

---

## Features

- **Interactive Canvas Dust Simulation (`#dust`)**:
  - Thousands of interactive particles sampled from the geometric Anode logo mask.
  - Dissolves seamlessly into drifting kinetic dust as the user scrolls down from the hero.
  - Reassembles into the Anode logo as the user scrolls to the bottom call-to-action stage.
  - Elastic mouse repulsion physics pushes grains aside dynamically.
  - Localized CRT / quantum static noise when hovering directly over the logo.
- **Minimalist Geist Typography & Aesthetic**:
  - Pitch black `#000000` background with crisp white typography and opacity hierarchies.
  - Glassmorphic navigation header with backdrop blur on scroll.
  - Docking mini mark (`#mark`) that expands, scales, and fades into the navbar as the hero logo begins dissolving.
  - Cryptographic text decipher / scrambler effect (`▓▒░█▌▐│┃...`) on scroll into view.
  - Section title keyframe flickers and card hover focus dimming.
  - Ambient radial cursor spotlight (`.light`).

---

## Free Hosting & Domain Deployment Options

### Option 1: Cloudflare Pages (Recommended - 100% Free Forever)
Cloudflare Pages offers unlimited bandwidth, global edge distribution, automatic SSL, and provides a free `.dev` URL (`anode.pages.dev`).

#### Method A: Git Integration (Zero CLI)
1. Push this folder to a GitHub repository:
   ```bash
   cd /Volumes/NetworkSSD/Anode
   git init
   git add .
   git commit -m "Initial commit of Anode website"
   git remote add origin https://github.com/<your-username>/anode.git
   git push -u origin main
   ```
2. Go to [dash.cloudflare.com](https://dash.cloudflare.com/) → **Workers & Pages** → **Create application** → **Pages** → **Connect to Git**.
3. Select your `anode` repository.
4. Leave build command blank (this is a static site), set build output directory to `/` (or root).
5. Click **Save and Deploy**. Your site is instantly live globally at `https://anode.pages.dev`!

#### Method B: Direct Deploy via Wrangler CLI
```bash
npx wrangler pages deploy . --project-name=anode
```

---

### Option 2: Free `is-a.dev` Custom Subdomain
If you want a developer domain with a `.dev` extension without paying registry fees:
1. Deploy your site to Cloudflare Pages or GitHub Pages.
2. Visit [is-a.dev](https://www.is-a.dev/).
3. Fork their GitHub repository and add an `anode.json` record pointing a CNAME to `anode.pages.dev`.
4. Once merged, your site is available globally at `https://anode.is-a.dev`!

---

### Option 3: GitHub Pages (100% Free)
1. Create a public repository named `anode` on GitHub.
2. Push your code to GitHub.
3. In repository settings, navigate to **Pages** → **Build and deployment** → Source: **Deploy from a branch** → select `main` branch → `/ (root)`.
4. Your site will be published at `https://<username>.github.io/anode`.

---

### Option 4: Custom Top-Level `.dev` Domain (~$10/year)
If you would like an apex domain like `anode.dev`:
1. Register `anode.dev` at cost-price on [Cloudflare Registrar](https://www.cloudflare.com/products/registrar/) or [Porkbun](https://porkbun.com/) (~$10/yr).
2. In Cloudflare Pages, go to **Custom domains** → **Set up a custom domain** → enter `anode.dev`.
3. Cloudflare automatically generates free SSL certificates and routes traffic globally.

---

## Local Development & Testing

To preview the website locally on any device on your local network:

```bash
# Using Python
python3 -m http.server 8080

# Or using Node
npx serve .
```

Open `http://localhost:8080` in your browser.
