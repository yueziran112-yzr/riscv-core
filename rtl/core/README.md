# Your RTL goes here

The Makefile compiles EVERY .sv file in this folder, except files named riscv_*.sv;
the core file is chosen with CORE=rtl/core/<file>.sv (default riscv_pipe.sv).

| File               | Module(s)              | Ports / parameters                                              |
|--------------------|------------------------|-----------------------------------------------------------------|
| regfile.sv         | regfile #(BYPASS)      | clk, we, ra1, ra2, wa, wd, rd1, rd2                             |
| imm_gen.sv         | imm_gen                | instr, imm                                                      |
| alu.sv             | alu                    | a, b, op[3:0], y        (op encoding: manual, chapter 3)        |
| branch_cmp.sv      | branch_cmp             | a, b, funct3, taken                                             |
| lsu.sv             | lsu_store, lsu_load    | (funct3, addr_lo, wdata_in, wdata_out, be) / (funct3, addr_lo, rword, rdata) |
| decoder.sv         | decoder                | free                                                            |
| muldiv_comb.sv     | muldiv_comb            | a, b, f3, y             (golden model for M instructions)       |
| div_iter.sv        | div_iter               | clk, rst_n, start, a, b, mode, busy, done, result               |
| mul_*.sv           | one module per multiplier, same ports as div_iter          |
| muldiv_unit.sv     | muldiv_unit #(MUL_IMPL)| clk, rst_n, start, f3, a, b, idle, done, result                 |
| riscv_sc.sv        | riscv_core             | single-cycle reference core                                     |
| riscv_pipe.sv      | riscv_core             | pipelined core                                                  |

`riscv_core` must have the parameters RESET_PC, MUL_IMPL and BP (unused ones may be ignored)
and the ports listed in chapter 2 of the manual.
