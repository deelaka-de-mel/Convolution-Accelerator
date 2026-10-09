import sys
src, dst = sys.argv[1], sys.argv[2]
words = 4096  # 16 KB
data = open(src, "rb").read()
if len(data) > words * 4:
    sys.exit("ERROR: program is %d bytes, RAM is %d bytes" % (len(data), words * 4))
data += b"\x00" * (words * 4 - len(data))
with open(dst, "w") as f:
    for i in range(words):
        w = int.from_bytes(data[i*4:i*4+4], "little")
        f.write("%08x\n" % w)
print("wrote", dst)
