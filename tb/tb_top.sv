`timescale 1ns/1ps
// System testbench: unified RAM model + riscv_core + tohost monitor + CPI counters + commit trace.
// Plusargs: +HEX=<file> +TOHOST=<hex addr> [+TRACE=<file>] [+TIMEOUT=<cycles>] [+WAVE -> wave.vcd]
module tb_top #(parameter int MUL_IMPL = 1, parameter int BP = 0);
  localparam int          MEM_WORDS = 16384;                 // 64 KiB
  localparam logic [31:0] BASE      = 32'h8000_0000;

  logic clk = 0, rst_n = 0;
  always #5 clk = ~clk;

  logic [31:0] mem [0:MEM_WORDS-1];
  logic [31:0] imem_addr, imem_rdata, dmem_addr, dmem_wdata, dmem_rdata;
  logic [3:0]  dmem_be;  logic dmem_re;
  logic        r_valid, r_we;  logic [31:0] r_pc, r_instr, r_data;  logic [4:0] r_rd;

  riscv_core #(.MUL_IMPL(MUL_IMPL), .BP(BP)) dut (.clk, .rst_n, .imem_addr, .imem_rdata, .dmem_addr, .dmem_wdata, .dmem_be, .dmem_re, .dmem_rdata,
                  .retire_valid(r_valid), .retire_pc(r_pc), .retire_instr(r_instr), .retire_rd(r_rd),
                  .retire_we(r_we), .retire_data(r_data));

  longint cycles = 0, instret = 0;

  // ---------- memory model (async read, sync write) ----------
  wire [31:0] iidx = (imem_addr - BASE) >> 2;
  wire [31:0] didx = (dmem_addr - BASE) >> 2;
  wire        iok  = (imem_addr >= BASE) && (iidx < MEM_WORDS);
  wire        dok  = (dmem_addr >= BASE) && (didx < MEM_WORDS);
  assign imem_rdata = iok ? mem[iidx[13:0]] : 32'h0000_0013;   // out of range -> NOP
  // simple MMIO (SoC stand-in):  0x1000_0000 UART TX (write a byte)   0x1000_0008 cycle counter (read)
  localparam logic [31:0] UART_TX = 32'h1000_0000, MTIME = 32'h1000_0008;
  assign dmem_rdata = dok ? mem[didx[13:0]] : (dmem_addr == MTIME) ? cycles[31:0] : 32'h0;
  always_ff @(posedge clk)
    if (dok) for (int i = 0; i < 4; i++) if (dmem_be[i]) mem[didx[13:0]][8*i +: 8] <= dmem_wdata[8*i +: 8];

  // ---------- run control ----------
  string hexfile, tracefile;  logic [31:0] tohost;  int timeout = 200000;  int tfd = 0;

  initial begin
    for (int i = 0; i < MEM_WORDS; i++) mem[i] = 32'h0;
    if (!$value$plusargs("HEX=%s", hexfile))      begin $display("ERROR: need +HEX=file");     $finish; end
    if (!$value$plusargs("TOHOST=%h", tohost))    begin $display("ERROR: need +TOHOST=addr");  $finish; end
    void'($value$plusargs("TIMEOUT=%d", timeout));
    $readmemh(hexfile, mem);
    if ($value$plusargs("TRACE=%s", tracefile)) tfd = $fopen(tracefile, "w");
    if ($test$plusargs("WAVE")) begin $dumpfile("wave.vcd"); $dumpvars(0, tb_top); end   // needs verilator --trace
    repeat (4) @(posedge clk);
    rst_n = 1;
  end

  always @(posedge clk) if (rst_n) begin
    cycles <= cycles + 1;
    if (r_valid) begin
      instret <= instret + 1;
      if (tfd != 0) begin
        if (r_we) $fdisplay(tfd, "core   0: 3 0x%08h (0x%08h) x%0d 0x%08h", r_pc, r_instr, r_rd, r_data);
        else      $fdisplay(tfd, "core   0: 3 0x%08h (0x%08h)", r_pc, r_instr);
      end
    end
    if (dmem_be[0] && dmem_addr == UART_TX) $write("%c", dmem_wdata[7:0]);
    if (dmem_be != 0 && dmem_addr == tohost) begin
      if (dmem_wdata == 32'd1) $display("RESULT PASS cycles=%0d instret=%0d", cycles, instret);
      else                     $display("RESULT FAIL testcase=%0d cycles=%0d instret=%0d", dmem_wdata >> 1, cycles, instret);
      $finish;
    end
    if (cycles > timeout) begin $display("RESULT TIMEOUT cycles=%0d instret=%0d", cycles, instret); $finish; end
  end
endmodule
