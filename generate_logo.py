import os
import sys
import numpy as np
from PIL import Image, ImageFilter

def generate_anode_sphere_logo(output_dir=".", size=1254):
    os.makedirs(output_dir, exist_ok=True)
    
    y, x = np.ogrid[:size, :size]
    cx = (size - 1) / 2.0
    cy = (size - 1) / 2.0
    
    R = size * 0.40
    dx = (x - cx)
    dy = (y - cy)
    r = np.sqrt(dx**2 + dy**2)
    r2 = (dx**2 + dy**2) / (R**2)
    inside_sphere = r2 <= 1.0
    
    z = np.where(inside_sphere, np.sqrt(np.maximum(0.0, 1.0 - r2)), 0.0)
    
    # Perspective latitude curvature matching user image
    D = 2.7
    y_3d = np.where(inside_sphere, (dy / R) * (1.0 - z / D), 0.0)
    
    # 7 luminous bands and 6 open transparent gaps
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
    
    # Strict Antialiased Binary Mask for particles
    mask_alpha = np.clip(0.5 - dist_comb_px * 0.75, 0.0, 1.0) * 255.0
    mask_img = np.zeros((size, size, 4), dtype=np.uint8)
    mask_img[:, :, 0] = 255
    mask_img[:, :, 1] = 255
    mask_img[:, :, 2] = 255
    mask_img[:, :, 3] = mask_alpha.astype(np.uint8)
    
    # 3D Normal Vector for lighting:
    nx = np.where(inside_sphere, dx / R, 0.0)
    ny = np.where(inside_sphere, dy / R, 0.0)
    nz = z
    
    lx = -0.50
    ly = -0.60
    lz = 0.62
    l_len = np.sqrt(lx**2 + ly**2 + lz**2)
    lx /= l_len; ly /= l_len; lz /= l_len
    
    diffuse = np.clip(nx * lx + ny * ly + nz * lz, 0.0, 1.0)
    
    # Subtle bevel on bands
    edge_dist = np.clip(-dist_comb_px, 0.0, 20.0)
    bevel = np.clip(edge_dist / 6.0, 0.0, 1.0)
    
    band_lum = (0.75 + 0.25 * diffuse) * (0.88 + 0.12 * bevel)
    aa_alpha = np.clip(-dist_comb_px * 0.5 + 0.5, 0.0, 1.0)
    final_alpha = np.clip(band_lum * aa_alpha * 255.0, 0.0, 255.0).astype(np.uint8)
    final_alpha = np.where(dist_comb_px > 1.0, 0, final_alpha)
    
    alpha_img = np.zeros((size, size, 4), dtype=np.uint8)
    alpha_img[:, :, 0] = 255
    alpha_img[:, :, 1] = 255
    alpha_img[:, :, 2] = 255
    alpha_img[:, :, 3] = final_alpha
    
    # Save master assets
    alpha_path = os.path.join(output_dir, "logo-alpha.png")
    mask_path = os.path.join(output_dir, "logo-mask.png")
    Image.fromarray(alpha_img).save(alpha_path)
    Image.fromarray(mask_img).save(mask_path)
    
    # Social preview logo on pitch black background (clean crisp contrast)
    preview = Image.new("RGBA", (size, size), (0, 0, 0, 255))
    alpha_pil = Image.fromarray(alpha_img)
    # Very subtle crisp ambient drop shadow
    subtle_glow = alpha_pil.filter(ImageFilter.GaussianBlur(radius=12))
    preview.paste(subtle_glow, (0, 0), subtle_glow)
    preview.paste(alpha_pil, (0, 0), alpha_pil)
    preview.convert("RGB").save(os.path.join(output_dir, "logo.png"))
    
    # Multi-resolution icons
    sizes = [(32, "icon-32.png"), (64, "icon-64.png"), (180, "icon-180.png"), (192, "icon-192.png")]
    for s, name in sizes:
        icon = preview.resize((s, s), Image.Resampling.LANCZOS)
        icon.save(os.path.join(output_dir, name))
        
    fav32 = preview.resize((32, 32), Image.Resampling.LANCZOS)
    fav16 = preview.resize((16, 16), Image.Resampling.LANCZOS)
    fav32.save(os.path.join(output_dir, "favicon.ico"), format="ICO", sizes=[(16, 16), (32, 32)])
    print(f"Generated clean 3D striped sphere assets in {output_dir}")

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    generate_anode_sphere_logo(out)
