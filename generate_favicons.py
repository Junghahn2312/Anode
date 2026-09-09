import os
import sys
import numpy as np
from PIL import Image, ImageFilter

def make_favicons(output_dir="."):
    size = 512
    y, x = np.ogrid[:size, :size]
    cx = (size - 1) / 2.0
    cy = (size - 1) / 2.0
    
    # Radius of sphere (fits comfortably in square icon with 5% margin)
    R = size * 0.44
    dx = (x - cx)
    dy = (y - cy)
    r = np.sqrt(dx**2 + dy**2)
    r2 = (dx**2 + dy**2) / (R**2)
    inside_sphere = r2 <= 1.0
    
    z = np.where(inside_sphere, np.sqrt(np.maximum(0.0, 1.0 - r2)), 0.0)
    D = 2.7
    y_3d = np.where(inside_sphere, (dy / R) * (1.0 - z / D), 0.0)
    
    bands_def = [
        (-0.085, 0.085),   # equator band
        (0.205, 0.360),    # mid band 1 (+Y)
        (-0.360, -0.205),  # mid band 1 (-Y)
        (0.485, 0.630),    # high band 2 (+Y)
        (-0.630, -0.485),  # high band 2 (-Y)
        (0.745, 1.200),    # bottom cap (+Y)
        (-1.200, -0.745)   # top cap (-Y)
    ]
    
    d_list = []
    for y0, y1 in bands_def:
        center = (y0 + y1) / 2.0
        half_w = (y1 - y0) / 2.0
        d_list.append(np.abs(y_3d - center) - half_w)
        
    d_bands = np.minimum.reduce(d_list)
    dist_bands_px = d_bands * R
    dist_sphere_px = r - R
    dist_comb_px = np.maximum(dist_sphere_px, dist_bands_px)
    
    # 3D Normal Vector for lighting:
    nx = np.where(inside_sphere, dx / R, 0.0)
    ny = np.where(inside_sphere, dy / R, 0.0)
    nz = z
    
    lx = -0.50; ly = -0.60; lz = 0.62
    l_len = np.sqrt(lx**2 + ly**2 + lz**2)
    lx /= l_len; ly /= l_len; lz /= l_len
    diffuse = np.clip(nx * lx + ny * ly + nz * lz, 0.0, 1.0)
    
    edge_dist = np.clip(-dist_comb_px, 0.0, 10.0)
    bevel = np.clip(edge_dist / 4.0, 0.0, 1.0)
    
    band_lum = (0.78 + 0.22 * diffuse) * (0.88 + 0.12 * bevel)
    aa_band = np.clip(-dist_comb_px * 0.75 + 0.5, 0.0, 1.0)
    aa_sphere = np.clip(-dist_sphere_px * 0.75 + 0.5, 0.0, 1.0)
    
    # RGB values:
    # Inside white bands: pure bright white with 3D shading
    # Inside black gaps: solid deep charcoal/black (#0c0c0c)
    # Outside sphere: transparent (alpha = 0)
    
    rgb = np.zeros((size, size, 3), dtype=np.float32)
    # White band color:
    for c in range(3):
        rgb[:, :, c] = np.where(inside_sphere, 12.0 + (255.0 * band_lum - 12.0) * aa_band, 0.0)
        
    # Alpha:
    # 255 inside sphere, smoothly antialiased to 0 at sphere edge
    alpha = aa_sphere * 255.0
    
    rgba = np.zeros((size, size, 4), dtype=np.uint8)
    rgba[:, :, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    rgba[:, :, 3] = np.clip(alpha, 0, 255).astype(np.uint8)
    
    master_icon = Image.fromarray(rgba)
    
    # 1. icon-32.png (32x32 transparent)
    icon32 = master_icon.resize((32, 32), Image.Resampling.LANCZOS)
    icon32.save(os.path.join(output_dir, "icon-32.png"))
    
    # 2. icon-64.png (64x64 transparent)
    icon64 = master_icon.resize((64, 64), Image.Resampling.LANCZOS)
    icon64.save(os.path.join(output_dir, "icon-64.png"))
    
    # 3. icon-192.png (192x192 transparent/PWA)
    icon192 = master_icon.resize((192, 192), Image.Resampling.LANCZOS)
    icon192.save(os.path.join(output_dir, "icon-192.png"))
    
    # 4. icon-180.png (Apple touch icon: solid black background)
    apple_bg = Image.new("RGBA", (size, size), (0, 0, 0, 255))
    apple_bg.paste(master_icon, (0, 0), master_icon)
    icon180 = apple_bg.resize((180, 180), Image.Resampling.LANCZOS)
    icon180.save(os.path.join(output_dir, "icon-180.png"))
    
    # 5. favicon.ico (multi-size: 16, 32, 48, 64)
    ico16 = master_icon.resize((16, 16), Image.Resampling.LANCZOS)
    ico32 = master_icon.resize((32, 32), Image.Resampling.LANCZOS)
    ico48 = master_icon.resize((48, 48), Image.Resampling.LANCZOS)
    ico32.save(
        os.path.join(output_dir, "favicon.ico"),
        format="ICO",
        sizes=[(16, 16), (32, 32), (48, 48)]
    )
    print("Favicons generated successfully!")

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    make_favicons(out)
