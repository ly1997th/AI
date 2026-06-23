//==============================================================================
// regfile.v — Register File (32×32-bit, 2-read 1-write)
//==============================================================================
//
// 【Circuit Architecture】
//   Function: 32-entry × 32-bit general-purpose register array. x0 hardwired to zero.
//
//   Write Path (sequential):
//     wr_dat[31:0] → [per-bit wr_dat MUX] → rf[wr_addr][31:0]
//                         ↑
//                    wr_en & (wr_addr != 0)
//
//   Read Path (combinational, zero-cycle latency):
//     rf[rd_addr0] → [x0 bypass] → rd_dat0[31:0]
//     rf[rd_addr1] → [x0 bypass] → rd_dat1[31:0]
//
//   Address Path (5-bit):
//     rd_addr0[4:0] → [5:32 Decoder] → 32 read wordlines (port 0)
//     rd_addr1[4:0] → [5:32 Decoder] → 32 read wordlines (port 1)
//     wr_addr[4:0]  → [5:32 Decoder] → 32 write wordlines
//
//   Control Path:
//     wr_en → write enable gating (AND with wr_addr≠0 condition)
//             fanout=32 (drives WE pin of all 32 registers)
//
//   Path Separation:
//     Data path: 32-bit wide, through MUX network (read path critical timing)
//     Address path: 5-bit decoder → 32 one-hot wordlines, very high fanout
//                   (each wordline drives 32 bit-cells), needs buffer tree
//     Control path: wr_en fanout=32, moderate buffering needed
//     Critical path: addr decode → wordline drive → bit-cell read → MUX cascade
//                    ≈ 1(decoder) + 1(wl) + 5(mux stages) ≈ 7 logic levels
//
// 【Macro Mapping & PPA】
//   Macros:
//     32×32 DFF array (1024 DFF total, forming rf[31:0])
//     2× 5:32 Decoder (read address decode, one-hot output)
//     1× 5:32 Decoder (write address decode)
//     2× 32-to-1 32-bit MUX (read port 0/1, dominant area contributor)
//     1× 5-bit Comparator (wr_addr == 0 detection, x0 write protection)
//     2× 32-bit 2-to-1 MUX (x0 read bypass)
//
//   Interconnect (high fanout concerns):
//     Decoder → wordlines (fanout=32 per line, buffer tree required)
//     Wordline → bit-cell select (fanout=32 DFF per wordline)
//     Read MUX cascade: 32→16→8→4→2→1 (5-stage MUX tree)
//     wr_en AND (wr_addr≠0) → 32 register WE pins (fanout=32)
//
//   PPA (precision: low — logic analysis):
//     Area: ~1024 DFF + 3 decoders + 2 large MUX trees ≈ 3000-5000 gate equiv
//           Register file is one of the largest area modules in the datapath
//     Timing: critical path ≈ 7 logic levels
//             Actual delay strongly depends on process library and bit-cell drive
//     Power: clock toggling dominates (1024 DFF CK pins)
//            Read ports are combinational, zero clock power
//     Process sensitivity: RF2P vs RF1P area delta varies 10%-100% across nodes
//
// 【RTL Code】
//==============================================================================

module regfile
(
  input  wire        clk,
  input  wire        rst_n,
  // Read port 0
  input  wire [4:0]  rd_addr0,
  output wire [31:0] rd_dat0,
  // Read port 1
  input  wire [4:0]  rd_addr1,
  output wire [31:0] rd_dat1,
  // Write port
  input  wire [4:0]  wr_addr,
  input  wire        wr_en,
  input  wire [31:0] wr_dat
);

  // 32×32 DFF array (synthesis maps to DFF or SRAM depending on target)
  reg [31:0] rf [31:0];

  //------------------------------------------------------------------------------
  // Read Path: 2× 32-to-1 32-bit MUX + x0 bypass
  // Pure combinational, zero clock latency
  //------------------------------------------------------------------------------
  // x0 hardware: when addr==0, force zero; otherwise read rf[addr] (MUX select)
  assign rd_dat0 = (rd_addr0 == 5'b0) ? 32'b0 : rf[rd_addr0];
  assign rd_dat1 = (rd_addr1 == 5'b0) ? 32'b0 : rf[rd_addr1];

  //------------------------------------------------------------------------------
  // Write Path: 1× 5:32 Decoder + 32× DFF (with write enable)
  // Sequential: posedge clk write
  //------------------------------------------------------------------------------
  // Address decode: wr_addr → 5:32 Decoder → selects 1 register
  // Write protection: x0 (wr_addr=0) write enable is hardware-masked
  integer i;
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      for (i = 0; i < 32; i = i + 1)
      begin
        rf[i] <= 32'b0;
      end
    end
    else if (wr_en && (wr_addr != 5'b0))
    begin
      rf[wr_addr] <= wr_dat;
    end
  end

endmodule
