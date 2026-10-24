// Iterative restoring divider, 32 cycles. Handles DIV/DIVU/REM/REMU including the
// RISC-V special cases (divide by zero, INT_MIN / -1).
module div_iter (
  input  logic        clk, rst_n,
  input  logic        start,
  input  logic [31:0] a, b,          // a = dividend, b = divisor
  input  logic [1:0]  mode,          // funct3[1:0]: 00 DIV, 01 DIVU, 10 REM, 11 REMU
  output logic        busy, done,
  output logic [31:0] result
);
  typedef enum logic [1:0] {S_IDLE, S_RUN, S_DONE} state_t;
  state_t      state;
  logic [31:0] rem, quo, dvsr;
  logic [5:0]  cnt;
  logic        q_neg, r_neg, want_rem;

  wire sgn   = ~mode[0];                       // DIV, REM are signed
  wire a_neg = sgn && a[31];
  wire b_neg = sgn && b[31];
  wire [31:0] a_abs = a_neg ? (~a + 32'd1) : a;
  wire [31:0] b_abs = b_neg ? (~b + 32'd1) : b;

  wire [32:0] sh   = {rem, quo[31]};           // shift in next dividend bit
  wire        ge   = (sh >= {1'b0, dvsr});
  wire [32:0] diff = sh - {1'b0, dvsr};

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= S_IDLE;
    else begin
      case (state)
        S_IDLE: if (start) begin
          quo      <= a_abs;
          rem      <= 32'b0;
          dvsr     <= b_abs;
          cnt      <= 6'd0;
          q_neg    <= (a_neg ^ b_neg) && (b != 32'b0);   // divide-by-zero: quotient stays all ones
          r_neg    <= a_neg;
          want_rem <= mode[1];
          state    <= S_RUN;
        end
        S_RUN: begin
          rem <= ge ? diff[31:0] : sh[31:0];
          quo <= {quo[30:0], ge};
          cnt <= cnt + 6'd1;
          if (cnt == 6'd31) state <= S_DONE;
        end
        S_DONE: state <= S_IDLE;
        default: state <= S_IDLE;
      endcase
    end
  end

  assign result = want_rem ? (r_neg ? (~rem + 32'd1) : rem)
                           : (q_neg ? (~quo + 32'd1) : quo);
  assign busy   = (state == S_RUN);
  assign done   = (state == S_DONE);
endmodule
