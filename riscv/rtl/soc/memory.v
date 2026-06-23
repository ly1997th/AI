//==============================================================================
// memory.v — Unified Memory (Von Neumann Architecture, Simulation Model)
//==============================================================================
//
// 【Circuit Architecture】
//   Function: Unified instruction/data memory for simulation.
//   Note: Simulation-only model. Real FPGA/ASIC would use separate I-MEM + D-MEM.
//
//   Data Path (32-bit):
//     Read side (combinational):
//       mem[imem_word_addr] → imem_rd_dat
//       mem[dmem_word_addr] → dmem_rd_dat (dmem_rd_en gated)
//     Write side (sequential):
//       dmem_wr_dat → mem[dmem_word_addr] (posedge clk + dmem_wr_en)
//
//   Address Path (byte addr → word addr, right shift by 2):
//     imem_rd_addr[31:0] → [>>2] → imem_word_addr (word-aligned)
//     dmem_addr[31:0]    → [>>2] → dmem_word_addr (word-aligned)
//
//   Control Path:
//     dmem_wr_en → write enable gating (DFF.D side)
//     dmem_rd_en → read enable gating (dmem_rd_dat output)
//
//   Path Separation:
//     Data path: 2 independent read channels (combinational) + 1 write channel (sequential)
//     Address path: 2 independent address inputs, zero conflict (single-cycle guarantee)
//     Single-cycle design guarantees I/D ports never conflict
//
// 【Macro Mapping & PPA】
//   Macros (simulation model, not synthesizable as-is):
//     1× reg [31:0] mem[0:MEM_DEPTH-1] (simulation memory array)
//       Physical analog: SRAM (real chip) or DFF array (FPGA)
//
//   PPA (simulation context, not for synthesis):
//     Area: not applicable in simulation
//     Timing: real SRAM read latency ≈ 1-3ns (process-dependent)
//     Power: SRAM read << write, instruction read is steady-state (almost every cycle)
//
// 【RTL Code】
//==============================================================================

module memory
#(
  parameter MEM_DEPTH = 1024,
  parameter MEM_WIDTH = 4
)
(
  input  wire        clk,

  // Instruction port (read-only, combinational)
  input  wire [31:0] imem_rd_addr,
  output wire [31:0] imem_rd_dat,

  // Data port (read/write)
  input  wire [31:0] dmem_addr,
  input  wire [31:0] dmem_wr_dat,
  output wire [31:0] dmem_rd_dat,
  input  wire        dmem_wr_en,
  input  wire        dmem_rd_en
);

  // Memory array (simulation reg array → synthesis maps to SRAM or DFF array)
  reg [31:0] mem [0:MEM_DEPTH-1];

  //------------------------------------------------------------------------------
  // Address Path: byte address → word address (right shift by 2)
  // Pure wiring, zero logic gates
  //------------------------------------------------------------------------------
  wire [$clog2(MEM_DEPTH)-1:0] imem_word_addr = imem_rd_addr[$clog2(MEM_DEPTH)+1:2];
  wire [$clog2(MEM_DEPTH)-1:0] dmem_word_addr = dmem_addr[$clog2(MEM_DEPTH)+1:2];

  //------------------------------------------------------------------------------
  // Read Path (combinational): I-port always reads, D-port gated by dmem_rd_en
  //------------------------------------------------------------------------------
  assign imem_rd_dat = mem[imem_word_addr];
  assign dmem_rd_dat = dmem_rd_en ? mem[dmem_word_addr] : 32'b0;

  //------------------------------------------------------------------------------
  // Write Path (sequential): dmem_wr_en gated, posedge clk write
  //------------------------------------------------------------------------------
  always @(posedge clk)
  begin
    if (dmem_wr_en)
    begin
      mem[dmem_word_addr] <= dmem_wr_dat;
    end
  end

  //------------------------------------------------------------------------------
  // Simulation helper: memory initialization
  // Uncomment to load test programs at simulation start
  //------------------------------------------------------------------------------
  `ifdef SIMULATION
  initial
  begin
    // $readmemh("path/to/program.hex", mem);
  end
  `endif

endmodule
