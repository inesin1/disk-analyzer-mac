import sys
try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("Pillow not installed. Skipping icon generation.")
    sys.exit(0)

def create_icon(filename="icon.png", size=(1024, 1024)):
    # Create a background with a gradient or solid color
    img = Image.new("RGBA", size, (255, 255, 255, 0))
    draw = ImageDraw.Draw(img)

    # Draw rounded rectangle background (macOS style)
    padding = 64
    r = 225 # radius
    x0, y0 = padding, padding
    x1, y1 = size[0] - padding, size[1] - padding

    # Outer background
    draw.rounded_rectangle([x0, y0, x1, y1], radius=r, fill=(240, 240, 245))

    # Draw a stylized "disk" and treemap
    # Inner rectangle
    inner_padding = 128
    ix0, iy0 = inner_padding, inner_padding
    ix1, iy1 = size[0] - inner_padding, size[1] - inner_padding

    # Treemap colors
    colors = [(255, 99, 71), (100, 149, 237), (60, 179, 113), (255, 215, 0), (147, 112, 219)]

    # Draw some blocks
    # Block 1
    draw.rectangle([ix0, iy0, ix0 + 400, iy0 + 500], fill=colors[0], outline=(0,0,0), width=8)
    # Block 2
    draw.rectangle([ix0 + 400, iy0, ix1, iy0 + 300], fill=colors[1], outline=(0,0,0), width=8)
    # Block 3
    draw.rectangle([ix0 + 400, iy0 + 300, ix1, iy0 + 500], fill=colors[2], outline=(0,0,0), width=8)
    # Block 4
    draw.rectangle([ix0, iy0 + 500, ix0 + 250, iy1], fill=colors[3], outline=(0,0,0), width=8)
    # Block 5
    draw.rectangle([ix0 + 250, iy0 + 500, ix1, iy1], fill=colors[4], outline=(0,0,0), width=8)

    img.save(filename)
    print(f"Created {filename}")

if __name__ == "__main__":
    create_icon()
