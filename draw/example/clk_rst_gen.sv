//=============================================================================
// Clock and Reset Generation Module
// Manages clock domains, clock gating, and reset distribution for the NPU
//
// Clock domains:
//   - clk_sys  (200 MHz) — System/bus clock from external oscillator
//   - clk_core (400 MHz) — Core compute clock (PLL multiplied)
//   - clk_mem  (100 MHz) — Memory interface clock (PLL divided)
//
// Reset scheme:
//   - ext_rst_n (active low, async) — External reset from board
//   - sys_rst_n — Synchronized to clk_sys
//   - core_rst_n — Synchronized to clk_core, deasserted after sys_rst_n
//   - mem_rst_n — Synchronized to clk_mem
//=============================================================================

module clk_rst_gen (
    // External clock and reset inputs
    input  wire                         ext_clk,        // External oscillator (200 MHz)
    input  wire                         ext_rst_n,      // External reset (active low)

    // PLL control (simplified model — in real design, use FPGA PLL IP)
    input  wire                         pll_locked,     // PLL lock indicator

    // Generated clocks
    output wire                         clk_sys,        // 200 MHz system clock
    output wire                         clk_core,       // 400 MHz core clock
    output wire                         clk_mem,        // 100 MHz memory clock

    // Generated resets (synchronized to respective domains)
    output wire                         sys_rst_n,      // clk_sys domain
    output wire                         core_rst_n,     // clk_core domain
    output wire                         mem_rst_n,      // clk_mem domain

    // Clock gating controls
    input  wire                         core_clk_en,    // Enable core clock
    input  wire                         mem_clk_en,     // Enable memory clock

    // Gated clocks (for power management)
    output wire                         gated_core_clk, // Gated core clock
    output wire                         gated_mem_clk,  // Gated memory clock

    // Reset status
    output wire                         rst_active,     // Any reset active
    output wire                         pll_stable      // PLL locked and stable
);

    //-------------------------------------------------------------------------
    // Clock distribution (simplified FPGA model)
    //-------------------------------------------------------------------------

    // BUFG: Global clock buffers
    wire clk_sys_bufg, clk_core_bufg, clk_mem_bufg;

    // System clock: direct from external oscillator
    assign clk_sys_bufg = ext_clk;
    assign clk_sys      = clk_sys_bufg;

    // Core clock: PLL output (2x multiply)
    // In real design: instantiate MMCM/PLL IP core
    // clk_core_bufg = PLL_CLKOUT0 (feedback divided)
    // For this model: externally generated
    assign clk_core_bufg = 1'b0;  // Placeholder — connect to PLL output in implementation
    assign clk_core      = clk_core_bufg;

    // Memory clock: from PLL (1x, phase-shifted for timing closure)
    assign clk_mem_bufg = 1'b0;   // Placeholder — connect to PLL output in implementation
    assign clk_mem      = clk_mem_bufg;

    //-------------------------------------------------------------------------
    // Clock gating (for power reduction when idle)
    // Uses BUFGCE (clock buffer with clock enable) on FPGA
    //-------------------------------------------------------------------------

    // Core clock gate
    reg core_clk_en_sync;
    always_ff @(negedge clk_core_bufg or negedge core_rst_n) begin
        if (!core_rst_n)
            core_clk_en_sync <= 1'b0;
        else
            core_clk_en_sync <= core_clk_en;
    end

    // In real FPGA: BUFGCE instantiation
    // BUFGCE u_core_clk_gate (.I(clk_core_bufg), .CE(core_clk_en_sync), .O(gated_core_clk));
    assign gated_core_clk = clk_core_bufg && core_clk_en_sync;

    // Memory clock gate
    reg mem_clk_en_sync;
    always_ff @(negedge clk_mem_bufg or negedge mem_rst_n) begin
        if (!mem_rst_n)
            mem_clk_en_sync <= 1'b0;
        else
            mem_clk_en_sync <= mem_clk_en;
    end
    assign gated_mem_clk = clk_mem_bufg && mem_clk_en_sync;

    //-------------------------------------------------------------------------
    // Reset Synchronizers — 2-stage flip-flop chains
    // Standard async-assert, sync-deassert pattern
    //-------------------------------------------------------------------------

    // --- System domain reset (clk_sys) ---
    reg [1:0] sys_rst_sync;

    always_ff @(posedge clk_sys or negedge ext_rst_n) begin
        if (!ext_rst_n) begin
            sys_rst_sync <= 2'b00;
        end else begin
            sys_rst_sync <= {sys_rst_sync[0], 1'b1};
        end
    end
    assign sys_rst_n = sys_rst_sync[1];

    // --- Core domain reset (clk_core) ---
    reg [1:0] core_rst_sync;

    always_ff @(posedge clk_core or negedge ext_rst_n) begin
        if (!ext_rst_n) begin
            core_rst_sync <= 2'b00;
        end else begin
            core_rst_sync <= {core_rst_sync[0], 1'b1};
        end
    end
    assign core_rst_n = core_rst_sync[1];

    // --- Memory domain reset (clk_mem) ---
    reg [1:0] mem_rst_sync;

    always_ff @(posedge clk_mem or negedge ext_rst_n) begin
        if (!ext_rst_n) begin
            mem_rst_sync <= 2'b00;
        end else begin
            mem_rst_sync <= {mem_rst_sync[0], 1'b1};
        end
    end
    assign mem_rst_n = mem_rst_sync[1];

    //-------------------------------------------------------------------------
    // Reset sequencing: core reset deasserts after system reset
    // Ensures bus interface is ready before core starts
    //-------------------------------------------------------------------------
    reg [7:0] core_rst_delay_cnt;
    reg       core_rst_delayed;
    wire      core_rst_n_final;

    always_ff @(posedge clk_core or negedge core_rst_n) begin
        if (!core_rst_n) begin
            core_rst_delay_cnt <= '0;
            core_rst_delayed   <= 1'b0;
        end else if (sys_rst_n && !core_rst_delayed) begin
            // Deassert core reset 16 cycles after system reset deasserts
            if (core_rst_delay_cnt == 8'd15) begin
                core_rst_delayed <= 1'b1;
            end else begin
                core_rst_delay_cnt <= core_rst_delay_cnt + 1;
            end
        end
    end

    assign core_rst_n_final = core_rst_n && core_rst_delayed;

    //-------------------------------------------------------------------------
    // CDC (Clock Domain Crossing) signals
    // Simple 2-FF synchronizer for control signals crossing domains
    //-------------------------------------------------------------------------

    // Example: done signal from core domain to sys domain
    reg [1:0] done_cdc_sync;  // Placeholder for actual CDC signals

    always_ff @(posedge clk_sys or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            done_cdc_sync <= 2'b00;
        end else begin
            done_cdc_sync <= {done_cdc_sync[0], 1'b0};  // Connect to actual done signal
        end
    end

    //-------------------------------------------------------------------------
    // Status outputs
    //-------------------------------------------------------------------------
    assign rst_active = !sys_rst_n || !core_rst_n_final || !mem_rst_n;
    assign pll_stable = pll_locked && sys_rst_n;

endmodule
