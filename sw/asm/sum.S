# sum.S - add 1 + 2 + ... + 100, store the result in memory, check it.
# Expected: result = 5050 (0x13BA). tohost = 1 means PASS.

    .section .text.init
    .globl _start
_start:
    li    t0, 0              # t0 = sum
    li    t1, 1              # t1 = i
    li    t2, 101            # loop limit

loop:
    add   t0, t0, t1         # sum = sum + i
    addi  t1, t1, 1          # i = i + 1
    blt   t1, t2, loop       # if (i < 101) repeat

    la    t3, result         # t3 = address of 'result'
    sw    t0, 0(t3)          # result = sum        (store)
    lw    t4, 0(t3)          # read it back        (load)

    li    t5, 5050
    bne   t4, t5, fail       # wrong answer -> fail

pass:
    li    a0, 1              # tohost = 1          -> PASS
    j     done
fail:
    li    a0, 3              # tohost = (1<<1)|1   -> FAIL, case 1
done:
    la    t6, tohost
    sw    a0, 0(t6)
1:  j     1b                 # stay here; the testbench stops the simulation

    .data
    .align 2
result: .word 0

    .section .tohost, "aw", @progbits
    .align 6
    .globl tohost
tohost: .dword 0
