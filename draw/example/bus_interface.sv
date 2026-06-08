//=============================================================================
// AXI4-Lite Slave Bus Interface — Memory-mapped CSRs for NPU configuration
// Provides host CPU access to NPU control registers and status
//
// Memory Map:
//   0x00: CTRL       — Control register (start, reset, interrupt enable)
//   0x04: STATUS     — Status register (busy, done, error flags)
//   0x08: LAYER_CFG  — Layer configuration pointer
//   0x0C: INPUT_ADDR — Input tensor base address
//   0x10: WGT_ADDR   — Weight tensor base address
//   0x14: OUTPUT_ADDR— Output tensor base address
//   0x18: SCALE_ADDR — Quantization scale table address
//   0x1C: INT_STATUS — Interrupt status / clear
//=============================================================================

module bus_interface #(
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 32
) (
    input  wire                         clk,
    input  wire                         rst_n,

    //-------------------------------------------------------------------------
    // AXI4-Lite Slave Interface
    //-------------------------------------------------------------------------
    // Write Address Channel
    input  wire [AXI_ADDR_WIDTH-1:0]    s_axi_awaddr,
    input  wire [2:0]                   s_axi_awprot,
    input  wire                         s_axi_awvalid,
    output wire                         s_axi_awready,

    // Write Data Channel
    input  wire [AXI_DATA_WIDTH-1:0]    s_axi_wdata,
    input  wire [AXI_DATA_WIDTH/8-1:0]  s_axi_wstrb,
    input  wire                         s_axi_wvalid,
    output wire                         s_axi_wready,

    // Write Response Channel
    output wire [1:0]                   s_axi_bresp,
    output wire                         s_axi_bvalid,
    input  wire                         s_axi_bready,

    // Read Address Channel
    input  wire [AXI_ADDR_WIDTH-1:0]    s_axi_araddr,
    input  wire [2:0]                   s_axi_arprot,
    input  wire                         s_axi_arvalid,
    output wire                         s_axi_arready,

    // Read Data Channel
    output wire [AXI_DATA_WIDTH-1:0]    s_axi_rdata,
    output wire [1:0]                   s_axi_rresp,
    output wire                         s_axi_rvalid,
    input  wire                         s_axi_rready,

    //-------------------------------------------------------------------------
    // NPU Register Interface (to internal logic)
    //-------------------------------------------------------------------------
    output wire                         npu_start,      // Start computation
    output wire                         npu_soft_rst,   // Software reset
    output wire                         npu_irq_en,     // Interrupt enable

    input  wire                         npu_busy,       // NPU is computing
    input  wire                         npu_done,       // Computation complete
    input  wire                         npu_error,      // Error occurred

    output wire [AXI_ADDR_WIDTH-1:0]    input_addr,
    output wire [AXI_ADDR_WIDTH-1:0]    weight_addr,
    output wire [AXI_ADDR_WIDTH-1:0]    output_addr,
    output wire [AXI_ADDR_WIDTH-1:0]    scale_addr,

    output wire                         irq_out         // Interrupt to host
);

    //-------------------------------------------------------------------------
    // Register definitions
    //-------------------------------------------------------------------------
    localparam REG_CTRL        = 8'h00;
    localparam REG_STATUS      = 8'h04;
    localparam REG_LAYER_CFG   = 8'h08;
    localparam REG_INPUT_ADDR  = 8'h0C;
    localparam REG_WGT_ADDR    = 8'h10;
    localparam REG_OUTPUT_ADDR = 8'h14;
    localparam REG_SCALE_ADDR  = 8'h18;
    localparam REG_INT_STATUS  = 8'h1C;

    // Internal registers
    reg [AXI_DATA_WIDTH-1:0] reg_ctrl;
    reg [AXI_DATA_WIDTH-1:0] reg_input_addr;
    reg [AXI_DATA_WIDTH-1:0] reg_weight_addr;
    reg [AXI_DATA_WIDTH-1:0] reg_output_addr;
    reg [AXI_DATA_WIDTH-1:0] reg_scale_addr;
    reg [AXI_DATA_WIDTH-1:0] reg_int_status;

    // Status is read-only, assembled from NPU status signals
    wire [AXI_DATA_WIDTH-1:0] reg_status;
    assign reg_status = {28'b0, npu_error, npu_done, npu_busy, 1'b0};

    // AXI handshake
    wire aw_hs, w_hs, b_hs, ar_hs, r_hs;
    assign aw_hs = s_axi_awvalid && s_axi_awready;
    assign w_hs  = s_axi_wvalid  && s_axi_wready;
    assign b_hs  = s_axi_bvalid  && s_axi_bready;
    assign ar_hs = s_axi_arvalid && s_axi_arready;
    assign r_hs  = s_axi_rvalid  && s_axi_rready;

    // Simple AXI handshake (no backpressure in this simplified interface)
    assign s_axi_awready = 1'b1;
    assign s_axi_wready  = 1'b1;
    assign s_axi_arready = 1'b1;

    // Write operation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_ctrl        <= '0;
            reg_input_addr  <= '0;
            reg_weight_addr <= '0;
            reg_output_addr <= '0;
            reg_scale_addr  <= '0;
            reg_int_status  <= '0;
        end else if (aw_hs && w_hs) begin
            case (s_axi_awaddr[7:0])
                REG_CTRL:        reg_ctrl        <= s_axi_wdata;
                REG_INPUT_ADDR:  reg_input_addr  <= s_axi_wdata;
                REG_WGT_ADDR:    reg_weight_addr <= s_axi_wdata;
                REG_OUTPUT_ADDR: reg_output_addr <= s_axi_wdata;
                REG_SCALE_ADDR:  reg_scale_addr  <= s_axi_wdata;
                REG_INT_STATUS:  reg_int_status  <= s_axi_wdata;  // Write 1 to clear
            endcase
        end
    end

    // Write response
    reg bvalid_reg;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bvalid_reg <= 1'b0;
        else if (aw_hs && w_hs)
            bvalid_reg <= 1'b1;
        else if (b_hs)
            bvalid_reg <= 1'b0;
    end
    assign s_axi_bvalid = bvalid_reg;
    assign s_axi_bresp  = 2'b00;  // OKAY

    // Read operation
    reg [AXI_DATA_WIDTH-1:0] rdata_reg;
    reg                      rvalid_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rdata_reg  <= '0;
            rvalid_reg <= 1'b0;
        end else if (ar_hs) begin
            rvalid_reg <= 1'b1;
            case (s_axi_araddr[7:0])
                REG_CTRL:        rdata_reg <= reg_ctrl;
                REG_STATUS:      rdata_reg <= reg_status;
                REG_INPUT_ADDR:  rdata_reg <= reg_input_addr;
                REG_WGT_ADDR:    rdata_reg <= reg_weight_addr;
                REG_OUTPUT_ADDR: rdata_reg <= reg_output_addr;
                REG_SCALE_ADDR:  rdata_reg <= reg_scale_addr;
                REG_INT_STATUS:  rdata_reg <= reg_int_status;
                default:         rdata_reg <= '0;
            endcase
        end else if (r_hs) begin
            rvalid_reg <= 1'b0;
        end
    end
    assign s_axi_rdata = rdata_reg;
    assign s_axi_rresp = 2'b00;  // OKAY
    assign s_axi_rvalid = rvalid_reg;

    //-------------------------------------------------------------------------
    // Register output assignments
    //-------------------------------------------------------------------------
    assign npu_start    = reg_ctrl[0];
    assign npu_soft_rst = reg_ctrl[1];
    assign npu_irq_en   = reg_ctrl[2];

    assign input_addr  = reg_input_addr;
    assign weight_addr = reg_weight_addr;
    assign output_addr = reg_output_addr;
    assign scale_addr  = reg_scale_addr;

    // Interrupt generation (on done or error)
    assign irq_out = reg_int_status[0] && npu_irq_en &&
                     (reg_int_status[1] ? npu_done : 1'b0 ||
                      reg_int_status[2] ? npu_error : 1'b0);

endmodule
