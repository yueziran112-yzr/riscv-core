# rtl/core — RTL of the RISC-V core

The Makefile compiles every `.sv` file in this folder except `riscv_*.sv`;
the core is chosen with `CORE=rtl/core/<file>.sv` (default `riscv_pipe.sv`).

| File | Module(s) | Ports / parameters | Status |
|---|---|---|---|
| regfile.sv | regfile #(BYPASS) | clk, we, ra1, ra2, wa, wd, rd1, rd2 | ✅ |
| imm_gen.sv | imm_gen | instr, imm | ✅ |
| alu.sv | alu | a, b, op[3:0], y | ✅ |
| branch_cmp.sv | branch_cmp | a, b, funct3, taken | ✅ |
| lsu.sv | lsu_store, lsu_load | (funct3, addr_lo, wdata_in, wdata_out, be) / (funct3, addr_lo, rword, rdata) | ✅ |
| decoder.sv | decoder | instr → alu_op, a_sel, b_sel, reg_we, mem_re, mem_we, is_branch, is_jal, is_jalr, wb_sel, is_muldiv, uses_rs1, uses_rs2 | ✅ |
| muldiv_comb.sv | muldiv_comb | a, b, f3, y (golden model for M instructions) | ✅ |
| div_iter.sv | div_iter | clk, rst_n, start, a, b, mode, busy, done, result | ✅ restoring division, 32 cycles |
| mul_iter.sv | mul_iter | same ports as div_iter | ✅ radix-2 shift-add, 32 cycles |
| mul_*.sv | other multipliers, same ports as div_iter | | planned (multiplier study) |
| muldiv_unit.sv | muldiv_unit #(MUL_IMPL) | clk, rst_n, start, f3, a, b, idle, done, result | ✅ (MUL_IMPL=1 only) |
| riscv_sc.sv | riscv_core | single-cycle core | ✅ 48/48 riscv-tests |
| riscv_pipe.sv | riscv_core | 5-stage pipelined core | ✅ 48/48, random 60/60 |

`riscv_core` must have the parameters RESET_PC, MUL_IMPL and BP (unused ones may be ignored)
and the memory / retire ports used by `tb/tb_top.sv`.