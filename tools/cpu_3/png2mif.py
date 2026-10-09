from PIL import Image

def png_to_mif(png_path, mif_path):
    img = Image.open(png_path).convert('L') # Grayscale
    img = img.resize((64, 64))            # 256x256 pixels
    pixels = list(img.getdata())

    depth = len(pixels) // 4  # 65536 words (4 pixels per 32-bit word)

    with open(mif_path, 'w') as f:
        f.write(f"DEPTH = {depth};\n")
        f.write("WIDTH = 32;\n")
        f.write("ADDRESS_RADIX = HEX;\n")
        f.write("DATA_RADIX = HEX;\n")
        f.write("CONTENT BEGIN\n")

        for idx in range(depth):
            p0 = pixels[idx * 4 + 0]
            p1 = pixels[idx * 4 + 1]
            p2 = pixels[idx * 4 + 2]
            p3 = pixels[idx * 4 + 3]

            # Pack 4 pixels Little-Endian: [Pixel3][Pixel2][Pixel1][Pixel0]
            word = (p3 << 24) | (p2 << 16) | (p1 << 8) | p0
            f.write(f"    {idx:04X} : {word:08X};\n")

        f.write("END;\n")

    print(f"Successfully generated {mif_path} ({depth} words)")

if __name__ == "__main__":
    png_to_mif("tools\\cpu_3\\input.png", "image.mif")