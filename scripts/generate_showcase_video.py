import os, sys, math, subprocess
from PIL import Image, ImageDraw, ImageFont, ImageFilter

WIDTH, HEIGHT = 1920, 1080
FPS = 30
TOTAL_FRAMES = 900  # Exactly 30.0 seconds

# Colors (Things 3 & Crucial palette)
BG_COLOR = (12, 14, 20)           # Deep obsidian carbon
CARD_BG = (22, 26, 36)            # Raised dark card
CARD_BORDER = (255, 255, 255, 24) # 10% white line
ACCENT = (13, 166, 135)           # Alpine Emerald #0DA687
ACCENT_LIGHT = (26, 188, 160)     # Emerald light
HONEY = (245, 158, 26)            # Honey Ochre #F59E1A
CRIMSON = (239, 71, 71)           # Vital Crimson
TEXT_PRIMARY = (240, 243, 248)    # Clean off-white
TEXT_MUTED = (156, 163, 175)      # Neutral secondary
TEXT_FAINT = (107, 114, 128)

# Load fonts
try:
    font_huge = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 72)
    font_hero = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 52)
    font_h2 = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 36)
    font_card_title = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 23)
    font_card_sub = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 16)
    font_mono = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 17)
    font_mono_lg = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 22)
    font_stat = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 56)
    font_badge = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 18)
except Exception:
    font_huge = font_hero = font_h2 = font_card_title = font_card_sub = font_mono = font_mono_lg = font_stat = font_badge = ImageFont.load_default()

# Asset paths
ICON_PATH = "/Users/py/.gemini/antigravity/scratch/crucial/resources/AppIcon.png"
AUDIO_PATH = "/tmp/audio_30s.m4a"
OUTPUT_VIDEO = "/Users/py/.gemini/antigravity/scratch/crucial/docs/crucial-showcase.mp4"
POSTER_PATH = "/Users/py/.gemini/antigravity/scratch/crucial/docs/video-poster.jpg"

raw_icon = Image.open(ICON_PATH).convert("RGBA")
uninstaller_img = Image.open("/tmp/screen_uninstaller_scanned.png").convert("RGBA")
assistant_img = Image.open("/tmp/screen_assistant_answered.png").convert("RGBA")
treemap_img = Image.open("/tmp/screen_treemap.png").convert("RGBA")
maintenance_img = Image.open("/tmp/screen_maintenance.png").convert("RGBA")

# Create squircle-masked app icon
def get_masked_icon(size):
    ico = raw_icon.resize((size, size), Image.Resampling.LANCZOS)
    return ico

# Pre-render scaled app windows with rounded corners and drop shadows
WIN_W = 1320
WIN_H = int(WIN_W * 760 / 1408)

def prepare_window(src_img):
    scaled = src_img.resize((WIN_W, WIN_H), Image.Resampling.LANCZOS)
    mask = Image.new("L", (WIN_W, WIN_H), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([0, 0, WIN_W, WIN_H], radius=18, fill=255)
    
    # Pre-render deep shadow
    shadow = Image.new("RGBA", (WIN_W + 80, WIN_H + 80), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle([40, 40, WIN_W + 40, WIN_H + 40], radius=26, fill=(0, 0, 0, 170))
    shadow = shadow.filter(ImageFilter.GaussianBlur(30))
    return scaled, mask, shadow

win_uninstaller, win_mask, win_shadow = prepare_window(uninstaller_img)
win_assistant, _, _ = prepare_window(assistant_img)
win_treemap, _, _ = prepare_window(treemap_img)

# Easing functions
def ease_out_cubic(t):
    t = max(0.0, min(1.0, t))
    return 1 - (1 - t) ** 3

def ease_in_out_cubic(t):
    t = max(0.0, min(1.0, t))
    if t < 0.5:
        return 4 * t * t * t
    return 1 - ((-2 * t + 2) ** 3) / 2

def ease_out_back(t, s=1.4):
    t = max(0.0, min(1.0, t))
    return 1 + (s + 1) * ((t - 1) ** 3) + s * ((t - 1) ** 2)

def smoothstep(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)

# Base background grid
def render_background(spotlight_x=960, spotlight_y=540, spotlight_r=750, alpha_factor=1.0):
    bg = Image.new("RGBA", (WIDTH, HEIGHT), BG_COLOR + (255,))
    draw = ImageDraw.Draw(bg)
    grid_col = (255, 255, 255, 9)
    for x in range(0, WIDTH, 48):
        draw.line([(x, 0), (x, HEIGHT)], fill=grid_col, width=1)
    for y in range(0, HEIGHT, 48):
        draw.line([(0, y), (WIDTH, y)], fill=grid_col, width=1)
        
    spot = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(spot)
    max_a = int(36 * alpha_factor)
    for r in range(spotlight_r, 0, -25):
        a = int(max_a * (1.0 - (r / float(spotlight_r))**1.6))
        if a > 0:
            sdraw.ellipse([spotlight_x - r, spotlight_y - r, spotlight_x + r, spotlight_y + r], fill=(13, 166, 135, a))
    return Image.alpha_composite(bg, spot)

def render_breadcrumb(canvas, section="", alpha=1.0):
    if alpha <= 0:
        return
    ico_s = get_masked_icon(32)
    canvas.paste(ico_s, (60, 46), ico_s)
    draw = ImageDraw.Draw(canvas)
    text_col = (TEXT_PRIMARY[0], TEXT_PRIMARY[1], TEXT_PRIMARY[2], int(255 * alpha))
    faint_col = (TEXT_FAINT[0], TEXT_FAINT[1], TEXT_FAINT[2], int(220 * alpha))
    draw.text((104, 50), "Crucial", fill=text_col, font=font_card_title)
    if section:
        draw.text((196, 53), section, fill=faint_col, font=font_mono)

def render_card(canvas, x, y, w, h, category, title, sub, stat, stat_color=HONEY, opacity=1.0):
    if opacity <= 0:
        return
    card = Image.new("RGBA", (w, h), (24, 28, 40, int(245 * opacity)))
    cd = ImageDraw.Draw(card)
    border_col = (255, 255, 255, int(28 * opacity))
    cd.rounded_rectangle([0, 0, w-1, h-1], radius=16, outline=border_col, width=1)
    
    cat_col = (ACCENT_LIGHT[0], ACCENT_LIGHT[1], ACCENT_LIGHT[2], int(255 * opacity))
    cd.text((22, 16), category.upper(), fill=cat_col, font=font_mono)
    
    t_col = (TEXT_PRIMARY[0], TEXT_PRIMARY[1], TEXT_PRIMARY[2], int(255 * opacity))
    cd.text((22, 44), title, fill=t_col, font=font_card_title)
    
    s_col = (TEXT_MUTED[0], TEXT_MUTED[1], TEXT_MUTED[2], int(255 * opacity))
    cd.text((22, 76), sub, fill=s_col, font=font_card_sub)
    
    st_col = (stat_color[0], stat_color[1], stat_color[2], int(255 * opacity))
    cd.text((w - 24, 44), stat, fill=st_col, font=font_card_title, anchor="rt")
    
    # Shadow
    shadow = Image.new("RGBA", (w + 40, h + 40), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle([20, 20, w + 20, h + 20], radius=20, fill=(0, 0, 0, int(130 * opacity)))
    shadow = shadow.filter(ImageFilter.GaussianBlur(14))
    
    canvas.paste(shadow, (int(x - 20), int(y - 10)), shadow)
    canvas.paste(card, (int(x), int(y)), card)

def render_cursor(canvas, x, y, clicking=False, click_progress=0.0):
    if x < -50 or x > WIDTH + 50 or y < -50 or y > HEIGHT + 50:
        return
    cursor = Image.new("RGBA", (44, 44), (0, 0, 0, 0))
    cdraw = ImageDraw.Draw(cursor)
    pts = [(2, 2), (2, 26), (8, 20), (14, 30), (17, 28), (11, 18), (20, 18)]
    shadow_pts = [(p[0]+2, p[1]+2) for p in pts]
    cdraw.polygon(shadow_pts, fill=(0, 0, 0, 100))
    cdraw.polygon(pts, fill=(255, 255, 255, 255), outline=(15, 15, 20, 240))
    
    if clicking and click_progress > 0:
        r = int(12 + click_progress * 28)
        alpha = int((1.0 - click_progress) * 160)
        ripple = Image.new("RGBA", (r * 2 + 10, r * 2 + 10), (0, 0, 0, 0))
        rd = ImageDraw.Draw(ripple)
        rd.ellipse([5, 5, r * 2 + 5, r * 2 + 5], outline=(13, 166, 135, alpha), width=2)
        canvas.paste(ripple, (int(x - r), int(y - r)), ripple)
        
    canvas.paste(cursor, (int(x), int(y)), cursor)

def render_bento_stat(canvas, x, y, w, h, stat, label, sub, color=ACCENT_LIGHT):
    card = Image.new("RGBA", (w, h), (24, 28, 42, 240))
    cd = ImageDraw.Draw(card)
    cd.rounded_rectangle([0, 0, w-1, h-1], radius=18, outline=(255, 255, 255, 24), width=1)
    cd.text((24, 22), stat, fill=color, font=font_stat)
    cd.text((24, 88), label, fill=TEXT_PRIMARY, font=font_card_title)
    cd.text((24, 122), sub, fill=TEXT_MUTED, font=font_card_sub)
    
    shadow = Image.new("RGBA", (w + 40, h + 40), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle([20, 20, w + 20, h + 20], radius=22, fill=(0, 0, 0, 120))
    shadow = shadow.filter(ImageFilter.GaussianBlur(16))
    canvas.paste(shadow, (int(x - 20), int(y - 10)), shadow)
    canvas.paste(card, (int(x), int(y)), card)

# FFmpeg Video Pipe Setup
ffmpeg_cmd = [
    "ffmpeg", "-y",
    "-f", "rawvideo",
    "-vcodec", "rawvideo",
    "-s", f"{WIDTH}x{HEIGHT}",
    "-pix_fmt", "rgba",
    "-r", str(FPS),
    "-i", "-",
    "-i", AUDIO_PATH,
    "-c:v", "libx264",
    "-preset", "veryfast",
    "-crf", "18",
    "-pix_fmt", "yuv420p",
    "-c:a", "aac",
    "-b:a", "192k",
    "-shortest",
    OUTPUT_VIDEO
]

proc = subprocess.Popen(ffmpeg_cmd, stdin=subprocess.PIPE)

print(f"Rendering {TOTAL_FRAMES} frames (30.0s @ {FPS} fps)...")

for frame in range(TOTAL_FRAMES):
    t_sec = frame / float(FPS)
    
    # =========================================================================
    # SCENE 1: The Hook (0.0s - 6.3s, frames 0 - 190)
    # =========================================================================
    if frame < 190:
        spot_intensity = 0.8 + 0.2 * math.sin(frame * 0.08)
        canvas = render_background(spotlight_x=960, spotlight_y=540, alpha_factor=spot_intensity)
        
        # Sub-phase A: Center logo reveal (0.0s - 2.3s, frames 0 - 70)
        if frame < 70:
            p = ease_out_back(frame / 60.0)
            ico_size = int(80 + p * 120)
            if ico_size > 10:
                ico = get_masked_icon(ico_size)
                # Shadow
                sh_size = ico_size + 40
                sh = Image.new("RGBA", (sh_size, sh_size), (0, 0, 0, 0))
                sd = ImageDraw.Draw(sh)
                sd.rounded_rectangle([20, 20, sh_size - 20, sh_size - 20], radius=int(sh_size * 0.22), fill=(0, 0, 0, 150))
                sh = sh.filter(ImageFilter.GaussianBlur(16))
                canvas.paste(sh, (960 - sh_size // 2, 450 - sh_size // 2 + 10), sh)
                canvas.paste(ico, (960 - ico_size // 2, 450 - ico_size // 2), ico)
                
            # Title & Subtitle fade in
            alpha = max(0.0, min(1.0, (frame - 25) / 30.0))
            if alpha > 0:
                draw = ImageDraw.Draw(canvas)
                t_col = (TEXT_PRIMARY[0], TEXT_PRIMARY[1], TEXT_PRIMARY[2], int(255 * alpha))
                s_col = (TEXT_MUTED[0], TEXT_MUTED[1], TEXT_MUTED[2], int(255 * alpha))
                draw.text((960, 580), "Crucial.", fill=t_col, font=font_hero, anchor="mt")
                draw.text((960, 646), "Quiet storage intelligence for your Mac.", fill=s_col, font=font_card_sub, anchor="mt")
                
        # Sub-phase B: Clutter problem cards appear (2.3s - 6.3s, frames 70 - 190)
        else:
            rel = frame - 70
            render_breadcrumb(canvas, section="/ storage", alpha=min(1.0, rel / 20.0))
            
            # Bottom-left typography
            d = ImageDraw.Draw(canvas)
            d.text((60, 920), "One Mac.", fill=TEXT_PRIMARY, font=font_hero)
            d.text((60, 985), "Cluttered everywhere.", fill=TEXT_MUTED, font=font_h2)
            
            # Card 1 (Dia / Claude / Apps residue)
            c1_p = ease_out_back(rel / 25.0)
            c1_x = 540 + (1.0 - c1_p) * 400
            render_card(canvas, c1_x, 220, 640, 125, "Uninstaller", "Orphaned App Residues", "~/Library/Application Support/Dia", "8.22 GB", stat_color=HONEY)
            
            # Card 2 (Developer build bloat)
            c2_p = ease_out_back((rel - 12) / 25.0)
            if rel >= 12:
                c2_x = 610 + (1.0 - c2_p) * 400
                render_card(canvas, c2_x, 380, 640, 125, "Developer", "Developer Build Caches", "node_modules, Xcode DerivedData, .venv", "14.8 GB", stat_color=ACCENT_LIGHT)
                
            # Card 3 (APFS snapshots)
            c3_p = ease_out_back((rel - 24) / 25.0)
            if rel >= 24:
                c3_x = 570 + (1.0 - c3_p) * 400
                render_card(canvas, c3_x, 540, 640, 125, "System", "APFS Local Snapshots", "Locked delta files from Time Machine", "28.4 GB", stat_color=HONEY)
                
            # Cursor gliding over cards
            cur_p = ease_out_cubic(rel / 90.0)
            cur_x = 1200 - cur_p * 450
            cur_y = 650 - cur_p * 200
            render_cursor(canvas, cur_x, cur_y)
            
    # =========================================================================
    # SCENE 2: The Core Hero — App Uninstaller (6.3s - 12.7s, frames 190 - 380)
    # =========================================================================
    elif frame < 380:
        rel = frame - 190
        canvas = render_background(spotlight_x=1200, spotlight_y=540)
        render_breadcrumb(canvas, section="/ uninstaller", alpha=1.0)
        
        # Bottom-left typography
        d = ImageDraw.Draw(canvas)
        d.text((60, 920), "Every residue found.", fill=TEXT_PRIMARY, font=font_hero)
        d.text((60, 985), "Deep Library tracing.", fill=TEXT_MUTED, font=font_h2)
        
        # Left stacked cards
        render_card(canvas, 60, 250, 420, 115, "Detected", "Application Residue", "6 unlinked Library folders", "8.22 GB", stat_color=HONEY)
        render_card(canvas, 60, 400, 420, 115, "Cleanable", "Cache Stores", "HTTP & WebKit storage", "1.52 GB", stat_color=ACCENT_LIGHT)
        
        # Window glide in from right
        win_p = ease_out_cubic(rel / 30.0)
        target_win_x, target_win_y = 520, 170
        curr_win_x = int(target_win_x + (1.0 - win_p) * 600)
        
        canvas.paste(win_shadow, (curr_win_x - 40, target_win_y - 20), win_shadow)
        canvas.paste(win_uninstaller, (curr_win_x, target_win_y), win_mask)
        
        # Glowing connection curves linking left cards to window
        curve_alpha = min(1.0, max(0.0, (rel - 20) / 20.0))
        if curve_alpha > 0:
            curve_layer = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
            cdraw = ImageDraw.Draw(curve_layer)
            # Curve 1
            p0 = (480, 307)
            p3 = (curr_win_x, target_win_y + 150)
            p1 = (curr_win_x - 80, 307)
            p2 = (curr_win_x - 40, target_win_y + 150)
            pts = []
            for s in range(25):
                u = s / 24.0
                bx = (1-u)**3 * p0[0] + 3*(1-u)**2*u * p1[0] + 3*(1-u)*u**2 * p2[0] + u**3 * p3[0]
                by = (1-u)**3 * p0[1] + 3*(1-u)**2*u * p1[1] + 3*(1-u)*u**2 * p2[1] + u**3 * p3[1]
                pts.append((bx, by))
            cdraw.line(pts, fill=(13, 166, 135, int(180 * curve_alpha)), width=3)
            canvas = Image.alpha_composite(canvas, curve_layer)
            
        # Cursor interaction: Moves to "Quit & Move to Trash" and clicks at rel=120
        clicking = (120 <= rel <= 145)
        click_p = (rel - 120) / 25.0 if clicking else 0.0
        
        if rel < 120:
            cp = ease_out_cubic(rel / 120.0)
            cx = curr_win_x + 400 + cp * 780
            cy = target_win_y + 200 + cp * 480
        else:
            cx = curr_win_x + 1180
            cy = target_win_y + 680
            
        render_cursor(canvas, cx, cy, clicking=clicking, click_progress=click_p)
        
        # Trash confirmation badge floats in after click
        if rel > 130:
            bp = ease_out_back(min(1.0, (rel - 130) / 20.0))
            badge_w, badge_h = 420, 56
            badge_x = int(curr_win_x + 800)
            badge_y = int(target_win_y + 600 - bp * 20)
            badge = Image.new("RGBA", (badge_w, badge_h), (18, 24, 34, 250))
            bd = ImageDraw.Draw(badge)
            bd.rounded_rectangle([0, 0, badge_w-1, badge_h-1], radius=14, outline=ACCENT, width=1)
            bd.text((20, 18), "✓ Staged to Trash · 100% Reversible", fill=TEXT_PRIMARY, font=font_badge)
            canvas.paste(badge, (badge_x, badge_y), badge)
            
    # =========================================================================
    # SCENE 3: Onboard Local AI — Crucial Assistant (12.7s - 18.7s, frames 380 - 560)
    # =========================================================================
    elif frame < 560:
        rel = frame - 380
        canvas = render_background(spotlight_x=1200, spotlight_y=540)
        render_breadcrumb(canvas, section="/ intelligence", alpha=1.0)
        
        # Bottom-left typography
        d = ImageDraw.Draw(canvas)
        d.text((60, 920), "Zero guesswork.", fill=TEXT_PRIMARY, font=font_hero)
        d.text((60, 985), "100% on-device Metal LLM.", fill=TEXT_MUTED, font=font_h2)
        
        # Left card: Offline privacy
        render_card(canvas, 60, 250, 420, 115, "Architecture", "Local Metal Llama 3.2", "No API keys · Zero network calls", "Offline", stat_color=ACCENT_LIGHT)
        render_card(canvas, 60, 400, 420, 115, "Explainability", "Provenance Analysis", "Explains why files exist before delete", "Safe", stat_color=HONEY)
        
        target_win_x, target_win_y = 520, 170
        canvas.paste(win_shadow, (target_win_x - 40, target_win_y - 20), win_shadow)
        canvas.paste(win_assistant, (target_win_x, target_win_y), win_mask)
        
        # Cursor clicks "Disk Health" at rel=35
        clicking = (35 <= rel <= 60)
        click_p = (rel - 35) / 25.0 if clicking else 0.0
        if rel < 35:
            cp = ease_out_cubic(rel / 35.0)
            cx = target_win_x + 100 + cp * 220
            cy = target_win_y + 300 - cp * 180
        else:
            cx = target_win_x + 320
            cy = target_win_y + 120
        render_cursor(canvas, cx, cy, clicking=clicking, click_progress=click_p)
        
        # Floating telemetry card
        tele_p = ease_out_back(min(1.0, rel / 25.0))
        tele_w, tele_h = 420, 76
        tele_x = target_win_x + 60
        tele_y = int(target_win_y + 240 + (1.0 - tele_p) * 60)
        tele = Image.new("RGBA", (tele_w, tele_h), (18, 24, 36, 245))
        td = ImageDraw.Draw(tele)
        td.rounded_rectangle([0, 0, tele_w-1, tele_h-1], radius=16, outline=ACCENT, width=1)
        td.text((22, 16), "⚡ 47.5 tokens/sec", fill=ACCENT_LIGHT, font=font_card_title)
        td.text((22, 46), "Apple Silicon Metal GPU · 0 KB Cloud", fill=TEXT_MUTED, font=font_card_sub)
        canvas.paste(tele, (tele_x, tele_y), tele)
        
    # =========================================================================
    # SCENE 4: Storage Treemap & Performance Bento (18.7s - 24.3s, frames 560 - 730)
    # =========================================================================
    elif frame < 730:
        rel = frame - 560
        canvas = render_background(spotlight_x=800, spotlight_y=540)
        render_breadcrumb(canvas, section="/ treemap", alpha=1.0)
        
        # Bottom-left typography
        d = ImageDraw.Draw(canvas)
        d.text((60, 920), "Pure speed. Zero noise.", fill=TEXT_PRIMARY, font=font_hero)
        d.text((60, 985), "Hardware-accelerated engine.", fill=TEXT_MUTED, font=font_h2)
        
        # Left window (Storage Treemap)
        win_w_small = 980
        win_h_small = int(win_w_small * 760 / 1408)
        scaled_treemap = treemap_img.resize((win_w_small, win_h_small), Image.Resampling.LANCZOS)
        tmask = Image.new("L", (win_w_small, win_h_small), 0)
        tmd = ImageDraw.Draw(tmask)
        tmd.rounded_rectangle([0, 0, win_w_small, win_h_small], radius=18, fill=255)
        
        tshadow = Image.new("RGBA", (win_w_small + 60, win_h_small + 60), (0, 0, 0, 0))
        tsd = ImageDraw.Draw(tshadow)
        tsd.rounded_rectangle([30, 30, win_w_small + 30, win_h_small + 30], radius=24, fill=(0, 0, 0, 160))
        tshadow = tshadow.filter(ImageFilter.GaussianBlur(24))
        
        tx = 60
        ty = 230
        canvas.paste(tshadow, (tx - 30, ty - 20), tshadow)
        canvas.paste(scaled_treemap, (tx, ty), tmask)
        
        # Bento Cards on the right
        # Bento 1: 2,163 MB/s
        b1_p = ease_out_back(rel / 25.0)
        b1_x = int(1100 + (1.0 - b1_p) * 400)
        render_bento_stat(canvas, b1_x, 220, 720, 165, "2,163 MB/s", "SHA-256 Duplicate Scanner", "Cryptographic byte-exact hashing with zero CPU churn", color=HONEY)
        
        # Bento 2: 0 MB RAM
        b2_p = ease_out_back((rel - 15) / 25.0)
        if rel >= 15:
            b2_x = int(1100 + (1.0 - b2_p) * 400)
            render_bento_stat(canvas, b2_x, 415, 720, 165, "0 MB RAM", "Zero Background Daemons", "Quits completely when closed. No silent background polling.", color=ACCENT_LIGHT)
            
        # Bento 3: 5.7 MB Universal Binary
        b3_p = ease_out_back((rel - 30) / 25.0)
        if rel >= 30:
            b3_x = int(1100 + (1.0 - b3_p) * 400)
            render_bento_stat(canvas, b3_x, 610, 720, 165, "5.7 MB", "Universal Native Binary", "Handcrafted in 100% pure Swift & Metal. Zero Electron bloat.", color=TEXT_PRIMARY)
            
    # =========================================================================
    # SCENE 5: Climax & Outro (24.3s - 30.0s, frames 730 - 900)
    # =========================================================================
    else:
        rel = frame - 730
        canvas = render_background(spotlight_x=960, spotlight_y=540, spotlight_r=700)
        render_breadcrumb(canvas, section="", alpha=1.0)
        
        # Large centered Chiral Prism Aperture logo
        ico_p = ease_out_back(min(1.0, rel / 35.0))
        ico_sz = int(220 * ico_p)
        if ico_sz > 10:
            ico = get_masked_icon(ico_sz)
            sh_sz = ico_sz + 44
            sh = Image.new("RGBA", (sh_sz, sh_sz), (0, 0, 0, 0))
            sd = ImageDraw.Draw(sh)
            sd.rounded_rectangle([22, 22, sh_sz - 22, sh_sz - 22], radius=int(sh_sz * 0.22), fill=(0, 0, 0, 150))
            sh = sh.filter(ImageFilter.GaussianBlur(18))
            canvas.paste(sh, (960 - sh_sz // 2, 380 - sh_sz // 2 + 10), sh)
            canvas.paste(ico, (960 - ico_sz // 2, 380 - ico_sz // 2), ico)
            
        # Typography
        t_alpha = min(1.0, max(0.0, (rel - 20) / 30.0))
        if t_alpha > 0:
            draw = ImageDraw.Draw(canvas)
            t_col = (TEXT_PRIMARY[0], TEXT_PRIMARY[1], TEXT_PRIMARY[2], int(255 * t_alpha))
            s_col = (TEXT_MUTED[0], TEXT_MUTED[1], TEXT_MUTED[2], int(255 * t_alpha))
            u_col = (ACCENT_LIGHT[0], ACCENT_LIGHT[1], ACCENT_LIGHT[2], int(255 * t_alpha))
            
            draw.text((960, 520), "Crucial.", fill=t_col, font=font_huge, anchor="mt")
            draw.text((960, 615), "Quiet. Native. Free forever.", fill=s_col, font=font_h2, anchor="mt")
            draw.text((960, 690), "yprnv7.github.io/crucial", fill=u_col, font=font_mono_lg, anchor="mt")
            
        # Shimmer highlight across logo
        if 50 <= rel <= 110:
            shim_p = (rel - 50) / 60.0
            shim = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
            shd = ImageDraw.Draw(shim)
            sx = int(960 - 200 + shim_p * 400)
            shd.line([(sx - 40, 260), (sx + 40, 500)], fill=(255, 255, 255, 45), width=24)
            shim = shim.filter(ImageFilter.GaussianBlur(12))
            canvas = Image.alpha_composite(canvas, shim)
            
        # Fade out to black at the very end (last 15 frames)
        if frame >= 885:
            fade_p = (frame - 885) / 15.0
            fade_layer = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, int(255 * fade_p)))
            canvas = Image.alpha_composite(canvas, fade_layer)
            
    # Save frame 300 as the video poster snapshot
    if frame == 300:
        canvas.convert("RGB").save(POSTER_PATH, "JPEG", quality=90)
        
    proc.stdin.write(canvas.tobytes())
    
    if (frame + 1) % 90 == 0:
        print(f"Rendered {frame + 1}/{TOTAL_FRAMES} frames ({((frame+1)/TOTAL_FRAMES)*100:.0f}%)...")

proc.stdin.close()
proc.wait()
print(f"Showcase video generated successfully at {OUTPUT_VIDEO} (returncode: {proc.returncode})")
