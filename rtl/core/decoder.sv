// Instruction decoder shared by the single-cycle and pipelined cores.
module decoder (
  input  logic [31:0] instr,
  output logic [3:0]  alu_op,
  output logic        a_sel,      // the first operand of ALU 0: rs1, 1: pc
  output logic        b_sel,      // the second operand of ALU 0: rs2, 1: imm
  output logic        reg_we,
  output logic        mem_re,
  output logic        mem_we,
  output logic        is_branch,
  output logic        is_jal,
  output logic        is_jalr,
  output logic [1:0]  wb_sel,     // 0: alu, 1: load data, 2: pc+4
  output logic        is_muldiv,  // multiply/divide
  output logic        uses_rs1, // used by pipeling 
  output logic        uses_rs2
);
  localparam logic [3:0] ALU_ADD=4'd0, ALU_SUB=4'd1, ALU_SLL=4'd2, ALU_SLT=4'd3, ALU_SLTU=4'd4,
                         ALU_XOR=4'd5, ALU_SRL=4'd6, ALU_SRA=4'd7, ALU_OR=4'd8, ALU_AND=4'd9, ALU_PASSB=4'd10;

  wire [6:0] opcode = instr[6:0];
  wire [2:0] f3     = instr[14:12];
  wire       f7_5   = instr[30];
  wire       f7_0   = instr[25];

  logic [3:0] alu_arith;      // ALU op for OP / OP-IMM from funct3
  always_comb begin
    case (f3)
      3'b000: alu_arith = (opcode == 7'b0110011 && f7_5) ? ALU_SUB : ALU_ADD;
      3'b001: alu_arith = ALU_SLL;
      3'b010: alu_arith = ALU_SLT;
      3'b011: alu_arith = ALU_SLTU;
      3'b100: alu_arith = ALU_XOR;
      3'b101: alu_arith = f7_5 ? ALU_SRA : ALU_SRL;
      3'b110: alu_arith = ALU_OR;
      default:alu_arith = ALU_AND;
    endcase
  end

  always_comb begin
    // defaults = NOP
    alu_op = ALU_ADD; a_sel = 1'b0; b_sel = 1'b0; reg_we = 1'b0; mem_re = 1'b0; mem_we = 1'b0;
    is_branch = 1'b0; is_jal = 1'b0; is_jalr = 1'b0; wb_sel = 2'd0; is_muldiv = 1'b0;
    uses_rs1 = 1'b0; uses_rs2 = 1'b0;
    case (opcode)
      7'b0110111: begin alu_op = ALU_PASSB; b_sel = 1'b1; reg_we = 1'b1; end                    // LUI
      7'b0010111: begin a_sel = 1'b1; b_sel = 1'b1; reg_we = 1'b1; end                          // AUIPC
      7'b1101111: begin is_jal = 1'b1; reg_we = 1'b1; wb_sel = 2'd2; end                        // JAL
      7'b1100111: begin is_jalr = 1'b1; b_sel = 1'b1; reg_we = 1'b1; wb_sel = 2'd2;
                        uses_rs1 = 1'b1; end                                                    // JALR
      7'b1100011: begin is_branch = 1'b1; uses_rs1 = 1'b1; uses_rs2 = 1'b1; end                 // BRANCH
      7'b0000011: begin b_sel = 1'b1; reg_we = 1'b1; mem_re = 1'b1; wb_sel = 2'd1;
                        uses_rs1 = 1'b1; end                                                    // LOAD
      7'b0100011: begin b_sel = 1'b1; mem_we = 1'b1; uses_rs1 = 1'b1; uses_rs2 = 1'b1; end      // STORE
      7'b0010011: begin alu_op = alu_arith; b_sel = 1'b1; reg_we = 1'b1; uses_rs1 = 1'b1; end   // OP-IMM
      7'b0110011: begin                                                                         // OP
        reg_we = 1'b1; uses_rs1 = 1'b1; uses_rs2 = 1'b1;
        if (f7_0) is_muldiv = 1'b1; else alu_op = alu_arith;
      end
      default: ;   // FENCE / SYSTEM / unknown: treated as NOP in this project
    endcase
  end
endmodule
