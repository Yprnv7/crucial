import os
import shutil
import subprocess
from PIL import Image, ImageDraw, ImageFilter

def create_mac_icon(input_path, output_icns_path):
    src = Image.open(input_path).convert("RGBA")
    
    # Standard macOS icon grid: 1024x1024 canvas with squircle centered at ~824x824
    # Let's crop/fit the squircle from the input image
    # If the input already has a squircle rendered in the center, we crop the central 824x824 or fit it nicely
    W, H = src.size
    
    # We want a clean 1024x1024 canvas with transparent background
    canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    
    # Squircle dimensions: 824 x 824, centered at (100, 100)
    # Apple squircle corner radius is approx 185 px on 824x824
    # We create a mask with anti-aliasing
    scale = 4
    mask_w, mask_h = 824 * scale, 824 * scale
    radius = int(185 * scale)
    
    mask = Image.new("L", (mask_w, mask_h), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([0, 0, mask_w - 1, mask_h - 1], radius=radius, fill=255)
    
    mask = mask.resize((824, 824), Image.Resampling.LANCZOS)
    
    # Crop the central region of the source artwork (where the icon is rendered)
    # If the image is 1024x1024 with a centered squircle, let's crop the center 860x860 and resize to 824x824
    crop_box = ((W - 840) // 2, (H - 840) // 2, (W + 840) // 2, (H + 840) // 2)
    icon_face = src.crop(crop_box).resize((824, 824), Image.Resampling.LANCZOS)
    
    # Apply squircle mask to the icon face
    icon_face.putalpha(mask)
    
    # Create subtle macOS drop shadow
    shadow = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    shadow_mask = Image.new("RGBA", (824, 824), (0, 0, 0, 140))
    shadow_mask.putalpha(mask)
    shadow.paste(shadow_mask, (100, 108)) # offset downward by 8px
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=18))
    
    # Composite shadow and icon onto canvas
    canvas = Image.alpha_composite(canvas, shadow)
    canvas.paste(icon_face, (100, 100), icon_face)
    
    # Ensure resources and iconset directories exist
    iconset_dir = "/tmp/AppIcon.iconset"
    if os.path.exists(iconset_dir):
        shutil.rmtree(iconset_dir)
    os.makedirs(iconset_dir)
    
    sizes = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]
    
    for filename, sz in sizes:
        resized = canvas.resize((sz, sz), Image.Resampling.LANCZOS)
        resized.save(os.path.join(iconset_dir, filename))
        
    # Run iconutil
    subprocess.run(["iconutil", "-c", "icns", iconset_dir, "-o", output_icns_path], check=True)
    print(f"Successfully generated macOS icns at: {output_icns_path}")

if __name__ == "__main__":
    src_img = "/Users/py/.gemini/antigravity/brain/00ae5fcb-d908-4b18-b30f-492f2b51b4f0/crucial_app_icon_1795358578772.jpg"
    out_icns = "/Users/py/.gemini/antigravity/scratch/crucial/resources/AppIcon.icns"
    os.makedirs("/Users/py/.gemini/antigravity/scratch/crucial/resources", exist_ok=True)
    create_mac_icon(src_img, out_icns)
