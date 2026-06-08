//=============================================================================
// Scratchpad SRAM — Dual-port on-chip memory for weights and activations
// Port A: DMA/External interface (read/write)
// Port B: Compute array interface (read-only for weights, read/write for acts)
//=============================================================================

module scratchpad #(
    parameter DATA_WIDTH    = 32,       // Data width per word
    parameter ADDR_WIDTH    = 12,       // Address width (4K entries)
    parameter DEPTH         = 4096      // Total entries
) (
    input  wire                         clk,
    input  wire                         rst_n,

    //-------------------------------------------------------------------------
    // Port A — DMA / External Bus Interface
    //-------------------------------------------------------------------------
    input  wire                         port_a_en,
    input  wire                         port_a_we,          // 1=write, 0=read
    input  wire [ADDR_WIDTH-1:0]        port_a_addr,
    input  wire [DATA_WIDTH-1:0]        port_a_wdata,
    output wire [DATA_WIDTH-1:0]        port_a_rdata,
    output wire                         port_a_ready,

    //-------------------------------------------------------------------------
    // Port B — Compute Array Interface
    //-------------------------------------------------------------------------
    input  wire                         port_b_en,
    input  wire                         port_b_we,          // 1=write, 0=read
    input  wire [ADDR_WIDTH-1:0]        port_b_addr,
    input  wire [DATA_WIDTH-1:0]        port_b_wdata,
    output wire [DATA_WIDTH-1:0]        port_b_rdata,
    output wire                         port_b_ready
);

    //-------------------------------------------------------------------------
    // SRAM array
    //-------------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    //-------------------------------------------------------------------------
    // Read/write control with read-before-write behavior
    // Port A
    //-------------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] port_a_rdata_reg;
    reg                  port_a_ready_reg;

    always_ff @(posedge clk) begin
        if (port_a_en) begin
            if (port_a_we) begin
                mem[port_a_addr] <= port_a_wdata;
                port_a_rdata_reg <= port_a_wdata;  // Write-through
            end else begin
                port_a_rdata_reg <= mem[port_a_addr];
            end
            port_a_ready_reg <= 1'b1;
        end else begin
            port_a_ready_reg <= 1'b0;
        end
    end

    assign port_a_rdata = port_a_rdata_reg;
    assign port_a_ready = port_a_ready_reg;

    //-------------------------------------------------------------------------
    // Port B
    //-------------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] port_b_rdata_reg;
    reg                  port_b_ready_reg;

    always_ff @(posedge clk) begin
        if (port_b_en) begin
            if (port_b_we) begin
                mem[port_b_addr] <= port_b_wdata;
                port_b_rdata_reg <= port_b_wdata;
            end else begin
                port_b_rdata_reg <= mem[port_b_addr];
            end
            port_b_ready_reg <= 1'b1;
        end else begin
            port_b_ready_reg <= 1'b0;
        end
    end

    assign port_b_rdata = port_b_rdata_reg;
    assign port_b_ready = port_b_ready_reg;

endmodule
