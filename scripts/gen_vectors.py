#!/usr/bin/env python3
"""Generate golden test vectors for leaf modules (imm_gen, alu, branch_cmp, lsu).
The Python model is written independently of the RTL: it is the 'golden model'."""
import random, sys, os
random.seed(1)
M = 0xFFFFFFFF
def s32(x): x &= M; return x - (1 << 32) if x & 0x80000000 else x

# ---------- instruction encoders ----------
def enc_i(op, rd, f3, rs1, imm): return ((imm & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op
def enc_s(op, f3, rs1, rs2, imm):
    return (((imm >> 5) & 0x7F) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | ((imm & 0x1F) << 7) | op
def enc_b(op, f3, rs1, rs2, imm):
    return (((imm >> 12) & 1) << 31) | (((imm >> 5) & 0x3F) << 25) | (rs2 << 20) | (rs1 << 15) | \
           (f3 << 12) | (((imm >> 1) & 0xF) << 8) | (((imm >> 11) & 1) << 7) | op
def enc_u(op, rd, imm20): return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | op
def enc_j(op, rd, imm):
    return (((imm >> 20) & 1) << 31) | (((imm >> 1) & 0x3FF) << 21) | (((imm >> 11) & 1) << 20) | \
           (((imm >> 12) & 0xFF) << 12) | (rd << 7) | op

out = sys.argv[1] if len(sys.argv) > 1 else "vec"
os.makedirs(out, exist_ok=True)

# ---------- imm_gen ----------
with open(f"{out}/imm.txt", "w") as f:
    n = 0
    for _ in range(400):
        r = lambda b: random.getrandbits(b)
        kind = random.choice("ISBUJL")
        if kind == "I":
            v = random.randint(-2048, 2047); ins = enc_i(random.choice([0x13, 0x03, 0x67]), r(5), r(3), r(5), v); exp = v
        elif kind == "S":
            v = random.randint(-2048, 2047); ins = enc_s(0x23, r(3), r(5), r(5), v); exp = v
        elif kind == "B":
            v = random.randint(-2048, 2047) * 2; ins = enc_b(0x63, r(3), r(5), r(5), v); exp = v
        elif kind == "U":
            v = r(20); ins = enc_u(random.choice([0x37, 0x17]), r(5), v); exp = v << 12
        elif kind == "J":
            v = random.randint(-(1 << 19), (1 << 19) - 1) * 2; ins = enc_j(0x6F, r(5), v); exp = v
        else:  # boundary values
            v = random.choice([-2048, 2047, -1, 0]); ins = enc_i(0x13, 1, 0, 2, v); exp = v
        f.write(f"{ins & M:08x} {exp & M:08x}\n"); n += 1

# ---------- alu ----------
def alu_ref(op, a, b):
    sh = b & 31
    return {0: a + b, 1: a - b, 2: a << sh, 3: int(s32(a) < s32(b)), 4: int(a < b), 5: a ^ b,
            6: a >> sh, 7: s32(a) >> sh, 8: a | b, 9: a & b, 10: b}[op] & M
edge = [0, 1, M, 0x80000000, 0x7FFFFFFF, 31, 32]
with open(f"{out}/alu.txt", "w") as f:
    for _ in range(1500):
        a = random.choice(edge) if random.random() < .3 else random.getrandbits(32)
        b = random.choice(edge) if random.random() < .3 else random.getrandbits(32)
        op = random.randint(0, 10)
        f.write(f"{op:x} {a:08x} {b:08x} {alu_ref(op, a, b):08x}\n")

# ---------- branch ----------
def br_ref(f3, a, b):
    return int({0: a == b, 1: a != b, 4: s32(a) < s32(b), 5: s32(a) >= s32(b), 6: a < b, 7: a >= b}[f3])
with open(f"{out}/br.txt", "w") as f:
    for _ in range(1000):
        a = random.choice(edge) if random.random() < .4 else random.getrandbits(32)
        b = a if random.random() < .2 else (random.choice(edge) if random.random() < .4 else random.getrandbits(32))
        f3 = random.choice([0, 1, 4, 5, 6, 7])
        f.write(f"{f3:x} {a:08x} {b:08x} {br_ref(f3, a, b):x}\n")

# ---------- lsu (byte-array model) ----------
with open(f"{out}/lsu.txt", "w") as f:
    for _ in range(1500):
        w = random.getrandbits(32)
        f3 = random.choice([0, 1, 2, 4, 5])
        lo = random.randint(0, 3)
        if f3 in (1, 5): lo &= 2          # halfword aligned
        if f3 == 2: lo = 0                # word aligned
        by = [(w >> (8 * i)) & 0xFF for i in range(4)]
        if f3 == 0:  v = by[lo];  e = (v | (0xFFFFFF00 if v & 0x80 else 0))
        elif f3 == 4: e = by[lo]
        elif f3 == 1: v = by[lo] | (by[lo + 1] << 8); e = v | (0xFFFF0000 if v & 0x8000 else 0)
        elif f3 == 5: e = by[lo] | (by[lo + 1] << 8)
        else: e = w
        # store: write 'w' into a zero word at lo, expect byte-enable pattern + the written bytes
        sf3 = random.choice([0, 1, 2]); slo = random.randint(0, 3)
        if sf3 == 1: slo &= 2
        if sf3 == 2: slo = 0
        nb = {0: 1, 1: 2, 2: 4}[sf3]
        be = ((1 << nb) - 1) << slo
        # bytes actually stored at lanes slo..slo+nb-1 are the low bytes of w
        f.write(f"{f3:x} {lo:x} {w:08x} {e & M:08x} {sf3:x} {slo:x} {be:x}\n")
print("vectors written to", out)
