//==============================================================================
// pc.v — Program Counter
//==============================================================================
//
// 【Circuit Architecture】
//   Function: 32-bit instruction address register with async reset.
//
//   Data Path (32-bit):
//     pc_nxt[31:0] → [32× DFF] → pc[31:0]
//
//   Control Path:
//     rst_n → DFF async reset (pc=RESET_VECTOR when rst_n=0)
//
//   Path Separation:
//     Pure data path — no address/parameter path complexity.
//     Control path has only reset (fanout=32 DFF RST pins).
//     Zero combinational logic between DFF Q and next stage.
//
// 【Macro Mapping & PPA】
//   Macros:
//     32× DFF (async reset, no enable)
//
//   Interconnect:
//     pc_nxt → DFF.D (fanout=1, direct)
//     rst_n → DFF.RST (fanout=32, reset tree needs buffer)
//     clk → DFF.CK (fanout=32, clock tree auto-balanced)
//
//   PPA (precision: low — logic analysis):
//     Area: 32 DFF ≈ 192 gate equivalents (lightweight)
//     Timing: CK→Q ≈ 1 DFF delay, zero combinational path
//     Power: dominated by clock toggling (32 DFF CK pins)
//
// 【RTL Code】
//==============================================================================

module pc
#(
  parameter RESET_VECTOR = 32'h0000_0000
)
(
  input  wire        clk,
  input  wire        rst_n,
  input  wire [31:0] pc_nxt,
  output reg  [31:0] pc
);

  // 32× DFF with async reset — pure sequential logic
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      pc <= RESET_VECTOR;
    end
    else
    begin
      pc <= pc_nxt;
    end
  end

endmodule
