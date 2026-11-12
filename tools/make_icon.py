"""Generate the 1024x1024 app icon for DSHMobile (App Store-format, opaque RGB)."""
from PIL import Image, ImageDraw, ImageFilter
import math
import os

S = 1024
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                   "Resources", "Assets.xcassets", "AppIcon.appiconset", "icon-1024.png")

img = Image.new("RGB", (S, S), (10, 11, 14))
d = ImageDraw.Draw(img)

# Vertical gradient background.
top = (24, 27, 34)
bottom = (8, 9, 12)
for y in range(S):
    t = y / (S - 1)
    c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
    d.line([(0, y), (S, y)], fill=c)

# Soft cyan glow behind the prompt glyph.
glow = Image.new("RGB", (S, S), (0, 0, 0))
gd = ImageDraw.Draw(glow)
gd.ellipse([S * 0.16, S * 0.20, S * 0.84, S * 0.80], fill=(0, 62, 74))
glow = glow.filter(ImageFilter.GaussianBlur(S * 0.10))
img = Image.blend(img, Image.blend(img, glow, 0.55), 0.75)
d = ImageDraw.Draw(img)

# Inner rounded frame.
pad = S * 0.10
d.rounded_rectangle([pad, pad, S - pad, S - pad], radius=S * 0.19,
                    outline=(90, 96, 110), width=int(S * 0.008))

# Terminal chevron ">".
cyan = (34, 224, 214)
stroke = int(S * 0.052)
cx0, cy = S * 0.36, S * 0.47
arm = S * 0.115
d.line([(cx0, cy - arm), (cx0 + arm, cy)], fill=cyan, width=stroke, joint="curve")
d.line([(cx0 + arm, cy), (cx0, cy + arm)], fill=cyan, width=stroke, joint="curve")

# Cursor underscore.
d.rounded_rectangle([S * 0.535, S * 0.545, S * 0.535 + S * 0.185, S * 0.545 + stroke],
                    radius=stroke / 2, fill=(235, 240, 248))

# Three quiet dots: the harness "sessions" row.
for i in range(3):
    x = S * 0.315 + i * S * 0.062
    y = S * 0.70
    r = S * 0.017
    d.ellipse([x - r, y - r, x + r, y + r], fill=(120, 128, 145))

img = img.convert("RGB")
img.save(OUT, "PNG", optimize=True)
print("wrote", OUT, img.size, os.path.getsize(OUT), "bytes")
