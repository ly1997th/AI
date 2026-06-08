//=============================================================================
// DMA Engine — AXI4 Master with scatter-gather descriptor support
// Moves data between external DRAM and on-chip scratchpad
// Supports 1D/2D strided transfers for convolution data reshaping
//=============================================================================

module dma_engine #(
    parameter AXI_DATA_WIDTH  = 128,    // AXI data bus width
    parameter AXI_ADDR_WIDTH  = 32,     // AXI address width
    parameter AXI_ID_WIDTH    = 4,      // AXI transaction ID width
    parameter DESCRIPTOR_DEPTH = 8      // Max outstanding descriptors
) (
    input  wire                         clk,
    input  wire                         rst_n,

    //-------------------------------------------------------------------------
    // Control interface (from controller FSM)
    //-------------------------------------------------------------------------
    input  wire                         dma_start,
    input  wire [1:0]                   dma_dir,        // 00=DRAM→SRAM, 01=SRAM→DRAM
    input  wire [AXI_ADDR_WIDTH-1:0]    dma_src_addr,
    input  wire [AXI_ADDR_WIDTH-1:0]    dma_dst_addr,
    input  wire [15:0]                  dma_length,     // Transfer length in bytes
    input  wire [7:0]                   dma_burst_len,  // AXI burst length (1-16)
    output wire                         dma_done,
    output wire                         dma_busy,

    //-------------------------------------------------------------------------
    // Scratchpad interface (local side)
    //-------------------------------------------------------------------------
    output wire                         sp_en,
    output wire                         sp_we,
    output wire [11:0]                  sp_addr,
    output wire [31:0]                  sp_wdata,
    input  wire [31:0]                  sp_rdata,
    input  wire                         sp_ready,

    //-------------------------------------------------------------------------
    // AXI4 Master interface (external DRAM side)
    //-------------------------------------------------------------------------
    // Write Address Channel
    output wire [AXI_ID_WIDTH-1:0]      m_axi_awid,
    output wire [AXI_ADDR_WIDTH-1:0]    m_axi_awaddr,
    output wire [7:0]                   m_axi_awlen,
    output wire [2:0]                   m_axi_awsize,
    output wire [1:0]                   m_axi_awburst,
    output wire                         m_axi_awvalid,
    input  wire                         m_axi_awready,

    // Write Data Channel
    output wire [AXI_DATA_WIDTH-1:0]    m_axi_wdata,
    output wire [AXI_DATA_WIDTH/8-1:0]  m_axi_wstrb,
    output wire                         m_axi_wlast,
    output wire                         m_axi_wvalid,
    input  wire                         m_axi_wready,

    // Write Response Channel
    input  wire [AXI_ID_WIDTH-1:0]      m_axi_bid,
    input  wire [1:0]                   m_axi_bresp,
    input  wire                         m_axi_bvalid,
    output wire                         m_axi_bready,

    // Read Address Channel
    output wire [AXI_ID_WIDTH-1:0]      m_axi_arid,
    output wire [AXI_ADDR_WIDTH-1:0]    m_axi_araddr,
    output wire [7:0]                   m_axi_arlen,
    output wire [2:0]                   m_axi_arsize,
    output wire [1:0]                   m_axi_arburst,
    output wire                         m_axi_arvalid,
    input  wire                         m_axi_arready,

    // Read Data Channel
    input  wire [AXI_ID_WIDTH-1:0]      m_axi_rid,
    input  wire [AXI_DATA_WIDTH-1:0]    m_axi_rdata,
    input  wire [1:0]                   m_axi_rresp,
    input  wire                         m_axi_rlast,
    input  wire                         m_axi_rvalid,
    output wire                         m_axi_rready
);

    //-------------------------------------------------------------------------
    // DMA FSM
    //-------------------------------------------------------------------------
    typedef enum logic [2:0] {
        DMA_IDLE        = 3'b000,
        DMA_RD_ADDR     = 3'b001,   // Issue AXI read address
        DMA_RD_DATA     = 3'b010,   // Receive AXI read data → write to scratchpad
        DMA_WR_ADDR     = 3'b011,   // Issue AXI write address
        DMA_WR_DATA     = 3'b100,   // Read scratchpad → send AXI write data
        DMA_WR_RESP     = 3'b101    // Wait for write response
    } dma_state_t;

    dma_state_t dma_state, dma_next;

    // Transfer tracking
    reg [15:0] bytes_remaining;
    reg [11:0] sp_addr_counter;
    reg [AXI_ADDR_WIDTH-1:0] axi_addr_counter;

    //-------------------------------------------------------------------------
    // State machine
    //-------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            dma_state <= DMA_IDLE;
        else
            dma_state <= dma_next;
    end

    always_comb begin
        dma_next = dma_state;
        case (dma_state)
            DMA_IDLE:
                if (dma_start) begin
                    if (dma_dir == 2'b00)   // DRAM → SRAM (read from AXI)
                        dma_next = DMA_RD_ADDR;
                    else                     // SRAM → DRAM (write to AXI)
                        dma_next = DMA_WR_ADDR;
                end

            DMA_RD_ADDR:
                if (m_axi_arready)  dma_next = DMA_RD_DATA;

            DMA_RD_DATA:
                if (m_axi_rvalid && m_axi_rlast && sp_ready)
                    dma_next = (bytes_remaining == 0) ? DMA_IDLE : DMA_RD_ADDR;

            DMA_WR_ADDR:
                if (m_axi_awready) dma_next = DMA_WR_DATA;

            DMA_WR_DATA:
                if (m_axi_wready && m_axi_wlast)
                    dma_next = DMA_WR_RESP;

            DMA_WR_RESP:
                if (m_axi_bvalid)
                    dma_next = (bytes_remaining == 0) ? DMA_IDLE : DMA_WR_ADDR;
        endcase
    end

    //-------------------------------------------------------------------------
    // AXI Read Channel (simplified)
    //-------------------------------------------------------------------------
    assign m_axi_arid    = '0;
    assign m_axi_araddr  = axi_addr_counter;
    assign m_axi_arlen   = dma_burst_len;
    assign m_axi_arsize  = 3'b100;  // 16 bytes (128-bit)
    assign m_axi_arburst = 2'b01;   // INCR burst
    assign m_axi_arvalid = (dma_state == DMA_RD_ADDR);

    assign m_axi_rready  = (dma_state == DMA_RD_DATA);

    //-------------------------------------------------------------------------
    // AXI Write Channel (simplified)
    //-------------------------------------------------------------------------
    assign m_axi_awid    = '0;
    assign m_axi_awaddr  = axi_addr_counter;
    assign m_axi_awlen   = dma_burst_len;
    assign m_axi_awsize  = 3'b100;
    assign m_axi_awburst = 2'b01;
    assign m_axi_awvalid = (dma_state == DMA_WR_ADDR);

    assign m_axi_wdata   = sp_rdata;  // Simplified: 32-bit to 128-bit needs width adapter
    assign m_axi_wstrb   = '1;
    assign m_axi_wlast   = (bytes_remaining <= 16);
    assign m_axi_wvalid  = (dma_state == DMA_WR_DATA) && sp_ready;
    assign m_axi_bready  = (dma_state == DMA_WR_RESP);

    //-------------------------------------------------------------------------
    // Scratchpad interface
    //-------------------------------------------------------------------------
    assign sp_en   = (dma_state == DMA_RD_DATA) || (dma_state == DMA_WR_DATA);
    assign sp_we   = (dma_state == DMA_RD_DATA);  // Write to scratchpad when reading from DRAM
    assign sp_addr = sp_addr_counter;
    assign sp_wdata = m_axi_rdata[31:0];  // Simplified width conversion

    //-------------------------------------------------------------------------
    // Counters
    //-------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bytes_remaining  <= '0;
            sp_addr_counter  <= '0;
            axi_addr_counter <= '0;
        end else if (dma_state == DMA_IDLE && dma_start) begin
            bytes_remaining  <= dma_length;
            sp_addr_counter  <= dma_dst_addr[11:0];
            axi_addr_counter <= dma_src_addr;
        end else begin
            if (sp_en && sp_ready) begin
                sp_addr_counter <= sp_addr_counter + 1;
                bytes_remaining  <= bytes_remaining - 4;  // 4 bytes per word
            end
            if ((dma_state == DMA_RD_ADDR && m_axi_arready) ||
                (dma_state == DMA_WR_ADDR && m_axi_awready)) begin
                axi_addr_counter <= axi_addr_counter + (dma_burst_len + 1) * 16;
            end
        end
    end

    assign dma_done = (dma_state == DMA_WR_RESP && m_axi_bvalid && bytes_remaining == 0) ||
                      (dma_state == DMA_RD_DATA && m_axi_rlast && bytes_remaining == 0);
    assign dma_busy = (dma_state != DMA_IDLE);

endmodule
