//==============================================================================
// core.v — Processor Core Datapath (Single-Cycle RV32I)
//==============================================================================
//
// 【Circuit Architecture】
//   Function: Integrate all core modules into a complete single-cycle RV32I datapath.
//
//   Top-Level Topology:
//     ┌──────┐      ┌──────────┐
//     │  PC  │─────→│ I-Memory │
//     │(DFF) │←──┐  │(Ext SRAM)│
//     └──────┘   │  └────┬─────┘
//         ↑      │       │ imem_rd_dat
//         │      │       ↓
//      ┌──┴──────┐│  ┌─────────┐  ┌───────────────┐
//      │pc_nxt   │←┘  │Control  │  │ Register File │
//      │ MUX     │    │ Unit    │  │ (DFF Array)   │
//      │(4-to-1) │    │(Decoder)│  │ 2R1W          │
//      └─────────┘    └────┬────┘  └──┬──────┬─────┘
//          ↑               │          │rd_dat0│rd_dat1
//    pc_branch_taken   control    ┌──────────────┐
//    pc_jump_en     ─────────────→│ ALU src MUX  │
//    pc_jalr_en                   │  (2-to-1)    │
//                                 └──┬──────┬────┘
//                                    │alu_opa│alu_opb
//                                    ↓       ↓
//                               ┌──────────────┐
//                               │     ALU      │
//                               │ (Adder+Shift │
//                               │  +MUX tree)  │
//                               └──────┬───────┘
//                                      │ alu_dat
//                                      ↓
//                               ┌──────────────┐
//                               │  D-Memory    │
//                               │  (Ext SRAM)  │
//                               └──────┬───────┘
//                                      │
//                               ┌──────┴───────┐
//                               │ rf_wr_sel    │
//                               │   MUX        │
//                               │  (2-to-1)    │
//                               └──────┬───────┘
//                                      │ rf_wr_dat
//                                      └──→ regfile.wr_dat
//
//   Four-Dimensional Path Separation:
//
//   【Data Path】(32-bit wide, core computation flow):
//     PC→I-MEM→imem_rd_dat→regfile→ALU→D-MEM→rf_wr_sel MUX→rf_wr_dat
//     Critical path: imem_rd_dat→regfile read→ALU→D-MEM→MUX→regfile setup
//
//   【Address Path】(5~32-bit, addressing signals):
//     Instruction address: PC → I-MEM.addr
//     Data address: alu_dat → D-MEM.addr
//     Register address: instr[19:15]→rd_addr0, instr[24:20]→rd_addr1,
//                        instr[11:7]→wr_addr
//
//   【Parameter Path】(32-bit, immediate/constant, minimal toggle):
//     Immediate: instr → imm_gen → imm_dat → alu_opb (I/S/B/U/J-type)
//     Branch offset: imm_dat → PC adder (branch/jump target calc)
//
//   【Control Path】(small width, complex logic, point-to-point fanout):
//     opcode → control_unit → {rf_wr_en, alu_op2_sel, dmem_wr_en,
//       dmem_rd_en, rf_wr_sel, pc_branch_en, pc_jump_en,
//       pc_jalr_en, alu_op_sel, alu_op}
//
// 【Macro Mapping & PPA】
//   Macros (this module — interconnect only, no new physical units):
//     1× 4-to-1 32-bit MUX (pc_nxt selection)
//     1× 2-to-1 32-bit MUX (ALU op2 selection)
//     1× 2-to-1 32-bit MUX (rf_wr_dat selection for rf_wr_sel)
//     1× 32-bit Adder (PC+4)
//     Branch decision logic (Comparator + funct3 decode)
//
//   Key Interconnect Nodes (fanout/reconvergence awareness):
//     imem_rd_dat → control_unit + imm_gen + regfile(addr)
//       (fanout=3, width=32, moderate — usually no buffer needed)
//     pc → I-MEM + Adder(PC+4) (fanout=2, width=32)
//     alu_dat → D-MEM + pc_nxt MUX + rf_wr_sel MUX
//       (fanout=3, width=32, critical path branch point)
//
//   PPA (precision: low — logic analysis):
//     Area: ~3× 32-bit MUX + 1 Adder ≈ 400 gate equiv
//     Timing (single-cycle critical path):
//       PC→I-MEM→decode→RegFile read→ALU→D-MEM→MUX→RegFile write
//       Sum of segment delays determines max clock frequency
//     Power: clock toggling dominates (PC.DFF + RegFile.DFF array)
//
// 【RTL Code】
//==============================================================================

module core
(
  input  wire        clk,
  input  wire        rst_n,

  // Instruction memory interface (Harvard — instruction side)
  input  wire [31:0] imem_rd_dat,
  output wire [31:0] imem_rd_addr,

  // Data memory interface (Harvard — data side)
  output wire [31:0] dmem_addr,
  output wire [31:0] dmem_wr_dat,
  input  wire [31:0] dmem_rd_dat,
  output wire        dmem_wr_en,
  output wire        dmem_rd_en
);

  //------------------------------------------------------------------------------
  // Internal Signal Declarations
  //------------------------------------------------------------------------------
  // PC related
  wire [31:0] pc;
  wire [31:0] pc_inc4;
  reg  [31:0] pc_nxt;             // reg: driven by always block (4-to-1 MUX)
  wire [31:0] pc_branch_tgt;
  wire [31:0] pc_jal_tgt;
  wire [31:0] pc_jalr_tgt;
  wire        pc_branch_taken;

  // Instruction fields (extracted in parallel — spatial slicing)
  wire [6:0]  opcode   = imem_rd_dat[6:0];
  wire [4:0]  rs1_addr = imem_rd_dat[19:15];
  wire [4:0]  rs2_addr = imem_rd_dat[24:20];
  wire [4:0]  rd_addr  = imem_rd_dat[11:7];
  wire [2:0]  funct3   = imem_rd_dat[14:12];
  wire        funct7_5 = imem_rd_dat[30];  // funct7[5]: ADD/SUB, SRL/SRA differentiate

  // Register file
  wire [31:0] rd_dat0;
  wire [31:0] rd_dat1;
  wire [31:0] rf_wr_dat;

  // Control signals
  wire        rf_wr_en;
  wire        alu_op2_sel;
  wire        dmem_wr_en_int;
  wire        dmem_rd_en_int;
  wire        rf_wr_sel;
  wire        pc_branch_en;
  wire        pc_jump_en;
  wire        pc_jalr_en;
  wire [1:0]  alu_op_sel;
  wire [3:0]  alu_op;

  // ALU datapath
  wire [31:0] alu_opa;
  wire [31:0] alu_opb;
  wire [31:0] alu_dat;
  wire        alu_zero_flag;

  // Immediate
  wire [31:0] imm_dat;

  //------------------------------------------------------------------------------
  // Sub-module Instantiation
  //------------------------------------------------------------------------------

  // PC: 32× DFF (async reset)
  pc u_pc
  (
    .clk    (clk),
    .rst_n  (rst_n),
    .pc_nxt (pc_nxt),
    .pc     (pc)
  );

  // Register File: 2R1W, DFF array
  regfile u_regfile
  (
    .clk       (clk),
    .rst_n     (rst_n),
    .rd_addr0  (rs1_addr),
    .rd_dat0   (rd_dat0),
    .rd_addr1  (rs2_addr),
    .rd_dat1   (rd_dat1),
    .wr_addr   (rd_addr),
    .wr_en     (rf_wr_en),
    .wr_dat    (rf_wr_dat)
  );

  // ALU: pure combinational, 10-to-1 MUX tree
  alu u_alu
  (
    .opa       (alu_opa),
    .opb       (alu_opb),
    .op_sel    (alu_op),
    .dat       (alu_dat),
    .zero_flag (alu_zero_flag)
  );

  // Immediate Generator: 6× wire reorder + 6-to-1 MUX
  imm_gen u_imm_gen
  (
    .instr   (imem_rd_dat),
    .imm_dat (imm_dat)
  );

  // Control Unit: two-level decode (Main Decoder + ALU Decoder)
  control_unit u_control
  (
    .opcode       (opcode),
    .rf_wr_en     (rf_wr_en),
    .alu_op2_sel  (alu_op2_sel),
    .dmem_wr_en   (dmem_wr_en_int),
    .dmem_rd_en   (dmem_rd_en_int),
    .rf_wr_sel    (rf_wr_sel),
    .pc_branch_en (pc_branch_en),
    .pc_jump_en   (pc_jump_en),
    .pc_jalr_en   (pc_jalr_en),
    .alu_op_sel   (alu_op_sel),
    .funct3       (funct3),
    .funct7_5     (funct7_5),
    .alu_op       (alu_op)
  );

  //------------------------------------------------------------------------------
  // Data Path MUX Network (combinational)
  //------------------------------------------------------------------------------

  // 2-to-1 MUX: ALU second operand selection (control-path driven)
  //   alu_op2_sel=0 → rs2 (R-type, Branch)
  //   alu_op2_sel=1 → imm_dat (I-type, Load, Store, AUIPC, JALR)
  assign alu_opa = rd_dat0;
  assign alu_opb = (alu_op2_sel) ? imm_dat : rd_dat1;

  // 2-to-1 MUX: writeback data selection (rf_wr_sel)
  //   rf_wr_sel=0 → alu_dat (R-type, I-ALU, AUIPC, JAL/JALR)
  //   rf_wr_sel=1 → dmem_rd_dat (Load)
  assign rf_wr_dat = (rf_wr_sel) ? dmem_rd_dat : alu_dat;

  //------------------------------------------------------------------------------
  // Address Path: target address computation + PC update (4-to-1 MUX + Adder)
  //------------------------------------------------------------------------------

  // Adder: PC + 4 (sequential address)
  assign pc_inc4       = pc + 32'd4;

  // Parameter path: immediate → jump target addresses
  assign pc_branch_tgt = pc + imm_dat;         // B-type offset (±4KB range)
  assign pc_jal_tgt    = pc + imm_dat;         // J-type offset (±1MB range)
  assign pc_jalr_tgt   = (rd_dat0 + imm_dat) & ~32'h1;  // JALR: rs1+imm, LSB cleared

  // Control path: branch condition decision (Comparator + funct3 decode)
  // Spatial slicing: focus on pc_branch_taken output, iterate all funct3 cases
  assign pc_branch_taken = pc_branch_en && (
      ((funct3 == 3'b000) &&  alu_zero_flag)      ||   // BEQ
      ((funct3 == 3'b001) && !alu_zero_flag)      ||   // BNE
      ((funct3 == 3'b100) &&  alu_dat[0])         ||   // BLT  (signed, via ALU SLT)
      ((funct3 == 3'b101) && !alu_dat[0])         ||   // BGE  (signed)
      ((funct3 == 3'b110) && !alu_zero_flag)      ||   // BLTU (unsigned)
      ((funct3 == 3'b111) &&  alu_zero_flag)           // BGEU (unsigned)
  );

  // 4-to-1 MUX: pc_nxt selection (priority-encoded if-else chain)
  //   pc_jalr_en > pc_jump_en > pc_branch_taken > sequential
  always @(*)
  begin
    if (pc_jalr_en)
    begin
      pc_nxt = pc_jalr_tgt;
    end
    else if (pc_jump_en)
    begin
      pc_nxt = pc_jal_tgt;
    end
    else if (pc_branch_taken)
    begin
      pc_nxt = pc_branch_tgt;
    end
    else
    begin
      pc_nxt = pc_inc4;
    end
  end

  //------------------------------------------------------------------------------
  // Output Connections
  //------------------------------------------------------------------------------
  assign imem_rd_addr = pc;
  assign dmem_addr    = alu_dat;        // data memory address = ALU result
  assign dmem_wr_dat  = rd_dat1;        // store data = rs2
  assign dmem_wr_en   = dmem_wr_en_int;
  assign dmem_rd_en   = dmem_rd_en_int;

endmodule
