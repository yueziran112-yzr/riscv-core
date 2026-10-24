// Iterative shift-add multiplier, 32 cycles. Handles MUL/MULH/MULHSU/MULHU.
//   start : 1-cycle pulse while idle; keep a, b, mode stable until `done`
//   done  : 1-cycle pulse, `result` is valid in that cycle
module mul_iter (
  input  logic        clk, rst_n,
  input  logic        start,
  input  logic [31:0] a, b,
  input  logic [1:0]  mode,          // funct3[1:0]: 00 MUL, 01 MULH, 10 MULHSU, 11 MULHU
  output logic        busy, done,
  output logic [31:0] result
);
  typedef enum logic [1:0] {S_IDLE, S_RUN, S_DONE} state_t;
  state_t      state;
  logic [63:0] mcand, acc;
  logic [31:0] mplier;
  logic [5:0]  cnt;
  logic        neg, hi;

  wire a_signed = (mode == 2'b01) || (mode == 2'b10);
  wire b_signed = (mode == 2'b01);
  wire a_neg    = a_signed && a[31];
  wire b_neg    = b_signed && b[31];
  wire [31:0] a_abs = a_neg ? (~a + 32'd1) : a;
  wire [31:0] b_abs = b_neg ? (~b + 32'd1) : b;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= S_IDLE;
    else begin
      case (state)
        S_IDLE: if (start) begin
          mcand  <= {32'b0, a_abs};
          mplier <= b_abs;
          acc    <= 64'b0;
          cnt    <= 6'd0;
          neg    <= a_neg ^ b_neg;
          hi     <= (mode != 2'b00);
          state  <= S_RUN;
        end
        S_RUN: begin
          if (mplier[0]) acc <= acc + mcand;
          mcand  <= mcand << 1;
          mplier <= mplier >> 1;
          cnt    <= cnt + 6'd1;
          if (cnt == 6'd31) state <= S_DONE;
        end
        S_DONE: state <= S_IDLE;
        default: state <= S_IDLE;
      endcase
    end
  end

  wire [63:0] prod = neg ? (~acc + 64'd1) : acc;
  assign result = hi ? prod[63:32] : prod[31:0];
  assign busy   = (state == S_RUN);
  assign done   = (state == S_DONE);
endmodule
