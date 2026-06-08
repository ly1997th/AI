//=============================================================================
// Systolic MAC Array — N×N grid of Processing Elements
// Weight-stationary dataflow: weights preloaded, activations flow through
// Supports matrix multiplication: C = A × B + C
//=============================================================================

module mac_array #(
    parameter ARRAY_SIZE   = 16,   // N×N systolic array
    parameter DATA_WIDTH   = 8,    // INT8 operands
    parameter ACCUM_WIDTH  = 32    // INT32 accumulation
) (
    input  wire                         clk,
    input  wire                         rst_n,

    // Activation inputs (broadcast to rows)
    input  wire [DATA_WIDTH-1:0]        act_in [0:ARRAY_SIZE-1],
    input  wire                         act_valid,

    // Weight inputs (preloaded column by column)
    input  wire [DATA_WIDTH-1:0]        wgt_in [0:ARRAY_SIZE-1],
    input  wire                         wgt_valid,
    input  wire                         wgt_load,       // Weight loading phase

    // Accumulator inputs (from previous layer or initial zeros)
    input  wire [ACCUM_WIDTH-1:0]       partial_in [0:ARRAY_SIZE-1],

    // Control
    input  wire                         compute_start,  // Begin MAC operations
    input  wire                         acc_clear,      // Clear accumulators

    // Results output (column outputs)
    output wire [ACCUM_WIDTH-1:0]       result_out [0:ARRAY_SIZE-1],
    output wire                         result_valid,

    // Status
    output wire                         busy,
    output wire                         done
);

    //-------------------------------------------------------------------------
    // Internal signals for systolic connections
    //-------------------------------------------------------------------------
    // Horizontal activation flow (between columns)
    wire [DATA_WIDTH-1:0]   act_h [0:ARRAY_SIZE-1][0:ARRAY_SIZE];  // [row][col+1]

    // Vertical weight flow (between rows) — not used in weight-stationary mode
    // Weights are held stationary at each PE after loading

    // PE accumulator outputs (sum flows vertically)
    wire [ACCUM_WIDTH-1:0]  acc_v [0:ARRAY_SIZE][0:ARRAY_SIZE-1]; // [row+1][col]

    // Weight storage in PEs
    reg  [DATA_WIDTH-1:0]   wgt_stored [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1];

    //-------------------------------------------------------------------------
    // Control state machine
    //-------------------------------------------------------------------------
    typedef enum logic [2:0] {
        ST_IDLE     = 3'b000,
        ST_LOAD_WGT = 3'b001,
        ST_COMPUTE  = 3'b010,
        ST_DRAIN    = 3'b011,
        ST_DONE     = 3'b100
    } state_t;

    state_t state, next_state;

    reg [7:0] cycle_counter;
    reg [7:0] compute_cycles;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= ST_IDLE;
        else
            state <= next_state;
    end

    always_comb begin
        next_state = state;
        case (state)
            ST_IDLE:    if (wgt_load)           next_state = ST_LOAD_WGT;
            ST_LOAD_WGT: if (cycle_counter == ARRAY_SIZE-1) next_state = ST_COMPUTE;
            ST_COMPUTE: if (compute_cycles == ARRAY_SIZE-1) next_state = ST_DRAIN;
            ST_DRAIN:   if (cycle_counter == ARRAY_SIZE-1) next_state = ST_DONE;
            ST_DONE:    if (!compute_start)     next_state = ST_IDLE;
        endcase
    end

    // Cycle counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_counter  <= '0;
            compute_cycles <= '0;
        end else begin
            case (state)
                ST_LOAD_WGT: cycle_counter  <= cycle_counter + 1;
                ST_COMPUTE:  compute_cycles <= compute_cycles + 1;
                ST_DRAIN:    cycle_counter  <= cycle_counter + 1;
                default: begin
                    cycle_counter  <= '0;
                    compute_cycles <= '0;
                end
            endcase
        end
    end

    //-------------------------------------------------------------------------
    // Activation input routing to first column
    //-------------------------------------------------------------------------
    genvar r;
    generate
        for (r = 0; r < ARRAY_SIZE; r = r + 1) begin : gen_act_input
            assign act_h[r][0] = act_in[r];
        end
    endgenerate

    //-------------------------------------------------------------------------
    // Accumulator input to first row (from external partial sums)
    //-------------------------------------------------------------------------
    genvar c;
    generate
        for (c = 0; c < ARRAY_SIZE; c = c + 1) begin : gen_acc_input
            assign acc_v[0][c] = partial_in[c];
        end
    endgenerate

    //-------------------------------------------------------------------------
    // PE Grid instantiation — ARRAY_SIZE × ARRAY_SIZE
    //-------------------------------------------------------------------------
    generate
        for (r = 0; r < ARRAY_SIZE; r = r + 1) begin : gen_row
            for (c = 0; c < ARRAY_SIZE; c = c + 1) begin : gen_col

                wire pe_enable = (state == ST_COMPUTE) || (state == ST_LOAD_WGT);
                wire pe_acc_clear = (state == ST_IDLE);

                pe #(
                    .DATA_WIDTH  (DATA_WIDTH),
                    .ACCUM_WIDTH (ACCUM_WIDTH)
                ) u_pe (
                    .clk        (clk),
                    .rst_n      (rst_n),
                    .act_in     (act_h[r][c]),
                    .wgt_in     (wgt_stored[r][c]),
                    .acc_in     (acc_v[r][c]),
                    .enable     (pe_enable),
                    .acc_clear  (pe_acc_clear),
                    .bypass     (1'b0),
                    .act_out    (act_h[r][c+1]),
                    .acc_out    (acc_v[r+1][c])
                );

                // Weight loading
                always_ff @(posedge clk) begin
                    if (state == ST_LOAD_WGT && wgt_valid)
                        wgt_stored[r][c] <= wgt_in[c];
                end

            end
        end
    endgenerate

    //-------------------------------------------------------------------------
    // Result outputs from last row of accumulators
    //-------------------------------------------------------------------------
    generate
        for (c = 0; c < ARRAY_SIZE; c = c + 1) begin : gen_result
            assign result_out[c] = acc_v[ARRAY_SIZE][c];
        end
    endgenerate

    assign result_valid = (state == ST_DRAIN);
    assign busy = (state != ST_IDLE) && (state != ST_DONE);
    assign done = (state == ST_DONE);

endmodule
