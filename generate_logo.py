import os
import sys
import numpy as np
from PIL import Image, ImageFilter

def generate_anode_logo(output_dir=".", size=1254):
    os.makedirs(output_dir, exist_ok=True)
    
    # Coordinate grid: -1 to 1 centered
    y, x = np.ogrid[:size, :size]
    cx = (size - 1) / 2.0
    cy = (size - 1) / 2.0
    
    # Normalized coordinates
    u = (x - cx) / (size * 0.40)
    v = (y - cy) / (size * 0.40)
    
    r = np.sqrt(u**2 + v**2)
    theta = np.arctan2(v, u)
    
    # Anode energy node:
    # 4-fold astroid-squircle symmetry, clean and balanced
    # Base radius modulation
    modulation = 0.30 * np.cos(4 * theta) + 0.04 * np.cos(8 * theta)
    r_target = 0.78 + modulation
    
    # Distance in pixels to the contour
    scale = (size * 0.40)
    dist_px = (r - r_target) * scale
    
    # Binary/Sharp mask with smooth 2px antialiased boundary
    # Inside: dist_px < 0 -> alpha = 255
    # Outside: dist_px > 0 -> alpha = 0
    mask_alpha = np.clip(0.5 - dist_px * 0.5, 0.0, 1.0) * 255.0
    mask_img = np.zeros((size, size, 4), dtype=np.uint8)
    mask_img[:, :, 0] = 255
    mask_img[:, :, 1] = 255
    mask_img[:, :, 2] = 255
    mask_img[:, :, 3] = mask_alpha.astype(np.uint8)
    
    # Rim lighting
    # Outer glow: decays outside the boundary (dist_px > 0)
    outer_glow = np.exp(-np.maximum(0.0, dist_px)**2 / (2 * 16.0**2))
    
    # Inner rim bevel: decays sharply inside the boundary (dist_px < 0)
    # Reaches near 0 by 50px inwards
    inner_glow = np.exp(-np.maximum(0.0, -dist_px)**1.6 / (2 * 20.0**2))
    # Cutoff inner glow completely if deeper than 65px
    inner_glow = np.where(dist_px < -70.0, 0.0, inner_glow)
    
    rim = np.where(dist_px >= 0, outer_glow, inner_glow)
    
    # Directional specular highlight from top-left (angle -3pi/4)
    light_angle = -3.0 * np.pi / 4.0
    dmod = -0.30 * 4 * np.sin(4 * theta) - 0.04 * 8 * np.sin(8 * theta)
    nx = np.cos(theta) - dmod * np.sin(theta) / r_target
    ny = np.sin(theta) + dmod * np.cos(theta) / r_target
    norm_len = np.sqrt(nx**2 + ny**2) + 1e-6
    nx /= norm_len
    ny /= norm_len
    
    lx = np.cos(light_angle)
    ly = np.sin(light_angle)
    diffuse = np.clip(nx * lx + ny * ly, 0.0, 1.0)
    
    # Rim brightness: strong highlight on top-left, soft rim all around
    rim_brightness = (0.50 + 0.50 * diffuse) * rim
    alpha_channel = np.clip(rim_brightness * 255.0, 0.0, 255.0).astype(np.uint8)
    
    alpha_img = np.zeros((size, size, 4), dtype=np.uint8)
    alpha_img[:, :, 0] = 255
    alpha_img[:, :, 1] = 255
    alpha_img[:, :, 2] = 255
    alpha_img[:, :, 3] = alpha_channel
    
    # Save master assets
    alpha_path = os.path.join(output_dir, "logo-alpha.png")
    mask_path = os.path.join(output_dir, "logo-mask.png")
    Image.fromarray(alpha_img).save(alpha_path)
    Image.fromarray(mask_img).save(mask_path)
    
    # Social preview logo on pitch black background
    preview = Image.new("RGBA", (size, size), (0, 0, 0, 255))
    alpha_pil = Image.fromarray(alpha_img)
    # Ambient halo bloom
    bloom1 = alpha_pil.filter(ImageFilter.GaussianBlur(radius=32))
    bloom2 = alpha_pil.filter(ImageFilter.GaussianBlur(radius=80))
    # Soft composite
    preview.paste(bloom2, (0, 0), bloom2)
    preview.paste(bloom1, (0, 0), bloom1)
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
    print(f"Refined Anode assets generated successfully in {output_dir}")

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    generate_anode_logo(out)
