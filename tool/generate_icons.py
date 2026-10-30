"""
Generator script to render high-resolution PKA-Home App Icons and Notification Icons.
Rendered with 4x supersampling for ultra-crisp anti-aliasing.
"""

import os
import math
from PIL import Image, ImageDraw, ImageFilter

def create_gradient(width, height, color_top, color_bottom):
    """Creates a smooth vertical gradient image."""
    base = Image.new("RGBA", (width, height))
    draw = ImageDraw.Draw(base)
    for y in range(height):
        ratio = y / float(height - 1)
        r = int(color_top[0] * (1 - ratio) + color_bottom[0] * ratio)
        g = int(color_top[1] * (1 - ratio) + color_bottom[1] * ratio)
        b = int(color_top[2] * (1 - ratio) + color_bottom[2] * ratio)
        draw.line([(0, y), (width, y)], fill=(r, g, b, 255))
    return base

def draw_pka_home_symbol(draw, center_x, center_y, scale, is_monochrome=False):
    """
    Renders the PKA-Home architectural emblem:
    - Smart Home Roofline / Chevron apex
    - Modern Multi-tier residential towers
    - Illuminated window matrix
    """
    white = (255, 255, 255, 255)
    cyan_glow = (3, 169, 244, 255) if not is_monochrome else white
    soft_blue = (224, 242, 254, 255) if not is_monochrome else white
    door_accent = (255, 255, 255, 255)

    # 1. Roofline / Apex Chevron (Gable representing Home & Shelter)
    # Peak at (center_x, center_y - 280 * scale)
    roof_thickness = int(48 * scale)
    peak_y = center_y - int(320 * scale)
    left_x = center_x - int(330 * scale)
    right_x = center_x + int(330 * scale)
    eave_y = center_y - int(30 * scale)

    # Outer roof polygon
    roof_pts = [
        (center_x, peak_y),
        (right_x, eave_y),
        (right_x - int(35 * scale), eave_y + int(35 * scale)),
        (center_x, peak_y + int(70 * scale)),
        (left_x + int(35 * scale), eave_y + int(35 * scale)),
        (left_x, eave_y),
    ]
    draw.polygon(roof_pts, fill=cyan_glow if not is_monochrome else white)

    # 2. Main Central Tower (Chung cư cao tầng trung tâm)
    tower_w = int(220 * scale)
    tower_h = int(380 * scale)
    tower_left = center_x - tower_w // 2
    tower_top = center_y - int(120 * scale)
    tower_right = tower_left + tower_w
    tower_bottom = tower_top + tower_h

    # Main tower body
    draw.rounded_rectangle(
        [tower_left, tower_top, tower_right, tower_bottom],
        radius=int(16 * scale),
        fill=white
    )

    # 3. Left Wing (Block A / Tòa phụ bên trái)
    left_w = int(90 * scale)
    left_h = int(250 * scale)
    left_wing_x = tower_left - left_w - int(16 * scale)
    left_wing_y = tower_bottom - left_h
    draw.rounded_rectangle(
        [left_wing_x, left_wing_y, left_wing_x + left_w, tower_bottom],
        radius=int(12 * scale),
        fill=soft_blue
    )

    # 4. Right Wing (Block B / Tòa phụ bên phải)
    right_w = int(90 * scale)
    right_h = int(290 * scale)
    right_wing_x = tower_right + int(16 * scale)
    right_wing_y = tower_bottom - right_h
    draw.rounded_rectangle(
        [right_wing_x, right_wing_y, right_wing_x + right_w, tower_bottom],
        radius=int(12 * scale),
        fill=soft_blue
    )

    # 5. Window Grids in Central Tower (Negative cutouts or Blue windows)
    win_color = (24, 76, 120, 255) if not is_monochrome else (0, 0, 0, 0)
    num_rows = 4
    num_cols = 3
    win_w = int(32 * scale)
    win_h = int(42 * scale)
    col_spacing = int(22 * scale)
    row_spacing = int(24 * scale)

    start_x = tower_left + (tower_w - (num_cols * win_w + (num_cols - 1) * col_spacing)) // 2
    start_y = tower_top + int(45 * scale)

    for r in range(num_rows):
        for c in range(num_cols):
            wx = start_x + c * (win_w + col_spacing)
            wy = start_y + r * (win_h + row_spacing)
            draw.rounded_rectangle(
                [wx, wy, wx + win_w, wy + win_h],
                radius=int(6 * scale),
                fill=win_color
            )

    # Windows on Left Wing (2 rows x 1 col)
    for r in range(3):
        wx = left_wing_x + (left_w - win_w) // 2
        wy = left_wing_y + int(35 * scale) + r * (win_h + int(18 * scale))
        draw.rounded_rectangle(
            [wx, wy, wx + win_w, wy + win_h],
            radius=int(6 * scale),
            fill=win_color
        )

    # Windows on Right Wing (3 rows x 1 col)
    for r in range(3):
        wx = right_wing_x + (right_w - win_w) // 2
        wy = right_wing_y + int(35 * scale) + r * (win_h + int(18 * scale))
        draw.rounded_rectangle(
            [wx, wy, wx + win_w, wy + win_h],
            radius=int(6 * scale),
            fill=win_color
        )

    # 6. Entrance Grand Portal (Cổng vòm sảnh tòa nhà)
    entrance_w = int(64 * scale)
    entrance_h = int(80 * scale)
    ex = center_x - entrance_w // 2
    ey = tower_bottom - entrance_h
    draw.rounded_rectangle(
        [ex, ey, ex + entrance_w, tower_bottom],
        radius=int(14 * scale),
        fill=win_color
    )

    # 7. Base Foundation Ground Line
    ground_h = int(20 * scale)
    gx1 = left_wing_x - int(24 * scale)
    gx2 = right_wing_x + right_w + int(24 * scale)
    draw.rounded_rectangle(
        [gx1, tower_bottom, gx2, tower_bottom + ground_h],
        radius=int(10 * scale),
        fill=cyan_glow if not is_monochrome else white
    )

def generate_master_app_icon(output_path, size=1024):
    """Generates the full master app icon with rich gradient & lighting."""
    ss = 4
    render_size = size * ss
    
    # 1. Premium Blue Gradient: Navy (#0F2942) -> Royal (#1E3A8A) -> Vibrant Blue (#1E88E5)
    canvas = Image.new("RGBA", (render_size, render_size))
    gradient = create_gradient(render_size, render_size, (15, 37, 65), (30, 136, 229))
    canvas.paste(gradient, (0, 0))

    # Subtle ambient light radial circle in top-center
    glow = Image.new("RGBA", (render_size, render_size), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.ellipse(
        [
            render_size * 0.15,
            render_size * 0.05,
            render_size * 0.85,
            render_size * 0.75
        ],
        fill=(3, 169, 244, 45)
    )
    glow = glow.filter(ImageFilter.GaussianBlur(radius=80 * ss))
    canvas = Image.alpha_composite(canvas, glow)

    # 2. Draw the building symbol
    draw = ImageDraw.Draw(canvas)
    draw_pka_home_symbol(draw, render_size // 2, int(render_size * 0.52), scale=ss * 1.05)

    # 3. Downsample with Lanczos for anti-aliasing
    final_img = canvas.resize((size, size), Image.Resampling.LANCZOS)
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    final_img.save(output_path, "PNG")
    print(f"Generated: {output_path} ({size}x{size})")

def generate_foreground_app_icon(output_path, size=1024):
    """
    Generates transparent foreground icon for Android Adaptive Icons.
    Safe zone is within ~680px diameter.
    """
    ss = 4
    render_size = size * ss
    canvas = Image.new("RGBA", (render_size, render_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)

    # Safe zone scale (0.75 of full canvas ensures safe 66dp area)
    draw_pka_home_symbol(draw, render_size // 2, int(render_size * 0.52), scale=ss * 0.82)

    final_img = canvas.resize((size, size), Image.Resampling.LANCZOS)
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    final_img.save(output_path, "PNG")
    print(f"Generated: {output_path} ({size}x{size})")

def generate_notification_icon(output_path, size=512):
    """
    Generates Android status bar notification icon:
    100% white monochrome on transparent background.
    Tạo hình: Chuông thông báo kết hợp mái nhà PKA.
    """
    ss = 4
    render_size = size * ss
    canvas = Image.new("RGBA", (render_size, render_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)

    white = (255, 255, 255, 255)
    cx = render_size // 2
    cy = int(render_size * 0.5)

    # 1. Top House Roofline Apex (Mái nhà)
    roof_w = int(320 * ss)
    roof_top_y = cy - int(170 * ss)
    roof_h = int(100 * ss)
    thickness = int(36 * ss)

    # Chevron roof peak
    draw.polygon([
        (cx, roof_top_y),
        (cx + roof_w // 2, roof_top_y + roof_h),
        (cx + roof_w // 2 - int(24 * ss), roof_top_y + roof_h + int(18 * ss)),
        (cx, roof_top_y + thickness),
        (cx - roof_w // 2 + int(24 * ss), roof_top_y + roof_h + int(18 * ss)),
        (cx - roof_w // 2, roof_top_y + roof_h),
    ], fill=white)

    # 2. Bell Dome / Body (Thân chuông)
    bell_top = roof_top_y + thickness + int(10 * ss)
    bell_w = int(220 * ss)
    bell_h = int(190 * ss)
    
    # Upper dome arc
    draw.pieslice(
        [cx - bell_w // 2, bell_top, cx + bell_w // 2, bell_top + bell_h * 2],
        start=180, end=360, fill=white
    )
    # Bell lower flare
    flare_w = int(280 * ss)
    flare_top = bell_top + bell_h - int(30 * ss)
    draw.polygon([
        (cx - bell_w // 2, flare_top),
        (cx + bell_w // 2, flare_top),
        (cx + flare_w // 2, flare_top + int(45 * ss)),
        (cx - flare_w // 2, flare_top + int(45 * ss)),
    ], fill=white)

    # Bottom lip of bell
    lip_h = int(22 * ss)
    lip_y = flare_top + int(45 * ss)
    draw.rounded_rectangle(
        [cx - flare_w // 2 - int(10 * ss), lip_y, cx + flare_w // 2 + int(10 * ss), lip_y + lip_h],
        radius=int(10 * ss),
        fill=white
    )

    # 3. Bell Clapper (Quả lắc chuông)
    clapper_r = int(28 * ss)
    clapper_y = lip_y + lip_h + int(8 * ss)
    draw.ellipse(
        [cx - clapper_r, clapper_y - clapper_r, cx + clapper_r, clapper_y + clapper_r],
        fill=white
    )

    # 4. Negative cutout: A mini door/smart house cutout in bell center
    cutout_w = int(54 * ss)
    cutout_h = int(80 * ss)
    cutout_x = cx - cutout_w // 2
    cutout_y = lip_y - cutout_h + int(4 * ss)
    draw.rounded_rectangle(
        [cutout_x, cutout_y, cutout_x + cutout_w, cutout_y + cutout_h],
        radius=int(14 * ss),
        fill=(0, 0, 0, 0)
    )

    final_img = canvas.resize((size, size), Image.Resampling.LANCZOS)
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    final_img.save(output_path, "PNG")
    print(f"Generated: {output_path} ({size}x{size})")

if __name__ == "__main__":
    generate_master_app_icon("assets/icons/app_icon.png", 1024)
    generate_foreground_app_icon("assets/icons/app_icon_foreground.png", 1024)
    generate_notification_icon("assets/icons/notification_icon.png", 512)

    # Render density variants for Android notification drawables
    sizes = {
        "drawable-mdpi": 24,
        "drawable-hdpi": 36,
        "drawable-xhdpi": 48,
        "drawable-xxhdpi": 72,
        "drawable-xxxhdpi": 96,
    }
    for folder, dim in sizes.items():
        out = f"android/app/src/main/res/{folder}/ic_notification.png"
        generate_notification_icon(out, dim)

