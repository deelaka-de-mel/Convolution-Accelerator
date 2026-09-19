# Hand-assembler for a tiny RV32I test program (no toolchain available in sandbox).
# Generates the instruction words for tb_soc_top.sv's initial memory load.

def r_type(funct7, rs2, rs1, funct3, rd, opcode):
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def i_type(imm, rs1, funct3, rd, opcode):
    imm &= 0xFFF
    return (imm << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def s_type(imm, rs2, rs1, funct3, opcode):
    imm &= 0xFFF
    imm11_5 = (imm >> 5) & 0x7F
    imm4_0 = imm & 0x1F
    return (imm11_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm4_0 << 7) | opcode

def u_type(imm, rd, opcode):
    return (imm & 0xFFFFF000) | (rd << 7) | opcode

def b_type(imm, rs2, rs1, funct3, opcode):
    # imm is byte offset, must be even
    imm &= 0x1FFE
    b12 = (imm >> 12) & 1
    b10_5 = (imm >> 5) & 0x3F
    b4_1 = (imm >> 1) & 0xF
    b11 = (imm >> 11) & 1
    return (b12 << 31) | (b10_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (b4_1 << 8) | (b11 << 7) | opcode

# opcodes
OP_LUI    = 0b0110111
OP_ADDI_ETC = 0b0010011
OP_STORE  = 0b0100011
OP_LOAD   = 0b0000011
OP_BRANCH = 0b1100011
OP_JAL    = 0b1101111

def LUI(rd, imm):   return u_type(imm, rd, OP_LUI)
def ADDI(rd, rs1, imm): return i_type(imm, rs1, 0b000, rd, OP_ADDI_ETC)
def SW(rs1, rs2, imm):  return s_type(imm, rs2, rs1, 0b010, OP_STORE)
def LW(rd, rs1, imm):   return i_type(imm, rs1, 0b010, rd, OP_LOAD)
def BEQ(rs1, rs2, imm): return b_type(imm, rs2, rs1, 0b000, OP_BRANCH)
def JAL(rd, imm):
    imm &= 0x1FFFFE
    b20 = (imm >> 20) & 1
    b10_1 = (imm >> 1) & 0x3FF
    b11 = (imm >> 11) & 1
    b19_12 = (imm >> 12) & 0xFF
    return (b20 << 31) | (b19_12 << 12) | (b11 << 20) | (b10_1 << 21) | (imm << 0 & 0) | (b20*0) | (0) | 0 | (rd << 7) | OP_JAL
    # placeholder, replaced below with correct packing

def JAL_correct(rd, imm):
    imm &= 0x1FFFFE
    b20 = (imm >> 20) & 1
    b19_12 = (imm >> 12) & 0xFF
    b11 = (imm >> 11) & 1
    b10_1 = (imm >> 1) & 0x3FF
    word = (b20 << 31) | (b10_1 << 21) | (b11 << 20) | (b19_12 << 12) | (rd << 7) | OP_JAL
    return word

# Registers
x0=0; x1=1; x2=2; x5=5; x6=6; x7=7; x28=28; x29=29; x30=30; x31=31

ACCEL_BASE = 0x00020000
PIXEL_OFF  = 0x000
WEIGHT_OFF = 0x024
CTRL_OFF   = 0x048
STATUS_OFF = 0x04C
RESULT_OFF = 0x050

prog = []

def emit(word, comment=""):
    prog.append((word, comment))

# x28 = ACCEL_BASE  (LUI loads upper 20 bits; ACCEL_BASE lower 12 bits are 0, clean case)
emit(LUI(x28, ACCEL_BASE), "lui x28, ACCEL_BASE>>12")

# Store 9 pixels: value = 10,20,...,90 into PIXEL[0..8]
pixels = [10,20,30,40,50,60,70,80,90]
weights = [-1,0,1,-2,0,2,-1,0,1]  # matches earlier example, expect conv_out = 80

for i, val in enumerate(pixels):
    emit(ADDI(x5, x0, val), f"addi x5, x0, {val}")
    emit(SW(x28, x5, PIXEL_OFF + 4*i), f"sw x5, PIXEL[{i}](x28)")

for i, val in enumerate(weights):
    emit(ADDI(x5, x0, val), f"addi x5, x0, {val}")
    emit(SW(x28, x5, WEIGHT_OFF + 4*i), f"sw x5, WEIGHT[{i}](x28)")

# Pulse START (CTRL = 1)
emit(ADDI(x5, x0, 1), "addi x5, x0, 1")
emit(SW(x28, x5, CTRL_OFF), "sw x5, CTRL(x28)   # start")

# Poll loop: label L_POLL
poll_instr_index = len(prog)
emit(LW(x6, x28, STATUS_OFF), "L_POLL: lw x6, STATUS(x28)")
emit(ADDI(x7, x0, 1), "addi x7, x0, 1")
# BEQ x6,x7 skip 2 instrs forward (to DONE) if equal else fall through to branch back
# We'll instead do: BEQ x6,x0 -> branch back to L_POLL (loop while status==0)
# recompute: branch if (x6 == 0) back to poll
beq_offset_placeholder_index = len(prog)
emit(0, "BEQ_PLACEHOLDER")  # will patch after we know addresses

# DONE: read RESULT into x29
emit(LW(x29, x28, RESULT_OFF), "lw x29, RESULT(x28)")

# Infinite loop (halt)
halt_index = len(prog)
emit(0, "JAL_HALT_PLACEHOLDER")

# ---- Now resolve addresses ----
# Each entry is one 4-byte instruction
poll_addr = poll_instr_index * 4
beq_addr  = beq_offset_placeholder_index * 4
halt_addr = halt_index * 4

# Patch BEQ: while x6==0, branch back to poll_addr
beq_imm = poll_addr - beq_addr
prog[beq_offset_placeholder_index] = (BEQ(x6, x0, beq_imm), f"beq x6, x0, L_POLL (imm={beq_imm})")

# Patch halt: JAL x0, self (infinite loop)
prog[halt_index] = (JAL_correct(x0, 0), "HALT: jal x0, 0 (self loop)")

for idx, (word, comment) in enumerate(prog):
    print(f"{idx*4:04x}: {word:08x}   // {comment}")

print()
print("Total instructions:", len(prog))
print()
print("SystemVerilog initial-block lines:")
for idx, (word, comment) in enumerate(prog):
    print(f"        prog_mem_init[{idx}] = 32'h{word:08x}; // {comment}")

print()
print("--- Sanity check: decode a few SW immediates back ---")
def decode_s_imm(word):
    imm11_5 = (word >> 25) & 0x7F
    imm4_0 = (word >> 7) & 0x1F
    imm = (imm11_5 << 5) | imm4_0
    if imm & 0x800:
        imm -= 0x1000
    return imm

checks = [2, 4, 18]  # a few SW instruction indices from prog list
for idx in checks:
    word, comment = prog[idx]
    print(f"idx {idx}: word={word:08x} decoded_imm={decode_s_imm(word)}  comment={comment}")
