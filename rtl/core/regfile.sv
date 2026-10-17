// 32x32 register file: 2 read ports (combinational), 1 write port (posedge).
// x0 always reads as zero.
// BYPASS=1: if the same register is written and read in the same cycle, the read
//   port returns the new value (needed in a 5-stage pipeline where WB and ID touch
//   the same register).
// BYPASS=0: use in the single-cycle core - there `wd` depends on the read data, so a
//   bypass would create a combinational loop.

module regfile #(parameter bit BYPASS = 1'b0) (
  input  logic        clk,
  input  logic        we,               // write enable
  input  logic [4:0]  ra1, ra2,         // read addresses (register numbers 0..31)
  input  logic [4:0]  wa,               // write address
  input  logic [31:0] wd,               // write data
  output logic [31:0] rd1, rd2          // read data
);
  logic [31:0] regs [0:31];             // 32 registers, each 32 bits

  // start all registers at 0 in simulation
  initial for (int i = 0; i < 32; i++) regs[i] = 32'b0;

  // write port (sequential)
  always_ff @(posedge clk) begin
     if(we && wa !=5'd0)
        regs[wa]<=wd;
  end

  // read ports (combinational)
  assign rd1 = (ra1 == 5'd0)                 ? 32'b0 : 
                (BYPASS && we && wa==ra1)    ? wd    : regs[ra1];
  assign rd2 = (ra2 == 5'd0)                 ? 32'b0 :
               (BYPASS && we && wa == ra2)   ? wd    : regs[ra2];
endmodule