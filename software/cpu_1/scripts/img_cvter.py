from PIL import Image

# Open image, convert to 8-bit grayscale, and resize to 64x64
img = Image.open("input.png").convert("L").resize((64, 64))
pixels = list(img.getdata())

# Save to image.hex (1024 lines)
with open("image.hex", "w") as f:
    for i in range(0, len(pixels), 4):
        p0, p1, p2, p3 = pixels[i : i + 4]
        # Pack 4 pixels into 32-bit word
        word = (p3 << 24) | (p2 << 16) | (p1 << 8) | p0
        f.write(f"{word:08x}\n")

print("Generated 64x64 image.hex with 1024 words.")