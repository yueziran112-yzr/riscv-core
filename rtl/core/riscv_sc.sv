// REFERENCE single-cycle RV32IM core (Step 1). Use it to compare against / get unstuck.
module riscv_core #(
  parameter logic [31:0] RESET_PC = 32'h8000_0000,
  parameter int          MUL_IMPL = 0,          // unused here (combinational reference)
  parameter int          BP       = 0           // unused here
) (
  input  logic        clk, rst_n,
  output logic [31:0] imem_addr,
  input  logic [31:0] imem_rdata,
  output logic [31:0] dmem_addr,
  output logic [31:0] dmem_wdata,
  output logic [3:0]  dmem_be,          // byte enables, 0 = no write
  output logic        dmem_re,
  input  logic [31:0] dmem_rdata,
  // retirement trace
  output logic        retire_valid,
  output logic [31:0] retire_pc, retire_instr,
  output logic [4:0]  retire_rd,
  output logic        retire_we,
  output logic [31:0] retire_data
);
  logic [31:0] pc, instr, imm, rs1, rs2, alu_a, alu_b, alu_y, wb_data, lsu_rdata, md_y, pc_next;
  logic [3:0]  alu_op;  logic a_sel, b_sel, reg_we, mem_re, mem_we, is_branch, is_jal, is_jalr, is_md, u1, u2;
  logic [1:0]  wb_sel;  logic taken;  logic [3:0] be;  logic [31:0] st_data;

  assign imem_addr = pc;
  assign instr     = imem_rdata;

  decoder   u_dec (.instr, .alu_op, .a_sel, .b_sel, .reg_we, .mem_re, .mem_we, .is_branch, .is_jal, .is_jalr,
                   .wb_sel, .is_muldiv(is_md), .uses_rs1(u1), .uses_rs2(u2));
  imm_gen   u_imm (.instr, .imm);
  regfile   u_rf  (.clk, .we(reg_we & rst_n), .ra1(instr[19:15]), .ra2(instr[24:20]), .wa(instr[11:7]),
                   .wd(wb_data), .rd1(rs1), .rd2(rs2));
  assign alu_a = a_sel ? pc  : rs1;
  assign alu_b = b_sel ? imm : rs2;
  alu       u_alu (.a(alu_a), .b(alu_b), .op(alu_op), .y(alu_y));
  branch_cmp u_br (.a(rs1), .b(rs2), .funct3(instr[14:12]), .taken);
  muldiv_comb u_md (.a(rs1), .b(rs2), .f3(instr[14:12]), .y(md_y));

  lsu_store u_st (.funct3(instr[14:12]), .addr_lo(alu_y[1:0]), .wdata_in(rs2), .wdata_out(st_data), .be);
  lsu_load  u_ld (.funct3(instr[14:12]), .addr_lo(alu_y[1:0]), .rword(dmem_rdata), .rdata(lsu_rdata));
  assign dmem_addr  = alu_y;
  assign dmem_wdata = st_data;
  assign dmem_be    = mem_we ? be : 4'b0000;
  assign dmem_re    = mem_re;

  always_comb begin
    case (wb_sel)
      2'd1:    wb_data = lsu_rdata;
      2'd2:    wb_data = pc + 32'd4;
      default: wb_data = is_md ? md_y : alu_y;
    endcase
  end

  always_comb begin
    if (is_jal || (is_branch && taken)) pc_next = pc + imm;
    else if (is_jalr)                   pc_next = (rs1 + imm) & 32'hFFFF_FFFE;
    else                                pc_next = pc + 32'd4;
  end
  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) pc <= RESET_PC; else pc <= pc_next;

  assign retire_valid = rst_n;
  assign retire_pc    = pc;
  assign retire_instr = instr;
  assign retire_rd    = instr[11:7];
  assign retire_we    = reg_we && instr[11:7] != 5'd0;
  assign retire_data  = wb_data;
endmodule
