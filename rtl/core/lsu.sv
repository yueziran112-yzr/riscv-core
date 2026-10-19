// Store-side formatter: places data on the right byte lanes and makes byte enables.
module lsu_store (
  input  logic [2:0]  funct3,       // 000 SB, 001 SH, 010 SW
  input  logic [1:0]  addr_lo,      // address[1:0]
  input  logic [31:0] wdata_in,     // rs2
  output logic [31:0] wdata_out,
  output logic [3:0]  be
);
  always_comb begin
    case (funct3[1:0])
      2'b00:   begin wdata_out = {4{wdata_in[7:0]}};  be = 4'b0001 << addr_lo;        end
      2'b01:   begin wdata_out = {2{wdata_in[15:0]}}; be = addr_lo[1] ? 4'b1100 : 4'b0011; end
      default: begin wdata_out = wdata_in;            be = 4'b1111;                   end
    endcase
  end
endmodule

// Load-side formatter: selects the byte/half and sign- or zero-extends.
module lsu_load (
  input  logic [2:0]  funct3,       // 000 LB, 001 LH, 010 LW, 100 LBU, 101 LHU
  input  logic [1:0]  addr_lo,
  input  logic [31:0] rword,        // aligned word read from memory
  output logic [31:0] rdata
);
  logic [7:0]  b;
  logic [15:0] h;
  always_comb begin
    b = rword[8*addr_lo +: 8];
    h = addr_lo[1] ? rword[31:16] : rword[15:0];
    case (funct3)
      3'b000:  rdata = {{24{b[7]}},  b};    // LB
      3'b100:  rdata = {24'b0,       b};    // LBU
      3'b001:  rdata = {{16{h[15]}}, h};    // LH
      3'b101:  rdata = {16'b0,       h};    // LHU
      default: rdata = rword;               // LW
    endcase
  end
endmodule
