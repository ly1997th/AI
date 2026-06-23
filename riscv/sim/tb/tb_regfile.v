//==============================================================================
// tb_regfile.v — Register File Testbench
//==============================================================================
// Tests: basic r/w, x0 hardwired zero, dual-port read, write-disable, persistence
//==============================================================================

`timescale 1ns / 1ps

module tb_regfile;

  reg         clk;
  reg         rst_n;

  // Read ports
  reg  [4:0]  rd_addr0, rd_addr1;
  wire [31:0] rd_dat0, rd_dat1;

  // Write port
  reg  [4:0]  wr_addr;
  reg         wr_en;
  reg  [31:0] wr_dat;

  // DUT
  regfile u_regfile
  (
    .clk      (clk),
    .rst_n    (rst_n),
    .rd_addr0 (rd_addr0),
    .rd_dat0  (rd_dat0),
    .rd_addr1 (rd_addr1),
    .rd_dat1  (rd_dat1),
    .wr_addr  (wr_addr),
    .wr_en    (wr_en),
    .wr_dat   (wr_dat)
  );

  // Clock (100 MHz)
  initial clk = 0;
  always #5 clk = ~clk;

  // Waveform
  initial
  begin
    $dumpfile("tb_regfile.vcd");
    $dumpvars(0, tb_regfile);
  end

  // Test flow
  initial
  begin
    $display("===== Register File Testbench =====");

    // Reset
    rst_n = 0; wr_en = 0;
    #20 rst_n = 1;

    // Test 1: basic write/read x5 = 0xDEADBEEF
    @(negedge clk);
    wr_addr = 5'd5; wr_dat = 32'hDEADBEEF; wr_en = 1;
    @(negedge clk);
    wr_en = 0;
    rd_addr0 = 5'd5;
    #10;
    $display("Write/Read x5: rd_dat0 = %h (expected DEADBEEF) %s",
              rd_dat0, (rd_dat0 === 32'hDEADBEEF) ? "PASS" : "FAIL");

    // Test 2: write x10 = 42
    @(negedge clk);
    wr_addr = 5'd10; wr_dat = 32'd42; wr_en = 1;
    @(negedge clk);
    wr_en = 0;
    rd_addr0 = 5'd10;
    #10;
    $display("Write/Read x10: rd_dat0 = %0d (expected 42) %s",
              rd_dat0, (rd_dat0 == 32'd42) ? "PASS" : "FAIL");

    // Test 3: x0 is hardware zero (write ignored)
    @(negedge clk);
    wr_addr = 5'd0; wr_dat = 32'hCAFEBABE; wr_en = 1;
    @(negedge clk);
    wr_en = 0;
    rd_addr0 = 5'd0;
    #10;
    $display("x0 read: rd_dat0 = %h (expected 00000000) %s",
              rd_dat0, (rd_dat0 === 32'b0) ? "PASS" : "FAIL");

    // Test 4: dual-port simultaneous read
    @(negedge clk);
    wr_addr = 5'd7; wr_dat = 32'd100; wr_en = 1;    // x7 = 100
    @(negedge clk);
    wr_addr = 5'd8; wr_dat = 32'd200; wr_en = 1;    // x8 = 200
    @(negedge clk);
    wr_en = 0;
    rd_addr0 = 5'd7; rd_addr1 = 5'd8;
    #10;
    $display("Dual read: rd_dat0=%0d rd_dat1=%0d (expected 100,200) %s",
              rd_dat0, rd_dat1,
              (rd_dat0 == 32'd100 && rd_dat1 == 32'd200) ? "PASS" : "FAIL");

    // Test 5: data persistence (x5, x10 still hold original values)
    rd_addr0 = 5'd5; rd_addr1 = 5'd10;
    #10;
    $display("Persistence: x5=%h x10=%0d %s",
              rd_dat0, rd_dat1,
              (rd_dat0 === 32'hDEADBEEF && rd_dat1 == 32'd42) ? "PASS" : "FAIL");

    // Test 6: wr_en=0 prevents write
    @(negedge clk);
    wr_addr = 5'd10; wr_dat = 32'd999; wr_en = 0;   // should NOT write
    @(negedge clk);
    rd_addr0 = 5'd10;
    #10;
    $display("Write-disable: x10=%0d (expected 42, not 999) %s",
              rd_dat0, (rd_dat0 == 32'd42) ? "PASS" : "FAIL");

    #20 $display("===== Register File Testbench Complete =====");
    $finish;
  end

endmodule
