#!/usr/bin/env python3
"""Random hazard-heavy RV32IM program generator.
usage: gen_random_test.py <seed> <n_instr> > out.S
Forward branches/jumps plus small counted backward loops (x16), so every program terminates. A mix of back-to-back
dependencies, loads followed by uses, stores, branches and M-extension ops stresses the
forwarding / stall / flush logic. Compare the commit trace of two cores (or core vs Spike)."""
import random, sys
seed = int(sys.argv[1]); n = int(sys.argv[2]) if len(sys.argv) > 2 else 300
rnd = random.Random(seed)
R = [f"x{i}" for i in range(5, 16)]          # registers the generator plays with
BASE = "x31"                                  # data buffer pointer (never overwritten)
BUF_WORDS = 32

def reg(): return rnd.choice(R)
def dst(): return "x0" if rnd.random() < 0.08 else reg()   # sometimes write x0 (must be ignored)
def src(): return "x0" if rnd.random() < 0.08 else reg()   # ... and read it back (must be 0)
lines = []; label = 0
def emit(s): lines.append("  " + s)

alu_rr  = ["add", "sub", "sll", "slt", "sltu", "xor", "srl", "sra", "or", "and"]
alu_ri  = ["addi", "slti", "sltiu", "xori", "ori", "andi"]
sh_ri   = ["slli", "srli", "srai"]
md      = ["mul", "mulh", "mulhsu", "mulhu", "div", "divu", "rem", "remu"]
branch  = ["beq", "bne", "blt", "bge", "bltu", "bgeu"]

lines.append('#include "riscv_test.h"\n#include "test_macros.h"\nRVTEST_RV32U\nRVTEST_CODE_BEGIN')
emit(f"la {BASE}, buf")
for r in R:
    v = rnd.choice([0, 1, -1, 0x7FFFFFFF, -0x80000000, rnd.getrandbits(32)]) & 0xFFFFFFFF
    emit(f"li {r}, 0x{v:08x}")

i = 0
while i < n:
    k = rnd.random()
    if k < 0.28:   emit(f"{rnd.choice(alu_rr)} {dst()}, {src()}, {src()}")
    elif k < 0.40: emit(f"{rnd.choice(alu_ri)} {dst()}, {reg()}, {rnd.randint(-2048, 2047)}")
    elif k < 0.45: emit(f"{rnd.choice(sh_ri)} {reg()}, {reg()}, {rnd.randint(0, 31)}")
    elif k < 0.49: emit(f"lui {reg()}, {rnd.getrandbits(20)}")
    elif k < 0.51:                                  # write x0, then read x0 right away (must read 0)
        emit(f"{rnd.choice(alu_rr)} x0, {reg()}, {reg()}")
        emit(f"{rnd.choice(alu_rr)} {reg()}, x0, {reg()}"); i += 1
    elif k < 0.53: emit(f"auipc {reg()}, {rnd.getrandbits(20)}")
    elif k < 0.63: emit(f"{rnd.choice(md)} {reg()}, {reg()}, {reg()}")
    elif k < 0.75:                                  # loads (aligned), often followed by a dependent use
        op = rnd.choice(["lw", "lh", "lhu", "lb", "lbu"])
        a = {"lw": 4, "lh": 2, "lhu": 2, "lb": 1, "lbu": 1}[op]
        off = rnd.randrange(0, BUF_WORDS * 4, a)
        rd = reg(); emit(f"{op} {rd}, {off}({BASE})")
        if rnd.random() < 0.6:
            emit(f"{rnd.choice(alu_rr)} {reg()}, {rd}, {reg()}"); i += 1
    elif k < 0.85:
        op = rnd.choice(["sw", "sh", "sb"]); a = {"sw": 4, "sh": 2, "sb": 1}[op]
        emit(f"{op} {reg()}, {rnd.randrange(0, BUF_WORDS * 4, a)}({BASE})")
    elif k < 0.92:                                  # forward branch over 1-3 instructions
        label += 1
        emit(f"{rnd.choice(branch)} {reg()}, {reg()}, L{label}")
        for _ in range(rnd.randint(1, 3)):
            emit(f"{rnd.choice(alu_rr)} {reg()}, {reg()}, {reg()}"); i += 1
        lines.append(f"L{label}:")
    elif k < 0.945:                                 # jal / jalr forward (links are written to a random reg)
        label += 1
        if rnd.random() < 0.5:
            emit(f"jal {reg()}, L{label}")
        else:
            t = reg(); rd = reg()
            while rd == t: rd = reg()
            emit(f"la {t}, L{label}")
            emit(f"jalr {rd}, 0({t})"); i += 1
        emit(f"addi {reg()}, {reg()}, 1")           # skipped (wrong-path) instruction
        lines.append(f"L{label}:")
    elif k < 0.975:                                 # call a shared subroutine: returns go to different targets
        emit("jal x1, SUB")
    elif k < 0.99:                                  # small backward loop (x16 = counter, 2-6 iterations)
        label += 1
        emit(f"li x16, {rnd.randint(2, 6)}")
        lines.append(f"L{label}:")
        for _ in range(rnd.randint(2, 6)):
            r = rnd.random()
            if r < 0.5:   emit(f"{rnd.choice(alu_rr)} {reg()}, {reg()}, {reg()}")
            elif r < 0.7: emit(f"{rnd.choice(md)} {reg()}, {reg()}, {reg()}")
            else:
                rd = reg(); emit(f"lw {rd}, {rnd.randrange(0, BUF_WORDS * 4, 4)}({BASE})")
                emit(f"add {reg()}, {rd}, {reg()}")
            i += 1
        if rnd.random() < 0.5:                      # data-dependent branch inside the loop
            label2 = label + 1000
            emit(f"{rnd.choice(branch)} {reg()}, {reg()}, L{label2}")
            emit(f"xor {reg()}, {reg()}, {reg()}")
            lines.append(f"L{label2}:")
        emit("addi x16, x16, -1")
        emit(f"bnez x16, L{label}")
    else:
        emit(f"{rnd.choice(alu_rr)} {reg()}, {reg()}, {reg()}")
    i += 1

# fold everything into x5 so any wrong value is visible, then pass
for r in R[1:]: emit(f"xor x5, x5, {r}")
emit("RVTEST_PASS")
lines.append("SUB:")
emit("addi x17, x17, 1")
emit("xor x5, x5, x17")
emit("ret")
lines.append("RVTEST_CODE_END\n  .data\nRVTEST_DATA_BEGIN\n  .align 4\nbuf:")
for _ in range(BUF_WORDS): lines.append(f"  .word 0x{rnd.getrandbits(32):08x}")
lines.append("RVTEST_DATA_END")
print("\n".join(lines))
