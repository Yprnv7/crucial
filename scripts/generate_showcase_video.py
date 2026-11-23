import os, sys, math, subprocess
from PIL import Image, ImageDraw, ImageFont, ImageFilter

WIDTH, HEIGHT = 1920, 1080
FPS = 30
TOTAL_FRAMES = 780  # 26.0 seconds

# Colors (Things 3 & Crucial palette)
BG_COLOR = (12, 11, 20)           # Deep ink background
CARD_BG = (22, 21, 34)            # Raised card
CARD_BORDER = (255, 255, 255, 24) # 10% white
ACCENT = (13, 166, 135)           # Alpine Emerald #0DA687
ACCENT_LIGHT = (26, 188, 160)     # Emerald light
HONEY = (245, 158, 26)            # Honey Ochre #F59E1A
CRIMSON = (239, 71, 71)           # Vital Crimson
TEXT_PRIMARY = (238, 236, 247)    # Off-white
TEXT_MUTED = (166, 162, 188)      # Lavender gray
TEXT_FAINT = (110, 106, 132)

# Load fonts
try:
    font_hero = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 64)
    font_h2 = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 46)
    font_h3 = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 32)
    font_body = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 22)
    font_small = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 17)
    font_mono = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 20)
    font_large_stat = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 80)
except Exception:
    font_hero = font_h2 = font_h3 = font_body = font_small = font_mono = font_large_stat = ImageFont.load_default()

# Load assets
ICON_PATH = "/Users/py/.gemini/antigravity/scratch/crucial/resources/AppIcon.png"
SCREEN_PATH = "/tmp/crucial_app_screen.jpg"
AUDIO_PATH = "/tmp/promo_audio.m4a"
OUTPUT_VIDEO = "/Users/py/.gemini/antigravity/scratch/crucial/docs/crucial-showcase.mp4"

os.makedirs("/Users/py/.gemini/antigravity/scratch/crucial/docs", exist_ok=True)

app_icon = None
if os.path.exists(ICON_PATH):
    app_icon = Image.open(ICON_PATH).convert("RGBA")

app_screen = None
if os.path.exists(SCREEN_PATH):
    app_screen = Image.open(SCREEN_PATH).convert("RGB")

def ease_out_cubic(t):
    return 1 - (1 - max(0.0, min(1.0, t))) ** 3

def ease_in_out_cubic(t):
    t = max(0.0, min(1.0, t))
    return 4 * t * t * t if t < 0.5 else 1 - (-2 * t + 2) ** 3 / 2

def draw_grid_background(draw):
    draw.rectangle([0, 0, WIDTH, HEIGHT], fill=BG_COLOR)
    # Subtle dot grid
    step = 40
    for x in range(step // 2, WIDTH, step):
        for y in range(step // 2, HEIGHT, step):
            draw.point((x, y), fill=(255, 255, 255, 18))

def draw_pill(draw, x, y, text, font, bg_color, text_color, pad_x=14, pad_y=6):
    bbox = font.getbbox(text)
    w = bbox[2] - bbox[0] + pad_x * 2
    h = bbox[3] - bbox[1] + pad_y * 2
    r = h // 2
    draw.rounded_rectangle([x, y, x + w, y + h], radius=r, fill=bg_color)
    draw.text((x + pad_x, y + pad_y), text, fill=text_color, font=font)
    return w, h

def draw_glass_card(draw, x, y, w, h, radius=16, border_color=(255, 255, 255, 28), fill_color=CARD_BG):
    draw.rounded_rectangle([x, y, x + w, y + h], radius=radius, fill=fill_color, outline=border_color, width=1)

def draw_traffic_lights(draw, x, y):
    draw.ellipse([x, y, x + 12, y + 12], fill=(255, 95, 87))
    draw.ellipse([x + 20, y, x + 32, y + 12], fill=(254, 188, 46))
    draw.ellipse([x + 40, y, x + 52, y + 12], fill=(40, 200, 64))

# Setup ffmpeg output pipe
ffmpeg_cmd = [
    'ffmpeg', '-y',
    '-f', 'rawvideo',
    '-vcodec', 'rawvideo',
    '-s', f'{WIDTH}x{HEIGHT}',
    '-pix_fmt', 'rgb24',
    '-r', str(FPS),
    '-i', '-',
]

if os.path.exists(AUDIO_PATH):
    ffmpeg_cmd.extend(['-i', AUDIO_PATH, '-c:a', 'aac', '-b:a', '192k'])

ffmpeg_cmd.extend([
    '-c:v', 'libx264',
    '-pix_fmt', 'yuv420p',
    '-preset', 'fast',
    '-crf', '18',
    '-shortest',
    OUTPUT_VIDEO
])

print("Launching ffmpeg video encoder...")
pipe = subprocess.Popen(ffmpeg_cmd, stdin=subprocess.PIPE)

print(f"Rendering {TOTAL_FRAMES} frames (~26 seconds @ 30 fps)...")

for frame_idx in range(TOTAL_FRAMES):
    t_sec = frame_idx / FPS
    img = Image.new("RGB", (WIDTH, HEIGHT), BG_COLOR)
    draw = ImageDraw.Draw(img, "RGBA")
    draw_grid_background(draw)

    # ----------------------------------------------------
    # SCENE 1: (0.0s to 5.0s, frames 0 - 150) - The Problem
    # ----------------------------------------------------
    if frame_idx < 150:
        p = frame_idx / 150.0
        intro_alpha = min(1.0, frame_idx / 30.0)

        # Icon and Header
        if app_icon:
            icon_size = 96
            res_icon = app_icon.resize((icon_size, icon_size), Image.Resampling.LANCZOS)
            img.paste(res_icon, (WIDTH // 2 - icon_size // 2, 120), res_icon)

        draw.text((WIDTH // 2 - 60, 235), "Crucial", fill=TEXT_PRIMARY, font=font_h2)
        draw.text((WIDTH // 2 - 130, 290), "STORAGE INTELLIGENCE FOR macOS", fill=ACCENT, font=font_small)

        # Floating Clutter Cards animating in
        cards = [
            ("node_modules (Developer Cache)", "14.8 GB", ACCENT, 340, 390, 0.15),
            ("Application Support (Spotify Clutter)", "1.19 GB", HONEY, 1140, 390, 0.25),
            ("APFS Local Snapshots (Hidden Storage)", "18.2 GB", CRIMSON, 360, 600, 0.35),
            ("Duplicate Video Dumps (SHA-256)", "4.3 GB", (150, 130, 240), 1160, 600, 0.45),
        ]

        for title, size, tag_color, tx, ty, start_p in cards:
            card_p = max(0.0, min(1.0, (p - start_p) * 4.0))
            if card_p > 0:
                e = ease_out_cubic(card_p)
                cur_y = int(ty + (1 - e) * 60)
                card_w, card_h = 440, 110
                draw_glass_card(draw, tx, cur_y, card_w, card_h)

                # Dot
                draw.ellipse([tx + 20, cur_y + 24, tx + 32, cur_y + 36], fill=tag_color)
                draw.text((tx + 44, cur_y + 20), title, fill=TEXT_PRIMARY, font=font_body)
                draw.text((tx + 44, cur_y + 54), f"Unverified Junk • Reclaimable", fill=TEXT_MUTED, font=font_small)
                draw.text((tx + card_w - 110, cur_y + 40), size, fill=TEXT_PRIMARY, font=font_h3)

        # Lower third
        lt_p = min(1.0, max(0.0, (p - 0.5) * 3.0))
        if lt_p > 0:
            e = ease_out_cubic(lt_p)
            draw.text((120, int(860 - (1 - e) * 20)), "One Mac. Cluttered everywhere.", fill=TEXT_PRIMARY, font=font_hero)
            draw.text((120, int(940 - (1 - e) * 20)), "Caches, orphaned residue, and hidden APFS snapshots silently eating storage.", fill=TEXT_MUTED, font=font_h3)

    # ----------------------------------------------------
    # SCENE 2: (5.0s to 11.0s, frames 150 - 330) - App Uninstaller
    # ----------------------------------------------------
    elif frame_idx < 330:
        p = (frame_idx - 150) / 180.0
        e = ease_out_cubic(min(1.0, p * 2.0))

        # macOS Window
        win_w, win_h = 1380, 740
        win_x = (WIDTH - win_w) // 2
        win_y = int(90 + (1 - e) * 40)

        draw_glass_card(draw, win_x, win_y, win_w, win_h, radius=18, border_color=(255, 255, 255, 40), fill_color=(18, 17, 26))
        draw_traffic_lights(draw, win_x + 20, win_y + 20)

        # Window Titlebar
        draw.text((win_x + 80, win_y + 16), "Crucial — App Uninstaller", fill=TEXT_MUTED, font=font_small)

        # Draw left sidebar
        sidebar_w = 340
        draw.rounded_rectangle([win_x, win_y + 50, win_x + sidebar_w, win_y + win_h], radius=0, fill=(14, 13, 20))
        draw.line([win_x + sidebar_w, win_y + 50, win_x + sidebar_w, win_y + win_h], fill=(255, 255, 255, 18), width=1)

        # Sidebar items
        sb_apps = [
            ("Dia", "7.35 GB", False),
            ("Claude", "1.84 GB", True),
            ("ChatGPT", "1.47 GB", False),
            ("pgAdmin 4", "901.9 MB", False),
            ("Spotify", "524.2 MB", False)
        ]
        s_y = win_y + 70
        for name, sz, is_sel in sb_apps:
            if is_sel:
                draw.rounded_rectangle([win_x + 12, s_y, win_x + sidebar_w - 12, s_y + 50], radius=8, fill=(28, 27, 40), outline=ACCENT, width=1)
                draw.text((win_x + 30, s_y + 14), name, fill=TEXT_PRIMARY, font=font_body)
                draw.text((win_x + sidebar_w - 90, s_y + 14), sz, fill=ACCENT, font=font_body)
            else:
                draw.text((win_x + 30, s_y + 14), name, fill=TEXT_MUTED, font=font_body)
                draw.text((win_x + sidebar_w - 90, s_y + 14), sz, fill=TEXT_FAINT, font=font_body)
            s_y += 58

        # Main pane: Selected App (Claude)
        mp_x = win_x + sidebar_w + 30
        draw.text((mp_x, win_y + 70), "Claude", fill=TEXT_PRIMARY, font=font_h2)
        draw.text((mp_x + 180, win_y + 80), "v4.4212.0  •  User App", fill=ACCENT, font=font_small)
        draw.text((mp_x, win_y + 125), "com.anthropic.claudefordesktop • /Applications/Claude.app", fill=TEXT_MUTED, font=font_small)

        # Big Stat
        draw.text((win_x + win_w - 240, win_y + 65), "1.84 GB", fill=ACCENT, font=font_h2)
        draw.text((win_x + win_w - 240, win_y + 115), "7 items selected", fill=TEXT_MUTED, font=font_small)

        # Residue items table
        res_items = [
            ("Claude.app (Application Bundle)", "647.2 MB", "Application"),
            ("Application Support/Claude", "1.19 GB", "Support"),
            ("Caches/claude-cli-nodejs", "325 KB", "Caches"),
            ("Caches/com.anthropic.claudefordesktop", "1.1 MB", "Caches"),
            ("Preferences/com.anthropic.claudefordesktop.plist", "1 KB", "Preferences"),
            ("HTTPStorages/com.anthropic.claudefordesktop", "296 KB", "Storage"),
        ]

        r_y = win_y + 170
        for r_name, r_sz, r_cat in res_items:
            draw.rounded_rectangle([mp_x, r_y, win_x + win_w - 30, r_y + 44], radius=6, fill=(24, 23, 34), outline=(255, 255, 255, 14), width=1)
            # Emerald Checkbox
            draw.ellipse([mp_x + 12, r_y + 13, mp_x + 30, r_y + 31], fill=ACCENT)
            draw.text((mp_x + 45, r_y + 12), r_name, fill=TEXT_PRIMARY, font=font_small)
            draw.text((win_x + win_w - 130, r_y + 12), r_sz, fill=TEXT_MUTED, font=font_small)
            r_y += 52

        # Bottom Action Button
        btn_y = win_y + win_h - 70
        draw.rounded_rectangle([win_x + win_w - 260, btn_y, win_x + win_w - 30, btn_y + 46], radius=23, fill=ACCENT)
        draw.text((win_x + win_w - 225, btn_y + 12), "Move to Trash (1.84 GB)", fill=(255, 255, 255), font=font_body)

        # Lower third
        draw.text((120, 890), "Deep Uninstaller. 10 Library Targets.", fill=TEXT_PRIMARY, font=font_hero)
        draw.text((120, 970), "Traces containers, caches, and plists with safe dual-tier macOS Trash staging.", fill=TEXT_MUTED, font=font_h3)

    # ----------------------------------------------------
    # SCENE 3: (11.0s to 17.0s, frames 330 - 510) - Offline Local LLM
    # ----------------------------------------------------
    elif frame_idx < 510:
        p = (frame_idx - 330) / 180.0
        e = ease_out_cubic(min(1.0, p * 2.0))

        # Terminal / Chat Window
        box_w, box_h = 1380, 720
        bx = (WIDTH - box_w) // 2
        by = int(100 + (1 - e) * 40)

        draw_glass_card(draw, bx, by, box_w, box_h, radius=18, border_color=ACCENT, fill_color=(15, 16, 24))
        draw_traffic_lights(draw, bx + 24, by + 24)

        # Window Title
        draw.text((bx + 85, by + 20), "Crucial Assistant — 100% Offline Llama 3.2 1B (Metal)", fill=TEXT_MUTED, font=font_small)
        draw_pill(draw, bx + box_w - 240, by + 16, "47.5 tokens/sec", font_small, ACCENT, (255, 255, 255), pad_x=12, pad_y=4)

        # User Question
        user_box_y = by + 80
        draw_glass_card(draw, bx + 50, user_box_y, box_w - 100, 60, radius=8, fill_color=(24, 25, 38))
        draw.text((bx + 75, user_box_y + 18), "User: What is node_modules, why is it 14.8 GB, and what happens if I delete it?", fill=TEXT_PRIMARY, font=font_body)

        # Streaming Assistant Response
        ai_box_y = user_box_y + 85
        full_text = (
            "Crucial Assistant:\n\n"
            "• Identification: node_modules contains third-party JavaScript package dependencies for your local project.\n"
            "• Origin: Created by npm / yarn / pnpm install.\n"
            "• Impact of Deletion: Completely safe. No system or personal code is affected.\n"
            "• Regeneration: Run 'npm install' in the project directory anytime to restore.\n\n"
            "Confidence: 100%  •  Vitality Score: 0/100 (Safe to Trash)  •  Reclaimable: 14.8 GB"
        )

        # Animate typewriter
        chars_to_show = int(len(full_text) * min(1.0, p * 1.5))
        current_text = full_text[:chars_to_show]

        draw_glass_card(draw, bx + 50, ai_box_y, box_w - 100, 440, radius=12, fill_color=(18, 20, 32))
        draw.text((bx + 80, ai_box_y + 30), current_text, fill=TEXT_PRIMARY, font=font_body)

        # Blinking cursor
        if int(frame_idx / 8) % 2 == 0:
            cursor_y = ai_box_y + 30 + (current_text.count("\n") * 28)
            draw.rectangle([bx + 80, cursor_y, bx + 92, cursor_y + 22], fill=ACCENT)

        # Lower third
        draw.text((120, 890), "100% Offline Local AI. Zero Cloud.", fill=TEXT_PRIMARY, font=font_hero)
        draw.text((120, 970), "Explains every file, its origin, and deletion risk with on-device Metal acceleration.", fill=TEXT_MUTED, font=font_h3)

    # ----------------------------------------------------
    # SCENE 4: (17.0s to 21.5s, frames 510 - 645) - Performance & Benchmarks
    # ----------------------------------------------------
    elif frame_idx < 645:
        p = (frame_idx - 510) / 135.0
        e = ease_out_cubic(min(1.0, p * 2.0))

        # 4 Metric Bento Cards
        metrics = [
            ("2,163 MB/s", "Hardware SHA-256", "Progressive duplicate verification with zero false positives.", ACCENT, 160, 140),
            ("0 MB", "Background RAM", "Zero background daemons, zero menu bar pollers when closed.", HONEY, 980, 140),
            ("47.5 t/s", "Local Generation", "Real-time streaming via Apple Silicon Metal shaders.", (150, 130, 240), 160, 440),
            ("5.7 MB", "Binary Footprint", "100% native Swift & AppKit. No Electron, no web wrappers.", CRIMSON, 980, 440),
        ]

        for val, title, desc, col, mx, my in metrics:
            cur_y = int(my + (1 - e) * 40)
            draw_glass_card(draw, mx, cur_y, 780, 240, radius=16, border_color=(255, 255, 255, 24))
            draw.text((mx + 40, cur_y + 30), val, fill=col, font=font_large_stat)
            draw.text((mx + 40, cur_y + 130), title, fill=TEXT_PRIMARY, font=font_h3)
            draw.text((mx + 40, cur_y + 175), desc, fill=TEXT_MUTED, font=font_body)

        # Lower third
        draw.text((120, 890), "Hardware Accelerated. Zero Background Bloat.", fill=TEXT_PRIMARY, font=font_hero)
        draw.text((120, 970), "Blazing fast native disk operations without draining your Mac's battery or RAM.", fill=TEXT_MUTED, font=font_h3)

    # ----------------------------------------------------
    # SCENE 5: (21.5s to 26.0s, frames 645 - 780) - Outro & CTA
    # ----------------------------------------------------
    else:
        p = (frame_idx - 645) / 135.0
        e = ease_out_cubic(min(1.0, p * 2.0))

        # Centered Icon
        if app_icon:
            icon_size = int(140 + (1 - e) * 30)
            res_icon = app_icon.resize((icon_size, icon_size), Image.Resampling.LANCZOS)
            img.paste(res_icon, (WIDTH // 2 - icon_size // 2, 230), res_icon)

        # Typography
        draw.text((WIDTH // 2 - 120, 400), "Crucial", fill=TEXT_PRIMARY, font=font_hero)
        draw.text((WIDTH // 2 - 270, 480), "Storage Intelligence for macOS", fill=ACCENT, font=font_h2)
        draw.text((WIDTH // 2 - 380, 550), "Crafted in the Things 3 design language • 100% Offline Local AI", fill=TEXT_MUTED, font=font_h3)

        # Button Pill
        btn_w, btn_h = 440, 64
        bx, by = (WIDTH - btn_w) // 2, 630
        draw.rounded_rectangle([bx, by, bx + btn_w, by + btn_h], radius=32, fill=ACCENT)
        draw.text((bx + 60, by + 18), "Download DMG on GitHub", fill=(255, 255, 255), font=font_h3)

        # Subtext URL
        draw.text((WIDTH // 2 - 130, 725), "github.com/Yprnv7/crucial", fill=TEXT_MUTED, font=font_body)
        draw.text((WIDTH // 2 - 230, 765), "macOS 14+ Sonoma & Sequoia • Apple Silicon", fill=TEXT_FAINT, font=font_small)

    # Send RGB frame to ffmpeg stdin
    pipe.stdin.write(img.tobytes())

    if frame_idx % 60 == 0:
        print(f"Rendered {frame_idx}/{TOTAL_FRAMES} frames ({int(frame_idx/TOTAL_FRAMES*100)}%)...")

pipe.stdin.close()
pipe.wait()
print("Video render complete! Output saved to:", OUTPUT_VIDEO)
