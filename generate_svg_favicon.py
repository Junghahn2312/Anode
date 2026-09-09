import numpy as np

# Generate a clean vector SVG for the 3D striped sphere
# Viewbox: 0 0 100 100, Center: 50, 50, Radius: 44
R = 44.0
cx = 50.0
cy = 50.0
D = 2.7

bands_def = [
    (-0.085, 0.085),   # equator band
    (0.205, 0.360),    # mid band 1 (+Y)
    (-0.360, -0.205),  # mid band 1 (-Y)
    (0.485, 0.630),    # high band 2 (+Y)
    (-0.630, -0.485),  # high band 2 (-Y)
    (0.745, 1.200),    # bottom cap (+Y)
    (-1.200, -0.745)   # top cap (-Y)
]

# For each band, we compute the path in SVG:
# At any y_3d, the curve across x in [-x_max, x_max] is:
# y_proj(x) = y_3d / (1 - sqrt(R^2 - x^2 - y^2)/D)
# We can sample points along the top and bottom curves of each band to form closed SVG paths.

paths = []
for y0, y1 in bands_def:
    # We trace top curve from -x_max to +x_max for y0, then bottom curve from +x_max to -x_max for y1
    # To find x_max for a given y_3d:
    # At limb, z=0, y_proj = y_3d * R. So x_max = sqrt(R^2 - (y_3d * R)^2)
    def get_curve(y_val, num_pts=30, reverse=False):
        y_scaled = np.clip(y_val, -0.999, 0.999)
        # solve y_3d = (y / R) * (1 - z / D)
        # Along curve, y varies slightly with x:
        # At x, z = sqrt(R^2 - x^2 - y^2).
        # We can find y for each x using Newton or small step:
        # Since D is large, y approx = y_scaled * R / (1 - sqrt(R^2 - x^2 - (y_scaled*R)^2)/(D*R))
        x_max = R * np.sqrt(max(0.001, 1.0 - y_scaled**2))
        xs = np.linspace(-x_max, x_max, num_pts)
        if reverse:
            xs = xs[::-1]
        pts = []
        for x in xs:
            # find y
            y_est = y_scaled * R
            for _ in range(3):
                z = np.sqrt(max(0.0, R**2 - x**2 - y_est**2))
                y_est = y_scaled * R / (1.0 - z / (D * R))
            pts.append((cx + x, cy + y_est))
        return pts

    pts_top = get_curve(y0, num_pts=32)
    pts_bot = get_curve(y1, num_pts=32, reverse=True)
    all_pts = pts_top + pts_bot
    d_str = "M " + " L ".join([f"{p[0]:.2f},{p[1]:.2f}" for p in all_pts]) + " Z"
    paths.append(d_str)

svg_content = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100%" height="100%">
  <defs>
    <radialGradient id="sphereGrad" cx="35%" cy="30%" r="65%">
      <stop offset="0%" stop-color="#ffffff" />
      <stop offset="70%" stop-color="#eeeeee" />
      <stop offset="100%" stop-color="#cccccc" />
    </radialGradient>
    <clipPath id="sphereClip">
      <circle cx="50" cy="50" r="44" />
    </clipPath>
  </defs>
  <!-- Dark backing circle for gaps so stripes are visible on light browser tabs -->
  <circle cx="50" cy="50" r="44" fill="#0d0e11" />
  <g clip-path="url(#sphereClip)" fill="url(#sphereGrad)">
'''
for p in paths:
    svg_content += f'    <path d="{p}" />\n'
svg_content += '''  </g>
</svg>'''

with open("favicon.svg", "w") as f:
    f.write(svg_content)

print("Generated favicon.svg successfully!")
