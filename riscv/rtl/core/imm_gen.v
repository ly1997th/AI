//==============================================================================
// imm_gen.v — Immediate Generator
//==============================================================================
//
// 【Circuit Architecture】
//   Function: Extract and sign-extend the immediate field from a 32-bit instruction.
//
//   Data Path (pure wiring reorder + MUX, zero logic gates):
//     instr[31:0] ─┬─→ I-type wire reorder ─┐
//                  ├─→ S-type wire reorder ─┤
//                  ├─→ B-type wire reorder ─┤
//                  ├─→ U-type wire reorder ─┤
//                  ├─→ J-type wire reorder ─┤
//                  └─→ default (zero) ──────┤
//                                           ├─→ [6-to-1 MUX] → imm_dat
//                                           │        ↑
//   Control Path (7-bit opcode):         opcode[6:0]
//     opcode → 6-to-1 MUX select
//
//   Path Separation:
//     Data path: 32-bit pure wire reorder, zero gate delay
//     Control path: opcode 7-bit → MUX select (fanout=1)
//     No reconvergence risk (immediates from non-overlapping instr fields)
//     Critical path: single MUX stage (shortest combinational path in the design)
//
// 【Macro Mapping & PPA】
//   Macros:
//     6× wire reorder blocks (bit concatenation, pure wiring, zero gates)
//     1× 6-to-1 32-bit MUX (the sole active unit)
//
//   Interconnect:
//     instr → 6 reorder blocks (fanout=6, width=32, pure fanout, no logic)
//     opcode → MUX select (fanout=1, 7-bit)
//
//   PPA (precision: low — logic analysis):
//     Area: 1× 6-to-1 32-bit MUX ≈ 160 gate equiv (lightweight)
//     Timing: single MUX stage (~0.1ns scale), non-critical path
//     Power: minimal (only MUX internal node toggling, zero clock-related power)
//
// 【RTL Code】
//==============================================================================

module imm_gen
(
  input  wire [31:0] instr,
  output reg  [31:0] imm_dat
);

  // opcode extraction (control path input to the "decoder")
  wire [6:0] opcode = instr[6:0];

  // 6-to-1 32-bit MUX: select immediate format by opcode
  // Each format is pure wire reorder (bit concatenation), zero extra gates
  always @(*)
  begin
    case (opcode)
      // I-type: imm_dat = {{20{instr[31]}}, instr[31:20]}
      7'b0010011,   // I-type ALU (addi, slti, etc.)
      7'b0000011,   // Load (lw, lh, lb, etc.)
      7'b1100111:   // JALR
      begin
        imm_dat = {{20{instr[31]}}, instr[31:20]};
      end

      // S-type: imm_dat = {{20{instr[31]}}, instr[31:25], instr[11:7]}
      7'b0100011:   // Store (sw, sh, sb)
      begin
        imm_dat = {{20{instr[31]}}, instr[31:25], instr[11:7]};
      end

      // B-type: imm_dat = {{19{instr[31]}}, instr[31], instr[7],
      //                     instr[30:25], instr[11:8], 1'b0}
      7'b1100011:   // Branch (beq, bne, blt, etc.)
      begin
        imm_dat = {{19{instr[31]}}, instr[31], instr[7],
                    instr[30:25], instr[11:8], 1'b0};
      end

      // U-type: imm_dat = {instr[31:12], 12'b0}
      7'b0110111,   // LUI
      7'b0010111:   // AUIPC
      begin
        imm_dat = {instr[31:12], 12'b0};
      end

      // J-type: imm_dat = {{11{instr[31]}}, instr[31], instr[19:12],
      //                     instr[20], instr[30:21], 1'b0}
      7'b1101111:   // JAL
      begin
        imm_dat = {{11{instr[31]}}, instr[31], instr[19:12],
                    instr[20], instr[30:21], 1'b0};
      end

      default:
      begin
        imm_dat = 32'b0;
      end
    endcase
  end

endmodule
