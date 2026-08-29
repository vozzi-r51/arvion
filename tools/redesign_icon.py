"""Generate a stylized 'B' launcher icon for DukanEdge.

Outputs:
  assets/icon/app_icon.png            (1024x1024 master)
  assets/icon/adaptive_foreground.png (432x432 foreground, transparent bg)
  assets/icon/adaptive_background.png (1024x1024 solid dark navy)

The design is a clean, friendly serif 'B' with two stacked rounded bowls,
matching the visual language of the previous 'A' (blue accent + light blue
'checkmark' interior detail) so the new app icon reads as a member of the
same family.
"""
from PIL import Image, ImageDraw

# Palette (matches the existing 'A' family).
BLUE = (47, 99, 244, 255)        # primary blue
LIGHT_BLUE = (96, 165, 250, 255)  # light blue accent
BG = (24, 28, 48, 255)            # dark navy adaptive background


def make_master(size=1024):
    """Master icon (square) used for all mipmap generations."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Bounding box for the B letter, inset so it sits inside the safe zone.
    inset = int(size * 0.16)
    left, top = inset, inset
    right, bottom = size - inset, size - inset
    w = right - left
    h = bottom - top

    stroke = int(size * 0.16)  # thickness of the B strokes

    # Vertical stem (left side of the B).
    stem_right = left + stroke
    draw.rectangle([left, top, stem_right, bottom], fill=BLUE)

    # Top bowl: rounded rectangle on the right half of the top section.
    bowl_top = top
    bowl_top_bottom = top + h // 2
    bowl_left = stem_right
    bowl_right = right
    bowl_w = bowl_right - bowl_left
    bowl_h = bowl_top_bottom - bowl_top
    # outer top bowl
    draw.rounded_rectangle(
        [bowl_left, bowl_top, bowl_right, bowl_top_bottom],
        radius=bowl_h // 2,
        fill=BLUE,
    )
    # inner cutout (top bowl) — makes it a hollow bowl
    inner_pad_top = int(size * 0.07)
    inner_pad_horiz = int(size * 0.07)
    draw.rounded_rectangle(
        [
            bowl_left + inner_pad_horiz,
            bowl_top + inner_pad_top,
            bowl_right - inner_pad_horiz,
            bowl_top_bottom - inner_pad_horiz,
        ],
        radius=(bowl_h - 2 * inner_pad_horiz) // 2,
        fill=(0, 0, 0, 0),
    )

    # Bottom bowl: larger, slightly longer than the top bowl — classic B shape.
    bowl2_top = top + h // 2
    bowl2_bottom = bottom
    # outer bottom bowl
    draw.rounded_rectangle(
        [bowl_left, bowl2_top, bowl_right, bowl2_bottom],
        radius=(bowl2_bottom - bowl2_top) // 2,
        fill=BLUE,
    )
    # inner cutout (bottom bowl)
    inner_pad_bottom = int(size * 0.07)
    draw.rounded_rectangle(
        [
            bowl_left + inner_pad_horiz,
            bowl2_top + inner_pad_horiz,
            bowl_right - inner_pad_horiz,
            bowl2_bottom - inner_pad_bottom,
        ],
        radius=(bowl2_bottom - bowl2_top - 2 * inner_pad_horiz) // 2,
        fill=(0, 0, 0, 0),
    )

    # Light-blue accent ribbon (matches the A's accent ribbon).
    ribbon_pad = int(size * 0.05)
    draw.rounded_rectangle(
        [
            left + ribbon_pad,
            top + int(h * 0.45),
            right - ribbon_pad,
            top + int(h * 0.55),
        ],
        radius=int(size * 0.04),
        fill=LIGHT_BLUE,
    )

    return img


def make_foreground(size=432):
    """Adaptive icon foreground — same B, transparent background."""
    master = make_master(size * 2)  # render larger and downscale for crisp edges
    # Center on a transparent canvas of `size`.
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    # Scale master to ~60% of the canvas (adaptive icon safe zone).
    fg = master.resize((int(size * 0.7), int(size * 0.7)), Image.LANCZOS)
    canvas.paste(fg, ((size - fg.width) // 2, (size - fg.height) // 2), fg)
    return canvas


def make_background(size=1024):
    """Adaptive icon background — solid dark navy."""
    img = Image.new("RGBA", (size, size), BG)
    return img


if __name__ == "__main__":
    out_dir = "assets/icon"
    master = make_master(1024)
    master.save(f"{out_dir}/app_icon.png")
    fg = make_foreground(432)
    fg.save(f"{out_dir}/adaptive_foreground.png")
    bg = make_background(1024)
    bg.save(f"{out_dir}/adaptive_background.png")
    print("Wrote: app_icon.png, adaptive_foreground.png, adaptive_background.png")
