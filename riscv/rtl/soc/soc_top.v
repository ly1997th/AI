//==============================================================================
// soc_top.v — SoC Top Level Integration
//==============================================================================
//
// 【Circuit Architecture】
//   Function: Integrate processor core + unified memory into a minimal system.
//
//   Top-Level Topology (2 macros, pure wiring):
//     ┌───────────┐        ┌───────────┐
//     │           │ imem_rd_addr  │           │
//     │           │─────────────→│           │
//     │   core    │←─────────────│  memory   │
//     │           │ imem_rd_dat  │           │
//     │           │              │           │
//     │           │ dmem_addr    │           │
//     │           │─────────────→│           │
//     │           │ dmem_wr_dat  │           │
//     │           │─────────────→│           │
//     │           │←─────────────│           │
//     │           │ dmem_rd_dat  │           │
//     │           │ dmem_wr_en   │           │
//     │           │─────────────→│           │
//     │           │ dmem_rd_en   │           │
//     │           │─────────────→│           │
//     └───────────┘              └───────────┘
//
//   Four-Dimensional Paths (top-level view):
//     Data path: core↔memory — 32-bit instruction + 32-bit data
//     Address path: imem_rd_addr→memory, dmem_addr→memory
//     Parameter path: none at top level
//     Control path: dmem_wr_en/dmem_rd_en → memory
//
//   Design Decisions:
//     Single-cycle processor — instruction and data access never conflict
//     Unified memory simplifies interface but I/D sharing is physical bottleneck
//     Extension: separate I-MEM + D-MEM for pipeline support
//
// 【Macro Mapping & PPA】
//   Macros:
//     1× core instance (complete processor datapath + control)
//     1× memory instance (unified I/D memory)
//
//   Interconnect (top-level wiring only, zero logic):
//     All signals are point-to-point direct connections (fanout=1)
//
//   PPA (precision: low — logic analysis):
//     This module contains only macro instantiation + direct wiring, zero logic
//     Total area = core area + memory area (see individual module PPA)
//     Zero timing cost from top-level wiring
//     Zero power contribution
//
// 【RTL Code】
//==============================================================================

module soc_top
(
  input  wire clk,
  input  wire rst_n
);

  //------------------------------------------------------------------------------
  // Internal Interconnect Signals (pure wiring, zero logic gates)
  //------------------------------------------------------------------------------
  // Instruction bus
  wire [31:0] imem_rd_dat;
  wire [31:0] imem_rd_addr;

  // Data bus
  wire [31:0] dmem_addr;
  wire [31:0] dmem_wr_dat;
  wire [31:0] dmem_rd_dat;
  wire        dmem_wr_en;
  wire        dmem_rd_en;

  //------------------------------------------------------------------------------
  // core instantiation: complete single-cycle RISC-V RV32I processor
  //------------------------------------------------------------------------------
  core u_core
  (
    .clk           (clk),
    .rst_n         (rst_n),
    .imem_rd_dat   (imem_rd_dat),
    .imem_rd_addr  (imem_rd_addr),
    .dmem_addr     (dmem_addr),
    .dmem_wr_dat   (dmem_wr_dat),
    .dmem_rd_dat   (dmem_rd_dat),
    .dmem_wr_en    (dmem_wr_en),
    .dmem_rd_en    (dmem_rd_en)
  );

  //------------------------------------------------------------------------------
  // memory instantiation: unified I/D memory (Von Neumann architecture)
  //------------------------------------------------------------------------------
  memory
  #(
    .MEM_DEPTH (1024),
    .MEM_WIDTH (4)
  )
  u_memory
  (
    .clk          (clk),
    .imem_rd_addr (imem_rd_addr),
    .imem_rd_dat  (imem_rd_dat),
    .dmem_addr    (dmem_addr),
    .dmem_wr_dat  (dmem_wr_dat),
    .dmem_rd_dat  (dmem_rd_dat),
    .dmem_wr_en   (dmem_wr_en),
    .dmem_rd_en   (dmem_rd_en)
  );

endmodule
