from PIL import Image

# Open image, convert to 8-bit grayscale, and resize to 256x256
img = Image.open("cpu_first_iter/not_directly_needed/input.png").convert("L").resize((256, 256))
pixels = list(img.getdata())

# Save to image.hex (1024 lines)
with open("cpu_first_iter/not_directly_needed/image.hex", "w") as f:
    for i in range(0, len(pixels), 4):
        p0, p1, p2, p3 = pixels[i : i + 4]
        # Pack 4 pixels into 32-bit word
        word = (p3 << 24) | (p2 << 16) | (p1 << 8) | p0
        f.write(f"{word:08x}\n")

print("Generated 64x64 image.hex with 1024 words.")