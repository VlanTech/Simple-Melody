#!/usr/bin/env python3
"""Resize downloaded icons into macOS .iconset standard sizes."""
import os
from pathlib import Path
from PIL import Image

ICONS_DIR = Path("/Users/vlan_channel/.minimax-agent-cn/projects/SimpleMelody/SimpleMelody/Resources/Assets.xcassets")
SOURCE = ICONS_DIR / "AppIcon.appiconset" / "source_1024.png"

# macOS .iconset standard sizes (base size, @2x for retina)
ICON_SIZES = [
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

def resize_app_icon():
    src = Image.open(SOURCE).convert("RGBA")
    print(f"Source size: {src.size}")
    icon_dir = ICONS_DIR / "AppIcon.appiconset"
    for name, size in ICON_SIZES:
        img = src.resize((size, size), Image.LANCZOS)
        out = icon_dir / name
        img.save(out, "PNG", optimize=True)
        print(f"  -> {name} ({size}x{size})")

def resize_ui_icon(src_name, out_name, max_size=256):
    src = Image.open(ICONS_DIR / src_name).convert("RGBA")
    w, h = src.size
    scale = max_size / max(w, h)
    if scale < 1:
        new_size = (int(w * scale), int(h * scale))
        src = src.resize(new_size, Image.LANCZOS)
    out = ICONS_DIR / out_name
    src.save(out, "PNG", optimize=True)
    print(f"  UI {src_name} -> {out_name} ({src.size[0]}x{src.size[1]})")

if __name__ == "__main__":
    print("== Generating App Icon .iconset ==")
    resize_app_icon()
    print("\n== Generating UI icons ==")
    resize_ui_icon("logo_monogram.png", "logo_monogram.png", 256)
    resize_ui_icon("section_marker.png", "section_marker.png", 256)
    resize_ui_icon("pronunciation.png", "pronunciation.png", 256)
    resize_ui_icon("idea_lightbulb.png", "idea_lightbulb.png", 256)
    print("\nDone!")
