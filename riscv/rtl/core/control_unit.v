//==============================================================================
// control_unit.v — Control Unit (Two-Level Decode)
//==============================================================================
//
// 【Circuit Architecture】
//   Function: Decode instruction opcode → generate all datapath control signals.
//   Two-level decode: Main Decoder + ALU Decoder.
//
//   Topology (2-stage decode tree):
//     ┌──────────────────┐
//     │  Main Decoder    │  rf_wr_en, alu_op2_sel, dmem_wr_en,
//     │  opcode[6:0]     │  dmem_rd_en, rf_wr_sel, pc_branch_en,
//     │      ↓           │  pc_jump_en, pc_jalr_en, alu_op_sel[1:0]
//     │  7:10 Decoder    │
//     └──────────────────┘
//              │
//              │ alu_op_sel[1:0]
//              ↓
//     ┌──────────────────────────────┐
//     │  ALU Decoder (combinational  │
//     │              LUT)            │
//     │  alu_op_sel[1:0] ─┐          │
//     │  funct3[2:0] ─────┤          │
//     │  funct7_5 ────────┘          │
//     │           ↓                  │
//     │  3-level selection tree      │→ alu_op[3:0]
//     └──────────────────────────────┘
//
//   Path Separation (pure control path, zero data/address path):
//     Stage 1: opcode(7-bit) → 9 independent outputs (Main Decoder)
//     Stage 2: {alu_op_sel, funct3, funct7_5}(6-bit) → alu_op(4-bit)
//     All outputs are control signals, width ≤ 1-bit, point-to-point fanout
//     Critical path: opcode→Main Decoder→alu_op_sel→ALU Decoder→alu_op
//                    ≈ 2 decoder stages, extremely short
//
// 【Macro Mapping & PPA】
//   Macros:
//     1× 7:10 Decoder (Main Decoder: opcode → 9 outputs + alu_op_sel)
//     1× Combinational LUT (ALU Decoder: 6-bit in → 4-bit out)
//
//   Interconnect (all point-to-point, minimal fanout):
//     opcode → Main Decoder (fanout=1, self-contained)
//     rf_wr_en → regfile.wr_en (fanout=1)
//     alu_op2_sel → ALU src MUX in core (fanout=1)
//     pc_branch_en → PC next logic in core (fanout=1)
//     alu_op → ALU op_sel (fanout=1, 4-bit)
//
//   PPA (precision: low — logic analysis):
//     Area: Main Decoder(~50 gates) + ALU Decoder LUT(~30 gates) ≈ 80 gate equiv
//           Control logic typically < 3% of total processor area
//     Timing: 2 decode stages ≈ 2-3 gate delays, far from critical path
//     Power: minimal (pure combinational, zero clock nodes)
//
// 【RTL Code】
//==============================================================================

module control_unit
(
  // Main Decoder input
  input  wire [6:0]  opcode,
  // Main Decoder outputs
  output reg         rf_wr_en,
  output reg         alu_op2_sel,
  output reg         dmem_wr_en,
  output reg         dmem_rd_en,
  output reg         rf_wr_sel,
  output reg         pc_branch_en,
  output reg         pc_jump_en,
  output reg         pc_jalr_en,
  output reg  [1:0]  alu_op_sel,

  // ALU Decoder inputs
  input  wire [2:0]  funct3,
  input  wire        funct7_5,
  // ALU Decoder output
  output reg  [3:0]  alu_op
);

  //==============================================================================
  // Stage 1: Main Decoder (7:10 Decoder)
  // opcode[6:0] → 9 control signals + alu_op_sel
  //==============================================================================
  always @(*)
  begin
    // Default: all zeros (safe state for invalid/ecall/ebreak opcodes)
    {rf_wr_en, alu_op2_sel, dmem_wr_en, dmem_rd_en,
     rf_wr_sel, pc_branch_en, pc_jump_en, pc_jalr_en} = 8'b0;
    alu_op_sel = 2'b00;

    case (opcode)
      // R-type (0110011): register-register ALU operation
      7'b0110011:
      begin
        rf_wr_en     = 1'b1;
        alu_op_sel   = 2'b10;  // use funct3+funct7 for further decode
      end

      // I-type ALU (0010011): immediate ALU operation
      7'b0010011:
      begin
        rf_wr_en     = 1'b1;
        alu_op2_sel  = 1'b1;   // ALU op2 from immediate
        alu_op_sel   = 2'b11;  // use funct3 for I-type further decode
      end

      // Load (0000011): read from memory
      7'b0000011:
      begin
        rf_wr_en     = 1'b1;
        alu_op2_sel  = 1'b1;   // address = rs1 + imm
        dmem_rd_en   = 1'b1;
        rf_wr_sel    = 1'b1;   // writeback from memory
        alu_op_sel   = 2'b00;  // ALU does addition (addr calc)
      end

      // Store (0100011): write to memory
      7'b0100011:
      begin
        alu_op2_sel  = 1'b1;   // address = rs1 + imm
        dmem_wr_en   = 1'b1;
        alu_op_sel   = 2'b00;  // ALU does addition (addr calc)
      end

      // Branch (1100011): conditional branch
      7'b1100011:
      begin
        pc_branch_en = 1'b1;
        alu_op_sel   = 2'b01;  // ALU does subtraction (compare rs1, rs2)
      end

      // JAL (1101111): jump and link
      7'b1101111:
      begin
        rf_wr_en     = 1'b1;
        pc_jump_en   = 1'b1;
      end

      // JALR (1100111): jump and link register (indirect)
      7'b1100111:
      begin
        rf_wr_en     = 1'b1;
        alu_op2_sel  = 1'b1;   // compute jump target = rs1 + imm
        pc_jalr_en   = 1'b1;
        alu_op_sel   = 2'b00;  // ALU does addition
      end

      // LUI (0110111): load upper immediate
      7'b0110111:
      begin
        rf_wr_en     = 1'b1;
      end

      // AUIPC (0010111): add upper immediate to PC
      7'b0010111:
      begin
        rf_wr_en     = 1'b1;
        alu_op2_sel  = 1'b1;
        alu_op_sel   = 2'b00;  // ALU does addition
      end

      default:
      begin
        // Invalid opcode — all control signals stay at safe default (0)
      end
    endcase
  end

  //==============================================================================
  // Stage 2: ALU Decoder (Combinational LUT)
  // {alu_op_sel[1:0], funct3[2:0], funct7_5} → alu_op[3:0]
  //==============================================================================
  always @(*)
  begin
    case (alu_op_sel)
      // ALUOp=00: addition (Load/Store/JALR/AUIPC address calc)
      2'b00:
      begin
        alu_op = 4'b0000;  // ADD
      end

      // ALUOp=01: subtraction (Branch compare)
      2'b01:
      begin
        alu_op = 4'b0001;  // SUB
      end

      // ALUOp=10: R-type — combined funct3+funct7_5 decode
      2'b10:
      begin
        case ({funct7_5, funct3})
          {1'b0, 3'b000}: alu_op = 4'b0000;  // ADD
          {1'b1, 3'b000}: alu_op = 4'b0001;  // SUB
          {1'b0, 3'b001}: alu_op = 4'b0101;  // SLL
          {1'b0, 3'b010}: alu_op = 4'b1000;  // SLT
          {1'b0, 3'b011}: alu_op = 4'b1001;  // SLTU
          {1'b0, 3'b100}: alu_op = 4'b0100;  // XOR
          {1'b0, 3'b101}: alu_op = 4'b0110;  // SRL
          {1'b1, 3'b101}: alu_op = 4'b0111;  // SRA
          {1'b0, 3'b110}: alu_op = 4'b0011;  // OR
          {1'b0, 3'b111}: alu_op = 4'b0010;  // AND
          default:        alu_op = 4'b0000;  // safe default
        endcase
      end

      // ALUOp=11: I-type ALU — funct3 decode (funct7_5 only for shifts)
      2'b11:
      begin
        case ({funct7_5, funct3})
          {1'b0, 3'b000}: alu_op = 4'b0000;  // ADDI
          {1'b0, 3'b010}: alu_op = 4'b1000;  // SLTI
          {1'b0, 3'b011}: alu_op = 4'b1001;  // SLTIU
          {1'b0, 3'b100}: alu_op = 4'b0100;  // XORI
          {1'b0, 3'b110}: alu_op = 4'b0011;  // ORI
          {1'b0, 3'b111}: alu_op = 4'b0010;  // ANDI
          {1'b0, 3'b001}: alu_op = 4'b0101;  // SLLI
          {1'b0, 3'b101}: alu_op = 4'b0110;  // SRLI
          {1'b1, 3'b101}: alu_op = 4'b0111;  // SRAI
          default:        alu_op = 4'b0000;  // safe default
        endcase
      end

      default:
      begin
        alu_op = 4'b0000;  // safe default
      end
    endcase
  end

endmodule
