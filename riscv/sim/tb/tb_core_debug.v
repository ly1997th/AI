//==============================================================================
// tb_core_debug.v — Debug Testbench (Branch Logic)
//==============================================================================
// Dedicated test for BEQ branch behavior with hierarchical signal probing.
//==============================================================================

`timescale 1ns / 1ps

module tb_core_debug;

  reg         clk;
  reg         rst_n;
  wire [31:0] imem_rd_dat;
  wire [31:0] imem_rd_addr;
  wire [31:0] dmem_addr, dmem_wr_dat, dmem_rd_dat;
  wire        dmem_wr_en, dmem_rd_en;

  reg  [31:0] mem [0:255];

  // DUT
  core u_core
  (
    .clk(clk), .rst_n(rst_n),
    .imem_rd_dat(imem_rd_dat), .imem_rd_addr(imem_rd_addr),
    .dmem_addr(dmem_addr), .dmem_wr_dat(dmem_wr_dat),
    .dmem_rd_dat(dmem_rd_dat),
    .dmem_wr_en(dmem_wr_en), .dmem_rd_en(dmem_rd_en)
  );

  initial clk = 0;
  always #5 clk = ~clk;
  assign imem_rd_dat = mem[imem_rd_addr[31:2]];
  assign dmem_rd_dat = (dmem_rd_en) ? mem[dmem_addr[31:2]] : 32'b0;
  always @(posedge clk)
  begin
    if (dmem_wr_en) mem[dmem_addr[31:2]] <= dmem_wr_dat;
  end

  // Hierarchical signal probes (updated for new signal names)
  wire [31:0] alu_opa    = u_core.alu_opa;
  wire [31:0] alu_opb    = u_core.alu_opb;
  wire [31:0] alu_dat    = u_core.alu_dat;
  wire        alu_zero_flag = u_core.alu_zero_flag;
  wire [3:0]  alu_op     = u_core.alu_op;
  wire        pc_branch_en = u_core.pc_branch_en;
  wire        pc_jump_en = u_core.pc_jump_en;
  wire        pc_jalr_en = u_core.pc_jalr_en;
  wire [2:0]  funct3     = u_core.funct3;
  wire        pc_branch_taken = u_core.pc_branch_taken;
  wire [31:0] pc_nxt     = u_core.pc_nxt;
  wire [31:0] rf_x3      = u_core.u_regfile.rf[3];

  // Waveform
  initial
  begin
    $dumpfile("tb_core_debug.vcd");
    $dumpvars(0, tb_core_debug);
  end

  initial
  begin
    for (integer i = 0; i < 256; i = i + 1) mem[i] = 32'b0;

    // Minimal test: 3 instructions
    // 0x00: addi x3, x0, 5    (set x3 to known value)
    // 0x04: beq  x3, x3, +8   (compare self → must branch)
    // 0x08: addi x5, x0, 99   (should SKIP!)
    // 0x0C: addi x6, x0, 42   (beq target)
    mem[0] = 32'h00500193;   // addi x3, x0, 5
    mem[1] = 32'h00318463;   // beq  x3, x3, +8 (offset=8 → imm[4:1]=4)
    mem[2] = 32'h06300293;   // addi x5, x0, 99 (should SKIP)
    mem[3] = 32'h02a00313;   // addi x6, x0, 42 (beq target)

    $display("=========================================");
    $display("  BEQ Branch Debug Test");
    $display("=========================================");
    $display("  mem[0]=addi x3,5  @ 0x00");
    $display("  mem[1]=beq x3,x3,+8 @ 0x04 → target 0x0C");
    $display("  mem[2]=addi x5,99 @ 0x08 (SHOULD SKIP)");
    $display("  mem[3]=addi x6,42 @ 0x0C (target)");

    rst_n = 0;
    #12 rst_n = 1;

    integer cycle;
    for (cycle = 1; cycle <= 10; cycle = cycle + 1)
    begin
      @(posedge clk);
      #1;
      $display("--- Cycle %0d (t=%0t) ---", cycle, $time);
      $display("  PC          = 0x%h", imem_rd_addr);
      $display("  imem_rd_dat = 0x%h", imem_rd_dat);
      $display("  opcode      = 0b%b", imem_rd_dat[6:0]);
      $display("  funct3      = 0b%b", funct3);
      $display("  rf[x3]      = %0d", rf_x3);
      $display("  alu_opa     = %0d", alu_opa);
      $display("  alu_opb     = %0d", alu_opb);
      $display("  alu_op      = 0b%b", alu_op);
      $display("  alu_dat     = %0d", alu_dat);
      $display("  alu_zero    = %b", alu_zero_flag);
      $display("  pc_branch_en= %b", pc_branch_en);
      $display("  branch_taken= %b", pc_branch_taken);
      $display("  pc_nxt      = 0x%h", pc_nxt);
      $display("");
    end

    $display("Final rf[x3] = %0d", rf_x3);
    $display("Final rf[x5] = %0d (expected 0)", u_core.u_regfile.rf[5]);
    $display("Final rf[x6] = %0d (expected 42)", u_core.u_regfile.rf[6]);
    if (u_core.u_regfile.rf[5] == 0 && u_core.u_regfile.rf[6] == 42)
    begin
      $display("BEQ BRANCH: PASS");
    end
    else
    begin
      $display("BEQ BRANCH: FAIL (x5=%0d, x6=%0d)",
                u_core.u_regfile.rf[5], u_core.u_regfile.rf[6]);
    end

    #20 $finish;
  end

endmodule
