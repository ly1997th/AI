//=============================================================================
// Quantization Unit — Data width converter with rounding and saturation
// Converts between precision formats: INT32→INT16→INT8
// Supports: Per-tensor affine quantization: q = clip(round(x/scale) + zero_point)
// Hardware-friendly: uses shift for power-of-2 scales, multiplier for arbitrary
//=============================================================================

module quantization #(
    parameter IN_WIDTH      = 32,       // Input data width (accumulator output)
    parameter OUT_WIDTH     = 8,        // Output data width (quantized)
    parameter SCALE_WIDTH   = 16,       // Scale factor width
    parameter VEC_SIZE      = 16        // Parallel vector lanes
) (
    input  wire                         clk,
    input  wire                         rst_n,

    // Data input
    input  wire [IN_WIDTH-1:0]          data_in [0:VEC_SIZE-1],
    input  wire                         data_valid,

    // Quantization parameters (per-layer, configurable)
    input  wire [SCALE_WIDTH-1:0]       scale,          // Scale factor
    input  wire [OUT_WIDTH-1:0]         zero_point,     // Zero point offset
    input  wire [3:0]                   shift,          // Power-of-2 shift amount (scale ≈ 2^(-shift))
    input  wire [1:0]                   round_mode,     // 00=nearest, 01=floor, 10=ceil
    input  wire                         use_shift,      // 1=use shift (fast), 0=use multiply (precise)

    // Data output
    output wire [OUT_WIDTH-1:0]         data_out [0:VEC_SIZE-1],
    output wire                         data_valid_out,

    // Status
    output wire                         overflow,       // Saturation occurred
    output wire                         underflow
);

    //-------------------------------------------------------------------------
    // Pipeline: Stage1 (scale) → Stage2 (round+sat) → Output
    //-------------------------------------------------------------------------

    // Stage 1: Apply scale
    reg  [2*IN_WIDTH-1:0] stage1_scaled [0:VEC_SIZE-1];
    reg                   stage1_valid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage1_valid <= 1'b0;
        end else begin
            stage1_valid <= data_valid;
            if (data_valid) begin
                for (int i = 0; i < VEC_SIZE; i++) begin
                    if (use_shift) begin
                        // Power-of-2 scaling with rounding
                        stage1_scaled[i] <= data_in[i] >>> shift;
                    end else begin
                        // Multiply by scale
                        stage1_scaled[i] <= data_in[i] * {{(IN_WIDTH-SCALE_WIDTH){scale[SCALE_WIDTH-1]}}, scale};
                    end
                end
            end
        end
    end

    //-------------------------------------------------------------------------
    // Stage 2: Rounding, zero-point addition, saturation
    //-------------------------------------------------------------------------
    reg [OUT_WIDTH-1:0] stage2_data [0:VEC_SIZE-1];
    reg                 stage2_valid;
    reg                 overflow_reg;
    reg                 underflow_reg;

    // Rounding: add 0.5 before truncation (for nearest rounding)
    function [IN_WIDTH-1:0] round_value;
        input [IN_WIDTH-1:0] val;
        input [1:0]          mode;
        reg half_lsb;
        begin
            half_lsb = 1'b1;  // 0.5 in fixed-point at bit IN_WIDTH-1
            case (mode)
                2'b00: round_value = val + half_lsb;  // Nearest
                2'b01: round_value = val;              // Floor (truncate)
                2'b10: round_value = val + 1;          // Ceil
                default: round_value = val + half_lsb;
            endcase
        end
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage2_valid  <= 1'b0;
            overflow_reg  <= 1'b0;
            underflow_reg <= 1'b0;
        end else begin
            stage2_valid <= stage1_valid;
            if (stage1_valid) begin
                for (int i = 0; i < VEC_SIZE; i++) begin
                    automatic signed [IN_WIDTH-1:0] scaled_rounded;
                    automatic signed [IN_WIDTH:0]   with_zp;
                    scaled_rounded = round_value(stage1_scaled[i][IN_WIDTH +: IN_WIDTH], round_mode);
                    with_zp        = scaled_rounded + zero_point;

                    // Saturation
                    if (with_zp > (2**(OUT_WIDTH-1) - 1)) begin
                        stage2_data[i] <= (2**(OUT_WIDTH-1) - 1);
                        overflow_reg   <= 1'b1;
                    end else if (with_zp < -(2**(OUT_WIDTH-1))) begin
                        stage2_data[i] <= -(2**(OUT_WIDTH-1));
                        underflow_reg  <= 1'b1;
                    end else begin
                        stage2_data[i] <= with_zp[OUT_WIDTH-1:0];
                    end
                end
            end
        end
    end

    //-------------------------------------------------------------------------
    // Output
    //-------------------------------------------------------------------------
    generate
        genvar g;
        for (g = 0; g < VEC_SIZE; g = g + 1) begin : gen_out
            assign data_out[g] = stage2_data[g];
        end
    endgenerate

    assign data_valid_out = stage2_valid;
    assign overflow       = overflow_reg;
    assign underflow      = underflow_reg;

endmodule
