import re, subprocess, sys, time
from PIL import Image

p = subprocess.Popen(["juart-terminal", "-q"],
                     stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                     stderr=subprocess.STDOUT)
print("Waiting for board...")

rows, chk = [], None
while True:
    line = p.stdout.readline()
    if not line:
        sys.exit("nios2-terminal exited (is the board programmed and connected?)")
    s = line.decode(errors="ignore").strip()
    if re.fullmatch(r"[0-9A-F]{128}", s):
        rows.append(bytes.fromhex(s))
    elif re.fullmatch(r"S[0-9A-F]{2}", s):
        chk = int(s[1:], 16)
        break

data = b"".join(rows)
ok = len(rows) == 64 and chk is not None and (sum(data) & 0xFF) == chk
if ok:
    Image.frombytes("L", (64, 64), data).save("output.png")
    print("Saved output.png")
else:
    print("Transfer error")

p.stdin.write(b"K" if ok else b"E")
p.stdin.flush()
time.sleep(2)
p.terminate()