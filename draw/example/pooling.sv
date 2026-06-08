//=============================================================================
// Pooling Unit — Configurable max/average pooling with sliding window
// Supports: 2×2, 3×3 window with configurable stride
// Operates on a sliding window over input feature maps
//=============================================================================

module pooling #(
    parameter DATA_WIDTH    = 16,
    parameter MAX_KERNEL    = 3,        // Max kernel size
    parameter MAX_LINES     = 256       // Max input line buffer depth
) (
    input  wire                         clk,
    input  wire                         rst_n,

    // Data input stream (line-by-line)
    input  wire [DATA_WIDTH-1:0]        data_in,
    input  wire                         data_valid,
    input  wire                         line_start,     // Start of new line marker
    input  wire                         frame_start,    // Start of new frame marker

    // Configuration
    input  wire [3:0]                   kernel_size,    // 2, 3
    input  wire [3:0]                   stride,         // 1, 2
    input  wire                         pool_mode,      // 0=Max, 1=Average
    input  wire [9:0]                   input_width,
    input  wire [9:0]                   input_height,

    // Data output
    output wire [DATA_WIDTH-1:0]        data_out,
    output wire                         data_valid_out,
    output wire                         pool_done
);

    //-------------------------------------------------------------------------
    // Line buffer for sliding window (stores up to kernel_size-1 lines)
    //-------------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] line_buffer [0:MAX_KERNEL-2][0:MAX_LINES-1];

    // Window registers
    reg [DATA_WIDTH-1:0] window [0:MAX_KERNEL-1][0:MAX_KERNEL-1];
    reg                  window_valid;

    // Counters
    reg [9:0]  col_cnt, row_cnt;
    reg [3:0]  win_col, win_row;
    reg [1:0]  pool_state;  // 0=IDLE, 1=COLLECT, 2=COMPUTE, 3=DONE

    //-------------------------------------------------------------------------
    // Pooling state machine
    //-------------------------------------------------------------------------
    localparam ST_IDLE    = 2'b00;
    localparam ST_COLLECT = 2'b01;
    localparam ST_COMPUTE = 2'b10;
    localparam ST_DONE    = 2'b11;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pool_state <= ST_IDLE;
            col_cnt    <= '0;
            row_cnt    <= '0;
            win_col    <= '0;
            win_row    <= '0;
        end else begin
            case (pool_state)
                ST_IDLE:
                    if (frame_start) pool_state <= ST_COLLECT;

                ST_COLLECT:
                    if (data_valid) begin
                        if (col_cnt == input_width - 1) begin
                            col_cnt <= '0;
                            if (row_cnt == input_height - 1)
                                pool_state <= ST_COMPUTE;
                            else
                                row_cnt <= row_cnt + 1;
                        end else begin
                            col_cnt <= col_cnt + 1;
                        end
                        // Window collection logic
                        if (col_cnt % stride == 0 && row_cnt % stride == 0) begin
                            win_col <= win_col + 1;
                            if (win_col == kernel_size - 1) begin
                                win_col <= '0;
                                win_row <= win_row + 1;
                            end
                        end
                    end

                ST_COMPUTE: begin
                    pool_state <= ST_DONE;
                end

                ST_DONE:
                    pool_state <= ST_IDLE;
            endcase
        end
    end

    //-------------------------------------------------------------------------
    // Max Pooling: find maximum in the kernel window
    //-------------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] max_val;

    always_comb begin
        max_val = window[0][0];
        for (int r = 0; r < MAX_KERNEL; r++) begin
            for (int c = 0; c < MAX_KERNEL; c++) begin
                if (window[r][c][DATA_WIDTH-1] == 1'b0 &&  // Positive
                    window[r][c] > max_val)
                    max_val = window[r][c];
                else if (max_val[DATA_WIDTH-1] == 1'b1 &&  // Max is negative
                         window[r][c] > max_val)
                    max_val = window[r][c];
            end
        end
    end

    //-------------------------------------------------------------------------
    // Average Pooling: sum then divide by kernel_size²
    //-------------------------------------------------------------------------
    reg [DATA_WIDTH+7:0] avg_sum;
    reg [DATA_WIDTH-1:0] avg_result;

    always_comb begin
        avg_sum = '0;
        for (int r = 0; r < MAX_KERNEL; r++) begin
            for (int c = 0; c < MAX_KERNEL; c++)
                avg_sum = avg_sum + {{8{window[r][c][DATA_WIDTH-1]}}, window[r][c]};
        end
        avg_result = avg_sum / (kernel_size * kernel_size);
    end

    assign data_out      = pool_mode ? avg_result : max_val;
    assign data_valid_out = (pool_state == ST_COMPUTE);
    assign pool_done      = (pool_state == ST_DONE);

endmodule
