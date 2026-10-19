// Purely combinational M-extension reference 
// used by the single-cycle core and as a golden model
module muldiv_comb (
  input  logic [31:0] a, b,
  input  logic [2:0]  f3,         // MUL 000, MULH 001, MULHSU 010, MULHU 011, DIV 100, DIVU 101, REM 110, REMU 111
  output logic [31:0] y
);
  logic signed [63:0] p_ss, p_su, p_uu;
  assign p_ss = $signed({{32{a[31]}}, a}) * $signed({{32{b[31]}}, b});
  assign p_su = $signed({{32{a[31]}}, a}) * $signed({32'b0, b});
  assign p_uu = {32'b0, a} * {32'b0, b};

  wire ovf = (a == 32'h8000_0000) && (b == 32'hFFFF_FFFF);
  always_comb begin
    case (f3)
      3'b000: y = p_ss[31:0];
      3'b001: y = p_ss[63:32];
      3'b010: y = p_su[63:32];
      3'b011: y = p_uu[63:32];
      3'b100: y = (b == 0) ? 32'hFFFF_FFFF : ovf ? a : 32'($signed(a) / $signed(b));
      3'b101: y = (b == 0) ? 32'hFFFF_FFFF : a / b;
      3'b110: y = (b == 0) ? a : ovf ? 32'b0 : 32'($signed(a) % $signed(b));
      default:y = (b == 0) ? a : a % b;
    endcase
  end
endmodule
