#!/usr/bin/env python3
"""Builds the sample sheet of the icons: each one at 4x (not smoothed) and at real size,
grouped by kit, over the editor's dark and light backgrounds.

Reads manifest.tsv (generate.lua writes it) and the generated SVGs. Needs Pillow.

Usage, from the repo root:  python3 tools/icons/preview.py <out.png> [pages]
With more than one page it writes <out>.png, <out>-2.png, <out>-3.png.
It always adds <out>-tree.png: every icon at real size with its name, the way the scene
tree shows them.
"""
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
MANIFEST = os.path.join(ROOT, "tools", "icons", "manifest.tsv")

SCALE = 4
COLUMNS = 6
CELL_W, CELL_H = 132, 96
HEADER_H = 30
MARGIN = 16
THEMES = [
    {"name": "dark theme", "back": "#202531", "text": "#cdd3de", "dim": "#7f8899"},
    {"name": "light theme", "back": "#e9eaee", "text": "#2b3040", "dim": "#70778a"},
]
RECT = re.compile(r'<rect x="(\d+)" y="(\d+)" width="(\d+)" height="(\d+)" fill="(#[0-9A-Fa-f]{6})"')


def load_font(size):
    for path in ("/System/Library/Fonts/Helvetica.ttc", "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def read_svg(path):
    """Aseprite's SVGs are only pixel rectangles: they are read without a rasterizer."""
    image = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    with open(path, encoding="utf-8") as handle:
        for x, y, width, height, fill in RECT.findall(handle.read()):
            color = tuple(int(fill[i:i + 2], 16) for i in (1, 3, 5)) + (255,)
            image.paste(color, (int(x), int(y), int(x) + int(width), int(y) + int(height)))
    return image


def read_manifest():
    kits = []
    with open(MANIFEST, encoding="utf-8") as handle:
        next(handle)
        for line in handle:
            kit, name, kind, _base, _script, icon, _glyph, _mark = line.rstrip("\n").split("\t")
            if not kits or kits[-1]["id"] != kit:
                found = next((k for k in kits if k["id"] == kit), None)
                if found is None:
                    found = {"id": kit, "name": kit, "icons": []}
                    kits.append(found)
            else:
                found = kits[-1]
            if kind == "emblem":
                found["name"] = name
                found["icons"].insert(0, ("(emblem)", icon, kind))
            else:
                found["icons"].append((name, icon, kind))
    return kits


def kit_height(kit):
    rows = -(-len(kit["icons"]) // COLUMNS)
    return HEADER_H + rows * CELL_H


def draw_kit(sheet, draw, kit, left, top, theme, fonts):
    count = len(kit["icons"]) - 1
    draw.text((left, top + 6), f"{kit['name']}  ·  {count} class{'' if count == 1 else 'es'}", fill=theme["text"], font=fonts[0])
    for index, (name, icon, kind) in enumerate(kit["icons"]):
        x = left + (index % COLUMNS) * CELL_W
        y = top + HEADER_H + (index // COLUMNS) * CELL_H
        image = read_svg(os.path.join(ROOT, icon))
        big = image.resize((16 * SCALE, 16 * SCALE), Image.NEAREST)
        sheet.paste(big, (x, y), big)
        sheet.paste(image, (x + 16 * SCALE + 12, y + 24), image)
        label = name if kind != "resource" else name + " ·r"
        draw.text((x, y + 16 * SCALE + 6), label, fill=theme["text"] if kind != "emblem" else theme["dim"], font=fonts[1])


def draw_tree(target, kits, fonts):
    """Every icon at 16 px with its name, in columns, over both backgrounds."""
    rows = [(name if kind != "emblem" else kit["name"], icon) for kit in kits for name, icon, kind in kit["icons"]]
    columns, row_h, column_w = 4, 22, 196
    per_column = -(-len(rows) // columns)
    panel_w = columns * column_w + MARGIN * 2
    height = per_column * row_h + MARGIN * 2 + 24
    sheet = Image.new("RGB", (panel_w * len(THEMES), height), "#000000")
    draw = ImageDraw.Draw(sheet)
    for theme_index, theme in enumerate(THEMES):
        left = theme_index * panel_w
        draw.rectangle((left, 0, left + panel_w, height), fill=theme["back"])
        draw.text((left + MARGIN, 10), f"{theme['name']}  ·  real size (16 px)", fill=theme["dim"], font=fonts[1])
        for index, (name, icon) in enumerate(rows):
            x = left + MARGIN + (index // per_column) * column_w
            y = MARGIN + 24 + (index % per_column) * row_h
            image = read_svg(os.path.join(ROOT, icon))
            sheet.paste(image, (x, y), image)
            draw.text((x + 22, y + 2), name, fill=theme["text"], font=fonts[1])
    sheet.save(target)
    print(f"{target}  {sheet.width} x {sheet.height}")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    target = sys.argv[1]
    pages = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    kits = read_manifest()
    fonts = (load_font(15), load_font(11))

    total = sum(kit_height(kit) for kit in kits)
    groups, current, used = [], [], 0
    for kit in kits:
        height = kit_height(kit)
        if current and len(groups) < pages - 1 and used + height / 2 > total / pages:
            groups.append(current)
            current, used = [], 0
        current.append(kit)
        used += height
    groups.append(current)

    panel_w = COLUMNS * CELL_W + MARGIN * 2
    stem, extension = os.path.splitext(target)
    for number, group in enumerate(groups, start=1):
        height = sum(kit_height(kit) for kit in group) + MARGIN * 2 + 24
        sheet = Image.new("RGB", (panel_w * len(THEMES), height), "#000000")
        draw = ImageDraw.Draw(sheet)
        for theme_index, theme in enumerate(THEMES):
            left = theme_index * panel_w
            draw.rectangle((left, 0, left + panel_w, height), fill=theme["back"])
            draw.text((left + MARGIN, 10), f"{theme['name']}  ·  4x and real size  ·  \"·r\" = Resource", fill=theme["dim"], font=fonts[1])
            top = MARGIN + 24
            for kit in group:
                draw_kit(sheet, draw, kit, left + MARGIN, top, theme, fonts)
                top += kit_height(kit)
        path = target if number == 1 else f"{stem}-{number}{extension}"
        sheet.save(path)
        print(f"{path}  {sheet.width} x {sheet.height}")
    draw_tree(f"{stem}-tree{extension}", kits, fonts)
    return 0


if __name__ == "__main__":
    sys.exit(main())
