//=============================================================================
// Processing Element (PE) — The fundamental compute unit of the NPU
// Performs: multiply-accumulate (MAC) = a * b + acc
// Supports INT8 multiplication with INT32 accumulation
//=============================================================================

module pe #(
    parameter DATA_WIDTH    = 8,    // Input data width (INT8)
    parameter ACCUM_WIDTH   = 32    // Accumulator width (INT32)
) (
    input  wire                     clk,
    input  wire                     rst_n,

    // Data inputs
    input  wire [DATA_WIDTH-1:0]    act_in,     // Activation input
    input  wire [DATA_WIDTH-1:0]    wgt_in,     // Weight input
    input  wire [ACCUM_WIDTH-1:0]   acc_in,     // Accumulator input (from previous PE or zero)

    // Control signals
    input  wire                     enable,     // PE enable
    input  wire                     acc_clear,  // Clear accumulator (start of new computation)
    input  wire                     bypass,     // Bypass mode: pass act_in to act_out, skip MAC

    // Data outputs
    output wire [DATA_WIDTH-1:0]    act_out,    // Activation passthrough (systolic shift)
    output wire [ACCUM_WIDTH-1:0]   acc_out     // Accumulator output
);

    //-------------------------------------------------------------------------
    // Internal registers
    //-------------------------------------------------------------------------
    reg [ACCUM_WIDTH-1:0]   accumulator;
    reg [DATA_WIDTH-1:0]    act_pipe;       // Pipeline register for activation passthrough

    //-------------------------------------------------------------------------
    // Multiply-accumulate logic
    //-------------------------------------------------------------------------
    wire [ACCUM_WIDTH-1:0]  product;
    wire [ACCUM_WIDTH-1:0]  sum;

    assign product = {{(ACCUM_WIDTH - 2*DATA_WIDTH){act_in[DATA_WIDTH-1]}},
                      act_in * wgt_in};    // Sign-extended multiply
    assign sum     = product + accumulator;

    //-------------------------------------------------------------------------
    // Accumulator register
    //-------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            accumulator <= '0;
        end else if (acc_clear) begin
            accumulator <= '0;
        end else if (enable) begin
            accumulator <= sum;
        end
    end

    //-------------------------------------------------------------------------
    // Activation passthrough (systolic shift register)
    //-------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            act_pipe <= '0;
        end else if (enable) begin
            act_pipe <= bypass ? act_in : act_in;
        end
    end

    assign act_out = act_pipe;
    assign acc_out = accumulator;

endmodule
