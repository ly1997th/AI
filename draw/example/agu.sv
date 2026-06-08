//=============================================================================
// Address Generation Unit (AGU) — Generates memory addresses for convolution
// Manages nested loops over: N (batch), C (channel), H (height), W (width),
//                             K (output channel), R (kernel height), S (kernel width)
// Supports padding, stride, and dilation parameters
//=============================================================================

module agu #(
    parameter ADDR_WIDTH    = 16,
    parameter MAX_DIM       = 10    // Bits per dimension counter
) (
    input  wire                         clk,
    input  wire                         rst_n,

    // Control
    input  wire                         agu_start,
    input  wire                         agu_advance,    // Advance to next address
    output wire                         agu_done,
    output wire                         agu_busy,

    // Configuration (layer parameters)
    input  wire [MAX_DIM-1:0]           N, C, H, W,     // Input dimensions
    input  wire [MAX_DIM-1:0]           K, R, S,        // Kernel dimensions
    input  wire [MAX_DIM-1:0]           pad_h, pad_w,   // Padding
    input  wire [MAX_DIM-1:0]           stride_h, stride_w,  // Stride
    input  wire [MAX_DIM-1:0]           dilate_h, dilate_w,  // Dilation

    // Base addresses
    input  wire [ADDR_WIDTH-1:0]        input_base,
    input  wire [ADDR_WIDTH-1:0]        weight_base,
    input  wire [ADDR_WIDTH-1:0]        output_base,

    // Generated addresses
    output wire [ADDR_WIDTH-1:0]        input_addr,
    output wire [ADDR_WIDTH-1:0]        weight_addr,
    output wire [ADDR_WIDTH-1:0]        output_addr,

    // Dimensional counters (for debugging)
    output wire [MAX_DIM-1:0]           cur_n, cur_c, cur_h, cur_w,
    output wire [MAX_DIM-1:0]           cur_k, cur_r, cur_s
);

    //-------------------------------------------------------------------------
    // Nested loop counter hierarchy: N → C → H → W → K → R → S (innermost)
    // "C-for" convention: outer loops change slowly, inner loops run fast
    //-------------------------------------------------------------------------
    reg [MAX_DIM-1:0] cnt_n, cnt_c, cnt_h, cnt_w;
    reg [MAX_DIM-1:0] cnt_k, cnt_r, cnt_s;

    // Derived dimensions
    wire [MAX_DIM-1:0] out_h, out_w;
    assign out_h = (H + 2*pad_h - dilate_h*(R-1) - 1) / stride_h + 1;
    assign out_w = (W + 2*pad_w - dilate_w*(S-1) - 1) / stride_w + 1;

    // State
    reg running;
    reg done_reg;

    //-------------------------------------------------------------------------
    // Counter update logic — nested loops
    //-------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_n <= '0; cnt_c <= '0; cnt_h <= '0; cnt_w <= '0;
            cnt_k <= '0; cnt_r <= '0; cnt_s <= '0;
            running <= 1'b0;
            done_reg <= 1'b0;
        end else if (agu_start && !running) begin
            cnt_n <= '0; cnt_c <= '0; cnt_h <= '0; cnt_w <= '0;
            cnt_k <= '0; cnt_r <= '0; cnt_s <= '0;
            running <= 1'b1;
            done_reg <= 1'b0;
        end else if (running && agu_advance) begin
            // Innermost loop: S (kernel width)
            if (cnt_s < S - 1) begin
                cnt_s <= cnt_s + 1;
            end else begin
                cnt_s <= '0;
                // Next: R (kernel height)
                if (cnt_r < R - 1) begin
                    cnt_r <= cnt_r + 1;
                end else begin
                    cnt_r <= '0;
                    // Next: K (output channel)
                    if (cnt_k < K - 1) begin
                        cnt_k <= cnt_k + 1;
                    end else begin
                        cnt_k <= '0;
                        // Next: W (output width)
                        if (cnt_w < out_w - 1) begin
                            cnt_w <= cnt_w + 1;
                        end else begin
                            cnt_w <= '0;
                            // Next: H (output height)
                            if (cnt_h < out_h - 1) begin
                                cnt_h <= cnt_h + 1;
                            end else begin
                                cnt_h <= '0;
                                // Next: C (input channel)
                                if (cnt_c < C - 1) begin
                                    cnt_c <= cnt_c + 1;
                                end else begin
                                    cnt_c <= '0;
                                    // Next: N (batch)
                                    if (cnt_n < N - 1) begin
                                        cnt_n <= cnt_n + 1;
                                    end else begin
                                        cnt_n <= '0;
                                        running <= 1'b0;
                                        done_reg <= 1'b1;
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end else if (!agu_start) begin
            done_reg <= 1'b0;
        end
    end

    //-------------------------------------------------------------------------
    // Address computation
    //-------------------------------------------------------------------------
    wire [ADDR_WIDTH-1:0] h_idx, w_idx;
    assign h_idx = cnt_h * stride_h + cnt_r * dilate_h - pad_h;
    assign w_idx = cnt_w * stride_w + cnt_s * dilate_w - pad_w;

    // Check if coordinates are within valid range
    wire valid_coord;
    assign valid_coord = (h_idx < H) && (w_idx < W);

    // Input address: input_base + n*C*H*W + c*H*W + h*W + w
    assign input_addr = input_base +
        (cnt_n * C * H * W) + (cnt_c * H * W) + (h_idx * W) + w_idx;

    // Weight address: weight_base + k*C*R*S + c*R*S + r*S + s
    assign weight_addr = weight_base +
        (cnt_k * C * R * S) + (cnt_c * R * S) + (cnt_r * S) + cnt_s;

    // Output address: output_base + n*K*out_h*out_w + k*out_h*out_w + cnt_h*out_w + cnt_w
    assign output_addr = output_base +
        (cnt_n * K * out_h * out_w) + (cnt_k * out_h * out_w) +
        (cnt_h * out_w) + cnt_w;

    //-------------------------------------------------------------------------
    // Status outputs
    //-------------------------------------------------------------------------
    assign agu_done = done_reg;
    assign agu_busy = running;

    assign cur_n = cnt_n; assign cur_c = cnt_c;
    assign cur_h = cnt_h; assign cur_w = cnt_w;
    assign cur_k = cnt_k; assign cur_r = cnt_r; assign cur_s = cnt_s;

endmodule
