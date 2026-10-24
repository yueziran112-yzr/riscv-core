// Wrapper: multiplier + iterative divider behind one start/done handshake.
//   funct3[2] = 0 -> multiplier (MUL, MULH, MULHSU, MULHU)
//   funct3[2] = 1 -> divider    (DIV, DIVU, REM, REMU)
//   MUL_IMPL selects the multiplier micro-architecture:
//     1 = radix-2 iterative, left shift (mul_iter.sv)  
//     0, 2, 3, 4 are added in chapter 6 (comb, right shift, Booth radix-4, 2-stage pipelined)
//   start : 1-cycle pulse, only while `idle`
//   done  : 1-cycle pulse, `result` is valid in that cycle
module muldiv_unit #(parameter int MUL_IMPL = 1) (
  input  logic        clk, rst_n,
  input  logic        start,
  input  logic [2:0]  f3,
  input  logic [31:0] a, b,
  output logic        idle, done,
  output logic [31:0] result
);
  logic m_busy, m_done, d_busy, d_done;
  logic [31:0] m_res, d_res;

  // chapter 6: replace this line with a `generate case (MUL_IMPL)` that picks the multiplier
  mul_iter u_mul (.clk, .rst_n, .start(start & ~f3[2]), .a, .b, .mode(f3[1:0]),
                  .busy(m_busy), .done(m_done), .result(m_res));

  div_iter u_div (.clk, .rst_n, .start(start &  f3[2]), .a, .b, .mode(f3[1:0]),
                  .busy(d_busy), .done(d_done), .result(d_res));

  // idle must not depend on a combinational `done`
  assign idle   = ~(m_busy | d_busy | m_done | d_done);
  assign done   = m_done | d_done;
  assign result = d_done ? d_res : m_res;
endmodule
