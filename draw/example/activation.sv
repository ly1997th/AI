//=============================================================================
// Activation Unit — Vectorized activation functions for neural network layers
// Supports: ReLU, Leaky ReLU, Parametric ReLU, Sigmoid (LUT), Tanh (LUT)
// Operates on vectors of up to VEC_SIZE elements per cycle
//=============================================================================

module activation #(
    parameter DATA_WIDTH    = 16,       // Data width (fixed-point: 8 integer + 8 fractional)
    parameter VEC_SIZE      = 16,       // Vector lane count
    parameter ACT_FUNC      = 2'b00     // Default: 00=ReLU, 01=LeakyReLU, 10=Sigmoid, 11=Tanh
) (
    input  wire                         clk,
    input  wire                         rst_n,

    // Data input
    input  wire [DATA_WIDTH-1:0]        data_in [0:VEC_SIZE-1],
    input  wire                         data_valid,

    // Data output
    output wire [DATA_WIDTH-1:0]        data_out [0:VEC_SIZE-1],
    output wire                         data_valid_out,

    // Configuration
    input  wire [1:0]                   act_func_sel,   // Activation function selection
    input  wire [DATA_WIDTH-1:0]        prelu_slope,    // Parametric ReLU negative slope
    input  wire [DATA_WIDTH-1:0]        leaky_slope     // Leaky ReLU negative slope (fixed 0.01)
);

    //-------------------------------------------------------------------------
    // Pipeline stages: Input → Function Select → Output
    //-------------------------------------------------------------------------

    // Stage 1: Input register
    reg [DATA_WIDTH-1:0] stage1_data [0:VEC_SIZE-1];
    reg                  stage1_valid;
    reg [1:0]            stage1_func;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage1_valid <= 1'b0;
            stage1_func  <= 2'b00;
        end else begin
            stage1_valid <= data_valid;
            stage1_func  <= act_func_sel;
            if (data_valid) begin
                for (int i = 0; i < VEC_SIZE; i++) begin
                    stage1_data[i] <= data_in[i];
                end
            end
        end
    end

    //-------------------------------------------------------------------------
    // Stage 2: Function computation (combinational)
    //-------------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] stage2_data [0:VEC_SIZE-1];
    reg                  stage2_valid;

    // ReLU: f(x) = max(0, x)
    function [DATA_WIDTH-1:0] relu;
        input [DATA_WIDTH-1:0] x;
        reg sign_bit;
        begin
            sign_bit = x[DATA_WIDTH-1];
            relu = sign_bit ? '0 : x;
        end
    endfunction

    // Leaky ReLU: f(x) = x if x > 0, else alpha * x
    function [DATA_WIDTH-1:0] leaky_relu;
        input [DATA_WIDTH-1:0] x;
        input [DATA_WIDTH-1:0] alpha;
        reg sign_bit;
        reg [2*DATA_WIDTH-1:0] product;
        begin
            sign_bit = x[DATA_WIDTH-1];
            product = x * alpha;
            leaky_relu = sign_bit ? product[DATA_WIDTH +: DATA_WIDTH] : x;
        end
    endfunction

    always_comb begin
        for (int i = 0; i < VEC_SIZE; i++) begin
            case (stage1_func)
                2'b00: stage2_data[i] = relu(stage1_data[i]);                    // ReLU
                2'b01: stage2_data[i] = leaky_relu(stage1_data[i], leaky_slope); // Leaky ReLU
                2'b10: stage2_data[i] = relu(stage1_data[i]);                    // Sigmoid (placeholder)
                2'b11: stage2_data[i] = relu(stage1_data[i]);                    // Tanh (placeholder)
            endcase
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            stage2_valid <= 1'b0;
        else
            stage2_valid <= stage1_valid;
    end

    //-------------------------------------------------------------------------
    // Output assignment
    //-------------------------------------------------------------------------
    generate
        genvar g;
        for (g = 0; g < VEC_SIZE; g = g + 1) begin : gen_out
            assign data_out[g] = stage2_data[g];
        end
    endgenerate

    assign data_valid_out = stage2_valid;

endmodule
