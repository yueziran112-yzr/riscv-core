# crt0.S - minimal C runtime: set sp/gp, clear .bss, call main, report exit code via tohost
    .section .text.init
    .globl _start
_start:
    la    sp, _stack_top
    .option push
    .option norelax
    la    gp, __global_pointer$
    .option pop
    la    t0, _bss_start
    la    t1, _bss_end
1:  bgeu  t0, t1, 2f
    sw    zero, 0(t0)
    addi  t0, t0, 4
    j     1b
2:  call  main
    # exit code in a0: 0 -> PASS (tohost = 1), else FAIL (tohost = code<<1 | 1)
    slli  a0, a0, 1
    ori   a0, a0, 1
    la    t0, tohost
    sw    a0, 0(t0)
3:  j     3b

    .section .tohost, "aw", @progbits
    .align 6
    .globl tohost
tohost: .dword 0
