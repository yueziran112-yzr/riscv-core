// 5-stage RV32IM pipeline - version 2 
//   IF -> ID -> EX -> MEM -> WB
//   * data forwarding : EX/MEM -> EX and MEM/WB -> EX
//   * load-use hazard : 1-cycle bubble
//   * control hazard  : branch/jump resolved in EX, predict-not-taken, flush IF/ID + ID/EX (2-cycle penalty)
//   * M extension     : iterative mul/div, whole front-end freezes while EX waits (ex_stall)
//   * register file bypasses WB -> ID within the same cycle
module riscv_core #(
  parameter logic [31:0] RESET_PC = 32'h8000_0000,
  parameter int          MUL_IMPL = 1,          // multiplier micro-architecture, see muldiv_unit.sv
  parameter int          BP       = 0           // chapter 7; this version: predict-not-taken only
) (
  input  logic        clk, rst_n,
  output logic [31:0] imem_addr,
  input  logic [31:0] imem_rdata,
  output logic [31:0] dmem_addr,
  output logic [31:0] dmem_wdata,
  output logic [3:0]  dmem_be,
  output logic        dmem_re,
  input  logic [31:0] dmem_rdata,
  output logic        retire_valid,
  output logic [31:0] retire_pc, retire_instr,
  output logic [4:0]  retire_rd,
  output logic        retire_we,
  output logic [31:0] retire_data
);
  localparam logic [31:0] NOP = 32'h0000_0013;

  // ------------------------------------------------------------------ pipeline registers
  // IF/ID
  logic        ifid_valid;
  logic [31:0] ifid_pc, ifid_instr;
  // ID/EX
  logic        idex_valid;
  logic [31:0] idex_pc, idex_instr, idex_rs1_val, idex_rs2_val, idex_imm;
  logic [4:0]  idex_rs1, idex_rs2, idex_rd;
  logic [3:0]  idex_alu_op;
  logic        idex_a_sel, idex_b_sel, idex_reg_we, idex_mem_re, idex_mem_we;
  logic        idex_is_branch, idex_is_jal, idex_is_jalr, idex_is_md;
  logic [1:0]  idex_wb_sel;
  logic [2:0]  idex_f3;
  // EX/MEM
  logic        exmem_valid;
  logic [31:0] exmem_pc, exmem_instr, exmem_result, exmem_store;
  logic [4:0]  exmem_rd;
  logic        exmem_reg_we, exmem_mem_re, exmem_mem_we;
  logic [2:0]  exmem_f3;
  // MEM/WB
  logic        memwb_valid, memwb_reg_we;
  logic [31:0] memwb_pc, memwb_instr, memwb_data;
  logic [4:0]  memwb_rd;

  // ------------------------------------------------------------------ control wires
  logic        load_use, ex_stall, redirect;
  logic [31:0] redirect_pc;
  wire         stall_front = load_use | ex_stall;      // freeze PC and IF/ID

  // ================================================================== IF
  logic [31:0] pc;
  assign imem_addr = pc;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)            pc <= RESET_PC;
    else if (redirect)     pc <= redirect_pc;
    else if (!stall_front) pc <= pc + 32'd4;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ifid_valid <= 1'b0; ifid_pc <= 32'b0; ifid_instr <= NOP;
    end else if (redirect) begin
      ifid_valid <= 1'b0; ifid_instr <= NOP;                       // flush wrong-path fetch
    end else if (!stall_front) begin
      ifid_valid <= 1'b1; ifid_pc <= pc; ifid_instr <= imem_rdata;
    end
  end

  // ================================================================== ID
  logic [3:0] d_alu_op;  logic d_a_sel, d_b_sel, d_reg_we, d_mem_re, d_mem_we, d_br, d_jal, d_jalr, d_md, d_u1, d_u2;
  logic [1:0] d_wb_sel;  logic [31:0] d_imm, d_rs1, d_rs2;
  wire  [4:0] id_rs1 = ifid_instr[19:15], id_rs2 = ifid_instr[24:20], id_rd = ifid_instr[11:7];

  decoder u_dec (.instr(ifid_instr), .alu_op(d_alu_op), .a_sel(d_a_sel), .b_sel(d_b_sel), .reg_we(d_reg_we),
                 .mem_re(d_mem_re), .mem_we(d_mem_we), .is_branch(d_br), .is_jal(d_jal), .is_jalr(d_jalr),
                 .wb_sel(d_wb_sel), .is_muldiv(d_md), .uses_rs1(d_u1), .uses_rs2(d_u2));
  imm_gen u_imm (.instr(ifid_instr), .imm(d_imm));

  regfile #(.BYPASS(1'b1)) u_rf (.clk, .we(memwb_reg_we), .ra1(id_rs1), .ra2(id_rs2), .wa(memwb_rd),
                                 .wd(memwb_data), .rd1(d_rs1), .rd2(d_rs2));

  // load-use hazard: the instruction in EX is a load whose rd is needed by the instruction in ID
  assign load_use = idex_valid && idex_mem_re && (idex_rd != 5'd0) && ifid_valid &&
                    ((d_u1 && id_rs1 == idex_rd) || (d_u2 && id_rs2 == idex_rd));

  always_ff @(posedge clk or negedge rst_n) begin
    // NOTE: async reset must be the ONLY condition of the first `if` - mixing it with
    // synchronous conditions (e.g. `if (!rst_n || flush)`) simulates fine but cannot be synthesized.
    if (!rst_n) begin
      idex_valid <= 1'b0; idex_reg_we <= 1'b0; idex_mem_re <= 1'b0; idex_mem_we <= 1'b0;
      idex_is_branch <= 1'b0; idex_is_jal <= 1'b0; idex_is_jalr <= 1'b0; idex_is_md <= 1'b0;
      idex_rd <= 5'd0; idex_rs1 <= 5'd0; idex_rs2 <= 5'd0; idex_instr <= NOP; idex_pc <= 32'b0;
    end else if (!ex_stall && (redirect || load_use || !ifid_valid)) begin
      // insert a bubble
      idex_valid <= 1'b0; idex_reg_we <= 1'b0; idex_mem_re <= 1'b0; idex_mem_we <= 1'b0;
      idex_is_branch <= 1'b0; idex_is_jal <= 1'b0; idex_is_jalr <= 1'b0; idex_is_md <= 1'b0;
      idex_rd <= 5'd0; idex_rs1 <= 5'd0; idex_rs2 <= 5'd0; idex_instr <= NOP; idex_pc <= 32'b0;
    end else if (!ex_stall) begin
      idex_valid <= 1'b1;  idex_pc <= ifid_pc;  idex_instr <= ifid_instr;
      idex_rs1_val <= d_rs1;  idex_rs2_val <= d_rs2;  idex_imm <= d_imm;
      idex_rs1 <= id_rs1;  idex_rs2 <= id_rs2;  idex_rd <= id_rd;
      idex_alu_op <= d_alu_op;  idex_a_sel <= d_a_sel;  idex_b_sel <= d_b_sel;
      idex_reg_we <= d_reg_we;  idex_mem_re <= d_mem_re;  idex_mem_we <= d_mem_we;
      idex_is_branch <= d_br;  idex_is_jal <= d_jal;  idex_is_jalr <= d_jalr;  idex_is_md <= d_md;
      idex_wb_sel <= d_wb_sel;  idex_f3 <= ifid_instr[14:12];
    end
  end

  // ================================================================== EX
  logic [31:0] fwd_a, fwd_b, alu_a, alu_b, alu_y, md_y, ex_result;
  logic        taken, md_idle, md_done;

  // forwarding (MEM result has priority over WB result)
  always_comb begin
    if      (exmem_reg_we && exmem_rd != 5'd0 && exmem_rd == idex_rs1) fwd_a = exmem_result;
    else if (memwb_reg_we && memwb_rd != 5'd0 && memwb_rd == idex_rs1) fwd_a = memwb_data;
    else                                                               fwd_a = idex_rs1_val;
    if      (exmem_reg_we && exmem_rd != 5'd0 && exmem_rd == idex_rs2) fwd_b = exmem_result;
    else if (memwb_reg_we && memwb_rd != 5'd0 && memwb_rd == idex_rs2) fwd_b = memwb_data;
    else                                                               fwd_b = idex_rs2_val;
  end

  assign alu_a = idex_a_sel ? idex_pc  : fwd_a;
  assign alu_b = idex_b_sel ? idex_imm : fwd_b;
  alu        u_alu (.a(alu_a), .b(alu_b), .op(idex_alu_op), .y(alu_y));
  branch_cmp u_br  (.a(fwd_a), .b(fwd_b), .funct3(idex_f3), .taken);

  // multi-cycle M unit
  wire md_active = idex_valid && idex_is_md;
  muldiv_unit #(.MUL_IMPL(MUL_IMPL)) u_md (.clk, .rst_n, .start(md_active & md_idle), .f3(idex_f3), .a(fwd_a), .b(fwd_b),
                    .idle(md_idle), .done(md_done), .result(md_y));
  assign ex_stall = md_active && !md_done;

  assign ex_result = (idex_wb_sel == 2'd2) ? idex_pc + 32'd4 :
                     idex_is_md            ? md_y            : alu_y;

  // branch / jump resolution
  assign redirect    = idex_valid && ((idex_is_branch && taken) || idex_is_jal || idex_is_jalr);
  assign redirect_pc = idex_is_jalr ? (alu_y & 32'hFFFF_FFFE) : (idex_pc + idex_imm);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      exmem_valid <= 1'b0; exmem_reg_we <= 1'b0; exmem_mem_re <= 1'b0; exmem_mem_we <= 1'b0;
      exmem_rd <= 5'd0; exmem_instr <= NOP; exmem_pc <= 32'b0;
    end else if (ex_stall) begin            // EX is busy (mul/div): send a bubble to MEM
      exmem_valid <= 1'b0; exmem_reg_we <= 1'b0; exmem_mem_re <= 1'b0; exmem_mem_we <= 1'b0;
      exmem_rd <= 5'd0; exmem_instr <= NOP; exmem_pc <= 32'b0;
    end else begin
      exmem_valid <= idex_valid;  exmem_pc <= idex_pc;  exmem_instr <= idex_instr;
      exmem_result <= ex_result;  exmem_store <= fwd_b;  exmem_rd <= idex_rd;
      exmem_reg_we <= idex_reg_we && idex_valid;
      exmem_mem_re <= idex_mem_re && idex_valid;
      exmem_mem_we <= idex_mem_we && idex_valid;
      exmem_f3 <= idex_f3;
    end
  end

  // ================================================================== MEM
  logic [3:0]  st_be;  logic [31:0] st_data, ld_data, mem_wb_data;
  lsu_store u_st (.funct3(exmem_f3), .addr_lo(exmem_result[1:0]), .wdata_in(exmem_store), .wdata_out(st_data), .be(st_be));
  lsu_load  u_ld (.funct3(exmem_f3), .addr_lo(exmem_result[1:0]), .rword(dmem_rdata), .rdata(ld_data));
  assign dmem_addr  = exmem_result;
  assign dmem_wdata = st_data;
  assign dmem_be    = exmem_mem_we ? st_be : 4'b0000;
  assign dmem_re    = exmem_mem_re;
  assign mem_wb_data = exmem_mem_re ? ld_data : exmem_result;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      memwb_valid <= 1'b0; memwb_reg_we <= 1'b0; memwb_rd <= 5'd0; memwb_instr <= NOP; memwb_pc <= 32'b0;
    end else begin
      memwb_valid <= exmem_valid; memwb_reg_we <= exmem_reg_we; memwb_rd <= exmem_rd;
      memwb_data <= mem_wb_data;  memwb_pc <= exmem_pc;  memwb_instr <= exmem_instr;
    end
  end

  // ================================================================== WB / retire trace
  assign retire_valid = memwb_valid;
  assign retire_pc    = memwb_pc;
  assign retire_instr = memwb_instr;
  assign retire_rd    = memwb_rd;
  assign retire_we    = memwb_reg_we && memwb_rd != 5'd0;
  assign retire_data  = memwb_data;
endmodule
