//=============================================================================
// NPU Top-Level Controller — Main FSM sequencing the full inference pipeline
// Orchestrates: DMA → Scratchpad → MAC Array → Activation → Pooling → Quantize
//
// FSM States:
//   IDLE → LOAD_WGT → LOAD_ACT → COMPUTE → ACTIVATE → POOL → QUANTIZE →
//   STORE → IDLE (for next layer)
//
// Control signals generated for each pipeline stage
//=============================================================================

module controller (
    input  wire                         clk,
    input  wire                         rst_n,

    //-------------------------------------------------------------------------
    // Host interface (from bus_interface)
    //-------------------------------------------------------------------------
    input  wire                         start,          // Start inference
    input  wire                         soft_rst,       // Software reset
    output wire                         busy,
    output wire                         done,
    output wire                         error,

    //-------------------------------------------------------------------------
    // DMA control
    //-------------------------------------------------------------------------
    output wire                         dma_start,
    output wire [1:0]                   dma_dir,
    input  wire                         dma_done,
    input  wire                         dma_busy,

    //-------------------------------------------------------------------------
    // Scratchpad access control
    //-------------------------------------------------------------------------
    output wire                         sp_a_en,        // Port A enable (DMA side)
    output wire                         sp_a_we,
    output wire                         sp_b_en,        // Port B enable (compute side)
    output wire                         sp_b_we,

    //-------------------------------------------------------------------------
    // MAC Array control
    //-------------------------------------------------------------------------
    output wire                         mac_compute_start,
    output wire                         mac_acc_clear,
    output wire                         mac_wgt_load,
    input  wire                         mac_busy,
    input  wire                         mac_done,
    input  wire                         mac_result_valid,

    //-------------------------------------------------------------------------
    // Activation control
    //-------------------------------------------------------------------------
    output wire [1:0]                   act_func_sel,
    output wire                         act_enable,
    input  wire                         act_valid_out,

    //-------------------------------------------------------------------------
    // Pooling control
    //-------------------------------------------------------------------------
    output wire                         pool_start,
    output wire                         pool_mode,
    input  wire                         pool_done,
    input  wire                         pool_valid_out,

    //-------------------------------------------------------------------------
    // Quantization control
    //-------------------------------------------------------------------------
    output wire                         quant_enable,
    input  wire                         quant_valid_out,
    input  wire                         quant_overflow,
    input  wire                         quant_underflow,

    //-------------------------------------------------------------------------
    // AGU control
    //-------------------------------------------------------------------------
    output wire                         agu_start,
    output wire                         agu_advance,
    input  wire                         agu_done,
    input  wire                         agu_busy,

    //-------------------------------------------------------------------------
    // Pipeline stage tracking
    //-------------------------------------------------------------------------
    output wire [3:0]                   current_state,
    output wire [15:0]                  cycle_count
);

    //-------------------------------------------------------------------------
    // FSM State Encoding
    //-------------------------------------------------------------------------
    typedef enum logic [3:0] {
        ST_IDLE         = 4'b0000,
        ST_LOAD_WGT     = 4'b0001,   // DMA: DRAM → Scratchpad (weights)
        ST_LOAD_ACT     = 4'b0010,   // DMA: DRAM → Scratchpad (activations)
        ST_LOAD_BIAS    = 4'b0011,   // DMA: DRAM → Scratchpad (bias)
        ST_COMPUTE      = 4'b0100,   // MAC Array computation
        ST_ACTIVATE     = 4'b0101,   // Activation function
        ST_POOL         = 4'b0110,   // Pooling
        ST_QUANTIZE     = 4'b0111,   // Quantization + rounding
        ST_STORE        = 4'b1000,   // DMA: Scratchpad → DRAM (results)
        ST_DONE         = 4'b1001,   // Layer complete
        ST_ERROR        = 4'b1010    // Error state
    } state_t;

    state_t state, next_state;

    // Cycle counter for performance monitoring
    reg [15:0] cycle_cnt;

    //-------------------------------------------------------------------------
    // State Register
    //-------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
        end else if (soft_rst) begin
            state <= ST_IDLE;
        end else begin
            state <= next_state;
        end
    end

    //-------------------------------------------------------------------------
    // Next State Logic
    //-------------------------------------------------------------------------
    always_comb begin
        next_state = state;
        case (state)
            ST_IDLE:
                if (start)          next_state = ST_LOAD_WGT;

            ST_LOAD_WGT:
                if (dma_done)       next_state = ST_LOAD_ACT;

            ST_LOAD_ACT:
                if (dma_done)       next_state = ST_LOAD_BIAS;

            ST_LOAD_BIAS:
                if (dma_done)       next_state = ST_COMPUTE;

            ST_COMPUTE:
                if (mac_done)       next_state = ST_ACTIVATE;

            ST_ACTIVATE:
                if (act_valid_out)  next_state = ST_POOL;

            ST_POOL:
                if (pool_done)      next_state = ST_QUANTIZE;

            ST_QUANTIZE:
                if (quant_valid_out) begin
                    if (quant_overflow || quant_underflow)
                        next_state = ST_ERROR;
                    else
                        next_state = ST_STORE;
                end

            ST_STORE:
                if (dma_done)       next_state = ST_DONE;

            ST_DONE:
                if (!start)         next_state = ST_IDLE;
                // else stay in DONE until host clears start

            ST_ERROR:
                if (soft_rst)       next_state = ST_IDLE;
                // Stay in error until software reset

            default:
                next_state = ST_IDLE;
        endcase
    end

    //-------------------------------------------------------------------------
    // Cycle Counter
    //-------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_cnt <= '0;
        end else if (state == ST_IDLE) begin
            cycle_cnt <= '0;
        end else begin
            cycle_cnt <= cycle_cnt + 1;
        end
    end

    //-------------------------------------------------------------------------
    // Control Signal Generation (Moore-style: outputs depend only on state)
    //-------------------------------------------------------------------------

    // DMA control
    assign dma_start = (state == ST_LOAD_WGT) || (state == ST_LOAD_ACT) ||
                       (state == ST_LOAD_BIAS) || (state == ST_STORE);
    assign dma_dir   = (state == ST_STORE) ? 2'b01 : 2'b00;  // 01=SRAM→DRAM, 00=DRAM→SRAM

    // Scratchpad control
    assign sp_a_en = (state == ST_LOAD_WGT) || (state == ST_LOAD_ACT) ||
                     (state == ST_LOAD_BIAS) || (state == ST_STORE);
    assign sp_a_we = (state == ST_STORE) ? 1'b0 : 1'b1;  // Write during load, read during store
    assign sp_b_en = (state == ST_COMPUTE);
    assign sp_b_we = 1'b0;  // Read-only from compute side

    // MAC Array control
    assign mac_compute_start = (state == ST_COMPUTE);
    assign mac_acc_clear     = (state == ST_IDLE);
    assign mac_wgt_load      = (state == ST_LOAD_WGT);

    // Activation control
    assign act_func_sel = 2'b00;  // Default: ReLU
    assign act_enable   = (state == ST_ACTIVATE);

    // Pooling control
    assign pool_start = (state == ST_ACTIVATE) && act_valid_out;
    assign pool_mode  = 1'b0;  // Default: Max pooling

    // Quantization control
    assign quant_enable = (state == ST_QUANTIZE);

    // AGU control
    assign agu_start   = (state == ST_COMPUTE);
    assign agu_advance = (state == ST_COMPUTE) && !mac_busy;

    //-------------------------------------------------------------------------
    // Status outputs
    //-------------------------------------------------------------------------
    assign busy   = (state != ST_IDLE) && (state != ST_DONE) && (state != ST_ERROR);
    assign done   = (state == ST_DONE);
    assign error  = (state == ST_ERROR);

    assign current_state = state;
    assign cycle_count   = cycle_cnt;

endmodule
