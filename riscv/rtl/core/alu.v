//==============================================================================
// alu.v — Arithmetic Logic Unit
//==============================================================================
//
// 【Circuit Architecture】
//   Function: Execute all RV32I arithmetic/logic operations (pure combinational).
//
//   Data Path (2×32-bit in → 32-bit out):
//     opa[31:0] ─┬─→ [Adder] ──────┐
//     opb[31:0] ─┤                 │
//                ├─→ [XOR Array] ──┤
//                ├─→ [AND/OR Arr] ─┤
//                ├─→ [Shifter] ────┤
//                ├─→ [Comparator] ─┤
//                └─→ [zero detect] ┤→ [Result MUX] → dat
//                  (NOR tree)      │       ↑
//                                  │   op_sel[3:0]
//                                  └→ zero_flag
//
//   Control Path (4-bit op_sel → MUX select + function gating):
//     op_sel[3:0] → operation sub-function enables
//                 → 10-to-1 MUX select
//
//   Path Separation:
//     Data path: opa, opb are 32-bit, converge at Result MUX
//     Control path: op_sel 4-bit fans out to all sub-function blocks
//     Reconvergence point: Result MUX (paths with different delays merge)
//     Critical path: Adder (carry chain) > Shifter > Comparator
//
// 【Macro Mapping & PPA】
//   Macros:
//     1× 32-bit Adder (ADD/SUB shared; SUB = opa + ~opb + 1)
//     1× 32-bit Barrel Shifter (SLL/SRL/SRA shared)
//     1× 32-bit XOR Array (32 parallel XOR gates)
//     1× 32-bit AND/OR Array (AOI compound gate array)
//     1× 32-bit Comparator (signed/unsigned cascaded chain)
//     1× 10-to-1 32-bit MUX (result selection)
//     1× 32-input NOR (zero detection → tree expansion)
//
//   Interconnect:
//     opa,opb → all compute units (fanout=6, moderate)
//     op_sel → Result MUX select (fanout=4-bit, no buffer stress)
//     Reconvergence: opa,opb paths merge at Result MUX after different delays
//
//   PPA (precision: low — logic analysis):
//     Area: Adder(~200 gates) + Shifter(~300) + Comp(~100)
//           + MUX10:1_32b(~300) ≈ 1000 gate equiv (medium scale)
//     Timing: critical path = Adder carry chain(~10 stages) + MUX(~2 stages) ≈ 12 stages
//     Power: combinational dynamic power scales with input toggle rate
//
// 【RTL Code】
//==============================================================================

module alu
(
  input  wire [31:0] opa,
  input  wire [31:0] opb,
  input  wire [3:0]  op_sel,
  output reg  [31:0] dat,
  output wire        zero_flag
);

  // Operation encoding (matched with control_unit ALU Decoder)
  localparam OP_ADD  = 4'b0000;
  localparam OP_SUB  = 4'b0001;
  localparam OP_AND  = 4'b0010;
  localparam OP_OR   = 4'b0011;
  localparam OP_XOR  = 4'b0100;
  localparam OP_SLL  = 4'b0101;
  localparam OP_SRL  = 4'b0110;
  localparam OP_SRA  = 4'b0111;
  localparam OP_SLT  = 4'b1000;
  localparam OP_SLTU = 4'b1001;

  // 10-to-1 32-bit MUX: select result by op_sel
  always @(*)
  begin
    case (op_sel)
      OP_ADD:  dat = opa + opb;
      OP_SUB:  dat = opa - opb;
      OP_AND:  dat = opa & opb;
      OP_OR:   dat = opa | opb;
      OP_XOR:  dat = opa ^ opb;
      OP_SLL:  dat = opa << opb[4:0];
      OP_SRL:  dat = opa >> opb[4:0];
      OP_SRA:  dat = $signed(opa) >>> opb[4:0];
      OP_SLT:  dat = ($signed(opa) < $signed(opb)) ? 32'd1 : 32'd0;
      OP_SLTU: dat = (opa < opb) ? 32'd1 : 32'd0;
      default: dat = 32'b0;
    endcase
  end

  // Zero detection: 32-input NOR (asserted when dat == 0)
  assign zero_flag = (dat == 32'b0);

endmodule
