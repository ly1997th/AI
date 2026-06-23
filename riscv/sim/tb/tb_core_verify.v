//==============================================================================
// tb_core_verify.v — Core Verification Testbench
//==============================================================================
// Verifies register state after running a 7-instruction test program.
// Uses hierarchical access to probe regfile internal state.
//
// Test Program:
//   addi x1, x0, 5      # x1 = 5
//   addi x2, x0, 3      # x2 = 3
//   add  x3, x1, x2     # x3 = 8
//   sub  x4, x1, x2     # x4 = 2
//   beq  x3, x3, +8     # branch taken → skip next
//   addi x5, x0, 99     # SKIPPED (x5 = 0)
//   addi x6, x0, 42     # executed (x6 = 42)
//==============================================================================

`timescale 1ns / 1ps

module tb_core_verify;

  reg         clk;
  reg         rst_n;
  wire [31:0] imem_rd_dat;
  wire [31:0] imem_rd_addr;
  wire [31:0] dmem_addr;
  wire [31:0] dmem_wr_dat;
  wire [31:0] dmem_rd_dat;
  wire        dmem_wr_en;
  wire        dmem_rd_en;

  reg  [31:0] mem [0:255];

  // DUT
  core u_core
  (
    .clk          (clk),
    .rst_n        (rst_n),
    .imem_rd_dat  (imem_rd_dat),
    .imem_rd_addr (imem_rd_addr),
    .dmem_addr    (dmem_addr),
    .dmem_wr_dat  (dmem_wr_dat),
    .dmem_rd_dat  (dmem_rd_dat),
    .dmem_wr_en   (dmem_wr_en),
    .dmem_rd_en   (dmem_rd_en)
  );

  // Clock generation
  initial clk = 0;
  always #5 clk = ~clk;

  // Instruction memory read (combinational)
  assign imem_rd_dat = mem[imem_rd_addr[31:2]];

  // Data memory r/w
  assign dmem_rd_dat = (dmem_rd_en) ? mem[dmem_addr[31:2]] : 32'b0;
  always @(posedge clk)
  begin
    if (dmem_wr_en)
    begin
      mem[dmem_addr[31:2]] <= dmem_wr_dat;
    end
  end

  // Hierarchical register probes
  wire [31:0] rf [0:31];
  genvar gi;
  generate
    for (gi = 0; gi < 32; gi = gi + 1)
    begin : gen_rf_probe
      assign rf[gi] = u_core.u_regfile.rf[gi];
    end
  endgenerate

  integer pass_count, fail_count;

  // Waveform
  initial
  begin
    $dumpfile("tb_core_verify.vcd");
    $dumpvars(0, tb_core_verify);
  end

  // Verification task
  task verify_reg;
    input [255:0] name;
    input [4:0]   reg_num;
    input [31:0]  expected;
    begin
      if (rf[reg_num] === expected)
      begin
        $display("  %0s (x%0d) = %0d [PASS]", name, reg_num, rf[reg_num]);
        pass_count = pass_count + 1;
      end
      else
      begin
        $display("  %0s (x%0d) = %0d, expected %0d [FAIL]",
                  name, reg_num, rf[reg_num], expected);
        fail_count = fail_count + 1;
      end
    end
  endtask

  // Main test flow
  initial
  begin
    pass_count = 0; fail_count = 0;

    $display("=========================================");
    $display("  RISC-V Core Verification");
    $display("=========================================");

    // Initialize memory
    for (integer i = 0; i < 256; i = i + 1)
    begin
      mem[i] = 32'b0;
    end

    // Load test program (verified machine codes)
    mem[0] = 32'h00500093;   // addi x1, x0, 5
    mem[1] = 32'h00300113;   // addi x2, x0, 3
    mem[2] = 32'h002081b3;   // add  x3, x1, x2
    mem[3] = 32'h40208233;   // sub  x4, x1, x2
    mem[4] = 32'h00318463;   // beq  x3, x3, +8 (skip 2 instrs → 0x18)
    mem[5] = 32'h06300293;   // addi x5, x0, 99 (SKIPPED)
    mem[6] = 32'h02a00313;   // addi x6, x0, 42 (branch target)

    $display("");
    $display("Test Program:");
    $display("  [0x00] addi x1, 5");
    $display("  [0x04] addi x2, 3");
    $display("  [0x08] add  x3, x1, x2  → x3=8");
    $display("  [0x0C] sub  x4, x1, x2  → x4=2");
    $display("  [0x10] beq  x3, x3, +8  → jump to 0x18");
    $display("  [0x14] addi x5, 99       → SKIPPED");
    $display("  [0x18] addi x6, 42       → executed");
    $display("");

    // Reset
    rst_n = 0;
    #25 rst_n = 1;

    // Run enough cycles for all 7 instructions (~12 cycles margin)
    repeat(12) @(posedge clk);

    // Wait for signals to stabilize
    #2;

    $display("--- Final Register Verification ---");
    verify_reg("x1  (addi 5)",      1,  5);
    verify_reg("x2  (addi 3)",      2,  3);
    verify_reg("x3  (x1+x2=8)",     3,  8);
    verify_reg("x4  (x1-x2=2)",     4,  2);
    verify_reg("x5  (skipped=0)",   5,  0);
    verify_reg("x6  (target=42)",   6,  42);
    verify_reg("x0  (always 0)",    0,  0);
    verify_reg("x7  (unused)",      7,  0);

    $display("");
    $display("=========================================");
    $display("  Results: %0d PASS, %0d FAIL", pass_count, fail_count);
    if (fail_count == 0)
    begin
      $display("  ALL CPU TESTS PASSED!");
    end
    else
    begin
      $display("  SOME TESTS FAILED!");
    end
    $display("=========================================");

    #10 $finish;
  end

endmodule
