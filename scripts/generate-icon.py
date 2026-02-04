#!/usr/bin/env python3
"""
Generate MCP Control app icon
Premium dark style with gradient M - Laravel aesthetic
"""

import subprocess
import sys

# Check for required modules
try:
    from PIL import Image, ImageDraw, ImageFilter, ImageChops
except ImportError:
    print("Installing Pillow...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "Pillow", "-q"])
    from PIL import Image, ImageDraw, ImageFilter

import os
import math

def create_icon(size=1024):
    """Create a premium app icon - gradient M on dark background"""

    # Create base image
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))

    # Colors
    bg_dark = (24, 24, 27)        # Near black, slightly warm
    bg_lighter = (39, 39, 42)     # Subtle gradient target

    # Gradient colors for the M (top to bottom)
    grad_top = (255, 120, 100)     # Coral/salmon - bright and warm
    grad_mid = (255, 65, 55)       # Vibrant red
    grad_bottom = (200, 30, 25)    # Deep red

    corner_radius = int(size * 0.22)

    # Create background with subtle radial gradient
    for y in range(size):
        for x in range(size):
            # Distance from center for radial effect
            dx = (x - size/2) / (size/2)
            dy = (y - size/2) / (size/2)
            dist = math.sqrt(dx*dx + dy*dy)

            # Subtle radial gradient (lighter in center)
            t = min(1.0, dist * 0.7)
            r = int(bg_lighter[0] + (bg_dark[0] - bg_lighter[0]) * t)
            g = int(bg_lighter[1] + (bg_dark[1] - bg_lighter[1]) * t)
            b = int(bg_lighter[2] + (bg_dark[2] - bg_lighter[2]) * t)
            img.putpixel((x, y), (r, g, b, 255))

    # Apply rounded corner mask
    mask = Image.new('L', (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle([0, 0, size, size], radius=corner_radius, fill=255)
    img.putalpha(mask)

    # Create the M shape as a mask for gradient fill
    m_mask = Image.new('L', (size, size), 0)
    m_draw = ImageDraw.Draw(m_mask)

    # M dimensions - bold and confident
    margin_x = int(size * 0.18)
    margin_top = int(size * 0.22)
    margin_bottom = int(size * 0.22)
    stroke = int(size * 0.125)  # Stroke width

    left = margin_x
    right = size - margin_x
    top = margin_top
    bottom = size - margin_bottom
    center_x = size // 2
    v_depth = int(size * 0.28)  # How deep the V goes

    # Draw M as connected polygon for clean shape
    # Outer outline of the M
    m_outer = [
        # Left leg outer
        (left, bottom),
        (left, top),
        # Left diagonal to center
        (left + stroke * 1.1, top),
        (center_x, top + v_depth),
        # Right diagonal from center
        (right - stroke * 1.1, top),
        # Right leg outer
        (right, top),
        (right, bottom),
        # Right leg inner
        (right - stroke, bottom),
        (right - stroke, top + stroke * 0.8),
        # Right inner diagonal
        (center_x, top + v_depth + stroke * 0.7),
        # Left inner diagonal
        (left + stroke, top + stroke * 0.8),
        # Left leg inner
        (left + stroke, bottom),
    ]
    m_draw.polygon(m_outer, fill=255)

    # Create gradient image for the M
    m_gradient = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    for y in range(size):
        # Calculate gradient position (0 at top, 1 at bottom of M)
        if y < top:
            t = 0
        elif y > bottom:
            t = 1
        else:
            t = (y - top) / (bottom - top)

        # Three-point gradient
        if t < 0.5:
            t2 = t * 2
            r = int(grad_top[0] + (grad_mid[0] - grad_top[0]) * t2)
            g = int(grad_top[1] + (grad_mid[1] - grad_top[1]) * t2)
            b = int(grad_top[2] + (grad_mid[2] - grad_top[2]) * t2)
        else:
            t2 = (t - 0.5) * 2
            r = int(grad_mid[0] + (grad_bottom[0] - grad_mid[0]) * t2)
            g = int(grad_mid[1] + (grad_bottom[1] - grad_mid[1]) * t2)
            b = int(grad_mid[2] + (grad_bottom[2] - grad_mid[2]) * t2)

        for x in range(size):
            m_gradient.putpixel((x, y), (r, g, b, 255))

    # Apply M mask to gradient
    m_gradient.putalpha(m_mask)

    # Add subtle glow behind the M
    glow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.polygon(m_outer, fill=(255, 80, 60, 60))
    glow = glow.filter(ImageFilter.GaussianBlur(radius=size * 0.04))

    # Composite: background + glow + M
    img = Image.alpha_composite(img, glow)
    img = Image.alpha_composite(img, m_gradient)

    # Re-apply corner mask to clean up any blur overflow
    img.putalpha(ImageChops.multiply(img.getchannel('A'), mask))

    return img

def generate_all_sizes(base_img, output_dir):
    """Generate all required macOS app icon sizes"""

    sizes = [
        (16, "icon_16x16.png"),
        (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"),
        (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"),
        (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"),
        (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_512x512@2x.png"),
    ]

    os.makedirs(output_dir, exist_ok=True)

    for size, filename in sizes:
        resized = base_img.resize((size, size), Image.Resampling.LANCZOS)
        filepath = os.path.join(output_dir, filename)
        resized.save(filepath, 'PNG')
        print(f"  Created {filename} ({size}x{size})")

    # Also save the full 1024x1024 version
    base_img.save(os.path.join(output_dir, "AppIcon.png"), 'PNG')
    print(f"  Created AppIcon.png (1024x1024)")

def update_contents_json(output_dir):
    """Update the Contents.json for the appiconset"""
    import json

    contents = {
        "images": [
            {"filename": "icon_16x16.png", "idiom": "mac", "scale": "1x", "size": "16x16"},
            {"filename": "icon_16x16@2x.png", "idiom": "mac", "scale": "2x", "size": "16x16"},
            {"filename": "icon_32x32.png", "idiom": "mac", "scale": "1x", "size": "32x32"},
            {"filename": "icon_32x32@2x.png", "idiom": "mac", "scale": "2x", "size": "32x32"},
            {"filename": "icon_128x128.png", "idiom": "mac", "scale": "1x", "size": "128x128"},
            {"filename": "icon_128x128@2x.png", "idiom": "mac", "scale": "2x", "size": "128x128"},
            {"filename": "icon_256x256.png", "idiom": "mac", "scale": "1x", "size": "256x256"},
            {"filename": "icon_256x256@2x.png", "idiom": "mac", "scale": "2x", "size": "256x256"},
            {"filename": "icon_512x512.png", "idiom": "mac", "scale": "1x", "size": "512x512"},
            {"filename": "icon_512x512@2x.png", "idiom": "mac", "scale": "2x", "size": "512x512"},
        ],
        "info": {"author": "xcode", "version": 1}
    }

    with open(os.path.join(output_dir, "Contents.json"), 'w') as f:
        json.dump(contents, f, indent=2)
    print("  Updated Contents.json")

def main():
    print("Generating MCP Control app icon...")

    # Generate the base icon at 1024x1024
    icon = create_icon(1024)

    # Output to the Assets.xcassets directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_dir = os.path.dirname(script_dir)
    output_dir = os.path.join(project_dir, "MCPControl", "Assets.xcassets", "AppIcon.appiconset")

    print(f"Output directory: {output_dir}")

    # Generate all sizes
    generate_all_sizes(icon, output_dir)

    # Update Contents.json
    update_contents_json(output_dir)

    print("\nDone! Rebuild the app in Xcode to see the new icon.")

if __name__ == "__main__":
    main()
