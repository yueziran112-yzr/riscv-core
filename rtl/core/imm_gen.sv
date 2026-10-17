// Immediate generator for RV32I. 
module imm_gen (
  input  logic [31:0] instr,
  output logic [31:0] imm
);
  always_comb begin
    case (instr[6:0])
      7'b0010011,                       // OP-IMM
      7'b0000011,                       // LOAD
      7'b1100111:                       // JALR
        imm = {{20{instr[31]}}, instr[31:20]};                                   // I
      7'b0100011:                       // STORE
        imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};                      // S
      7'b1100011:                       // BRANCH
        imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};   // B
      7'b0110111,                       // LUI
      7'b0010111:                       // AUIPC
        imm = {instr[31:12], 12'b0};                                             // U
      7'b1101111:                       // JAL
        imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0}; // J
      default: imm = 32'b0;
    endcase
  end
endmodule