// Minimal riscv-tests environment for a core WITHOUT CSRs / traps.
// Pass/fail is reported by storing to the `tohost` word:
//   tohost == 1            -> PASS
//   tohost == (n << 1) | 1 -> FAIL at test case n
#ifndef _ENV_OURS_H
#define _ENV_OURS_H

#define RVTEST_RV32U   .macro init; .endm
#define RVTEST_RV64U   RVTEST_RV32U
#define TESTNUM        gp

#define RVTEST_CODE_BEGIN                                   \
        .section .text.init;                                \
        .align  2;                                          \
        .globl  _start;                                     \
_start:                                                     \
        li      TESTNUM, 0;                                 \
        init;

#define RVTEST_CODE_END                                     \
        .align 2;

#define RVTEST_PASS                                         \
        li      a0, 1;                                      \
        la      t0, tohost;                                 \
        sw      a0, 0(t0);                                  \
1:      j       1b;

#define RVTEST_FAIL                                         \
        sll     a0, TESTNUM, 1;                             \
        or      a0, a0, 1;                                  \
        la      t0, tohost;                                 \
        sw      a0, 0(t0);                                  \
1:      j       1b;

#define EXTRA_DATA

#define RVTEST_DATA_BEGIN                                   \
        .pushsection .tohost, "aw", @progbits;              \
        .align 6; .global tohost;   tohost:   .dword 0;     \
        .align 6; .global fromhost; fromhost: .dword 0;     \
        .popsection;                                        \
        .align 4; .global begin_signature; begin_signature: \
        EXTRA_DATA

#define RVTEST_DATA_END                                     \
        .align 4; .global end_signature; end_signature:

#endif
