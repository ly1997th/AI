//=============================================================================
// NPU Top-Level Module — Neural Processing Unit
// Integrates all NPU subsystems: DMA, Scratchpad, MAC Array, Activation,
// Pooling, Quantization, AGU, Controller, Bus Interface, Clock/Reset Gen
//
// Configuration:
//   - NUM_MACS = 256 (16×16 systolic array)
//   - DATA_WIDTH = 8-bit (INT8)
//   - ACCUM_WIDTH = 32-bit (INT32 accumulation)
//   - SRAM_DEPTH = 4096 × 32-bit scratchpad
//   - Three clock domains: sys (200MHz), core (400MHz), mem (100MHz)
//=============================================================================

module npu_top #(
    parameter NUM_MACS      = 256,          // Total MAC units (16×16)
    parameter DATA_WIDTH    = 8,            // Input data width
    parameter ACCUM_WIDTH   = 32,           // Accumulator width
    parameter SRAM_DEPTH    = 4096,         // Scratchpad depth
    parameter SRAM_WIDTH    = 32,           // Scratchpad data width
    parameter AXI_ADDR_W    = 32,           // AXI address width
    parameter AXI_DATA_W    = 32            // AXI data width
) (
    //-------------------------------------------------------------------------
    // Clock and Reset (from external board)
    //-------------------------------------------------------------------------
    input  wire                         ext_clk,            // 200 MHz external oscillator
    input  wire                         ext_rst_n,          // External reset (active low)

    //-------------------------------------------------------------------------
    // AXI4-Lite Slave Interface (Host CPU configuration)
    //-------------------------------------------------------------------------
    input  wire [AXI_ADDR_W-1:0]        s_axi_awaddr,
    input  wire                         s_axi_awvalid,
    output wire                         s_axi_awready,
    input  wire [AXI_DATA_W-1:0]        s_axi_wdata,
    input  wire                         s_axi_wvalid,
    output wire                         s_axi_wready,
    output wire                         s_axi_bvalid,
    input  wire                         s_axi_bready,
    input  wire [AXI_ADDR_W-1:0]        s_axi_araddr,
    input  wire                         s_axi_arvalid,
    output wire                         s_axi_arready,
    output wire [AXI_DATA_W-1:0]        s_axi_rdata,
    output wire                         s_axi_rvalid,
    input  wire                         s_axi_rready,

    //-------------------------------------------------------------------------
    // AXI4 Master Interface (External DRAM access)
    //-------------------------------------------------------------------------
    output wire [AXI_ADDR_W-1:0]        m_axi_awaddr,
    output wire                         m_axi_awvalid,
    input  wire                         m_axi_awready,
    output wire [127:0]                 m_axi_wdata,
    output wire                         m_axi_wlast,
    output wire                         m_axi_wvalid,
    input  wire                         m_axi_wready,
    input  wire                         m_axi_bvalid,
    output wire                         m_axi_bready,
    output wire [AXI_ADDR_W-1:0]        m_axi_araddr,
    output wire                         m_axi_arvalid,
    input  wire                         m_axi_arready,
    input  wire [127:0]                 m_axi_rdata,
    input  wire                         m_axi_rlast,
    input  wire                         m_axi_rvalid,
    output wire                         m_axi_rready,

    //-------------------------------------------------------------------------
    // Interrupt
    //-------------------------------------------------------------------------
    output wire                         irq_out
);

    //=========================================================================
    // Clock and Reset Generation
    //=========================================================================
    wire clk_sys, clk_core, clk_mem;
    wire sys_rst_n, core_rst_n, mem_rst_n;
    wire gated_core_clk, gated_mem_clk;
    wire pll_locked;
    wire pll_stable;

    // PLL lock signal from external (simplified)
    assign pll_locked = 1'b1;  // Assume always locked in simulation

    clk_rst_gen u_clk_rst_gen (
        .ext_clk        (ext_clk),
        .ext_rst_n      (ext_rst_n),
        .pll_locked     (pll_locked),
        .clk_sys        (clk_sys),
        .clk_core       (clk_core),
        .clk_mem        (clk_mem),
        .sys_rst_n      (sys_rst_n),
        .core_rst_n     (core_rst_n),
        .mem_rst_n      (mem_rst_n),
        .core_clk_en    (1'b1),
        .mem_clk_en     (1'b1),
        .gated_core_clk (gated_core_clk),
        .gated_mem_clk  (gated_mem_clk),
        .rst_active     (),
        .pll_stable     (pll_stable)
    );

    //=========================================================================
    // Bus Interface (AXI4-Lite Slave → Internal Register Bus)
    //=========================================================================
    wire        npu_start, npu_soft_rst, npu_irq_en;
    wire        npu_busy, npu_done, npu_error;
    wire [31:0] cfg_input_addr, cfg_weight_addr, cfg_output_addr, cfg_scale_addr;

    bus_interface #(
        .AXI_ADDR_WIDTH (AXI_ADDR_W),
        .AXI_DATA_WIDTH (AXI_DATA_W)
    ) u_bus_interface (
        .clk            (clk_sys),
        .rst_n          (sys_rst_n),
        .s_axi_awaddr   (s_axi_awaddr),
        .s_axi_awprot   (3'b000),
        .s_axi_awvalid  (s_axi_awvalid),
        .s_axi_awready  (s_axi_awready),
        .s_axi_wdata    (s_axi_wdata),
        .s_axi_wstrb    (4'b1111),
        .s_axi_wvalid   (s_axi_wvalid),
        .s_axi_wready   (s_axi_wready),
        .s_axi_bresp    (),
        .s_axi_bvalid   (s_axi_bvalid),
        .s_axi_bready   (s_axi_bready),
        .s_axi_araddr   (s_axi_araddr),
        .s_axi_arprot   (3'b000),
        .s_axi_arvalid  (s_axi_arvalid),
        .s_axi_arready  (s_axi_arready),
        .s_axi_rdata    (s_axi_rdata),
        .s_axi_rresp    (),
        .s_axi_rvalid   (s_axi_rvalid),
        .s_axi_rready   (s_axi_rready),
        .npu_start      (npu_start),
        .npu_soft_rst   (npu_soft_rst),
        .npu_irq_en     (npu_irq_en),
        .npu_busy       (npu_busy),
        .npu_done       (npu_done),
        .npu_error      (npu_error),
        .input_addr     (cfg_input_addr),
        .weight_addr    (cfg_weight_addr),
        .output_addr    (cfg_output_addr),
        .scale_addr     (cfg_scale_addr),
        .irq_out        (irq_out)
    );

    //=========================================================================
    // Controller FSM — Top-level sequencing
    //=========================================================================
    wire        dma_start, dma_done, dma_busy;
    wire [1:0]  dma_dir;
    wire        sp_a_en, sp_a_we, sp_b_en, sp_b_we;
    wire        mac_compute_start, mac_acc_clear, mac_wgt_load;
    wire        mac_busy, mac_done, mac_result_valid;
    wire [1:0]  act_func_sel;
    wire        act_enable, act_valid_out;
    wire        pool_start, pool_mode, pool_done, pool_valid_out;
    wire        quant_enable, quant_valid_out, quant_overflow, quant_underflow;
    wire        agu_start, agu_advance, agu_done, agu_busy;
    wire [3:0]  fsm_state;
    wire [15:0] cycle_count;

    controller u_controller (
        .clk               (clk_sys),
        .rst_n             (sys_rst_n),
        .start             (npu_start),
        .soft_rst          (npu_soft_rst),
        .busy              (npu_busy),
        .done              (npu_done),
        .error             (npu_error),
        .dma_start         (dma_start),
        .dma_dir           (dma_dir),
        .dma_done          (dma_done),
        .dma_busy          (dma_busy),
        .sp_a_en           (sp_a_en),
        .sp_a_we           (sp_a_we),
        .sp_b_en           (sp_b_en),
        .sp_b_we           (sp_b_we),
        .mac_compute_start (mac_compute_start),
        .mac_acc_clear     (mac_acc_clear),
        .mac_wgt_load      (mac_wgt_load),
        .mac_busy          (mac_busy),
        .mac_done          (mac_done),
        .mac_result_valid  (mac_result_valid),
        .act_func_sel      (act_func_sel),
        .act_enable        (act_enable),
        .act_valid_out     (act_valid_out),
        .pool_start        (pool_start),
        .pool_mode         (pool_mode),
        .pool_done         (pool_done),
        .pool_valid_out    (pool_valid_out),
        .quant_enable      (quant_enable),
        .quant_valid_out   (quant_valid_out),
        .quant_overflow    (quant_overflow),
        .quant_underflow   (quant_underflow),
        .agu_start         (agu_start),
        .agu_advance       (agu_advance),
        .agu_done          (agu_done),
        .agu_busy          (agu_busy),
        .current_state     (fsm_state),
        .cycle_count       (cycle_count)
    );

    //=========================================================================
    // DMA Engine — External DRAM ↔ Scratchpad data movement
    //=========================================================================
    wire        sp_en, sp_we;
    wire [11:0] sp_addr;
    wire [31:0] sp_wdata, sp_rdata;
    wire        sp_ready;

    dma_engine #(
        .AXI_DATA_WIDTH  (128),
        .AXI_ADDR_WIDTH  (AXI_ADDR_W),
        .AXI_ID_WIDTH    (4),
        .DESCRIPTOR_DEPTH(8)
    ) u_dma_engine (
        .clk            (clk_mem),
        .rst_n          (mem_rst_n),
        .dma_start      (dma_start),
        .dma_dir        (dma_dir),
        .dma_src_addr   (cfg_input_addr),
        .dma_dst_addr   (cfg_output_addr),
        .dma_length     (16'd1024),
        .dma_burst_len  (8'd15),
        .dma_done       (dma_done),
        .dma_busy       (dma_busy),
        .sp_en          (sp_en),
        .sp_we          (sp_we),
        .sp_addr        (sp_addr),
        .sp_wdata       (sp_wdata),
        .sp_rdata       (sp_rdata),
        .sp_ready       (sp_ready),
        .m_axi_awaddr   (m_axi_awaddr),
        .m_axi_awlen    (),
        .m_axi_awsize   (),
        .m_axi_awburst  (),
        .m_axi_awvalid  (m_axi_awvalid),
        .m_axi_awready  (m_axi_awready),
        .m_axi_wdata    (m_axi_wdata),
        .m_axi_wstrb    (),
        .m_axi_wlast    (m_axi_wlast),
        .m_axi_wvalid   (m_axi_wvalid),
        .m_axi_wready   (m_axi_wready),
        .m_axi_bresp    (),
        .m_axi_bvalid   (m_axi_bvalid),
        .m_axi_bready   (m_axi_bready),
        .m_axi_araddr   (m_axi_araddr),
        .m_axi_arlen    (),
        .m_axi_arsize   (),
        .m_axi_arburst  (),
        .m_axi_arvalid  (m_axi_arvalid),
        .m_axi_arready  (m_axi_arready),
        .m_axi_rdata    (m_axi_rdata),
        .m_axi_rresp    (),
        .m_axi_rlast    (m_axi_rlast),
        .m_axi_rvalid   (m_axi_rvalid),
        .m_axi_rready   (m_axi_rready)
    );

    //=========================================================================
    // Scratchpad SRAM — On-chip weight/activation storage
    //=========================================================================
    scratchpad #(
        .DATA_WIDTH (SRAM_WIDTH),
        .ADDR_WIDTH (12),
        .DEPTH      (SRAM_DEPTH)
    ) u_scratchpad (
        .clk            (clk_core),
        .rst_n          (core_rst_n),
        .port_a_en      (sp_a_en),
        .port_a_we      (sp_a_we),
        .port_a_addr    (sp_addr),
        .port_a_wdata   (sp_wdata),
        .port_a_rdata   (sp_rdata),
        .port_a_ready   (sp_ready),
        .port_b_en      (sp_b_en),
        .port_b_we      (sp_b_we),
        .port_b_addr    (12'd0),  // AGU-driven in full implementation
        .port_b_wdata   (32'd0),
        .port_b_rdata   (),
        .port_b_ready   ()
    );

    //=========================================================================
    // Address Generation Unit — Memory address computation
    //=========================================================================
    wire [15:0] agu_input_addr, agu_weight_addr, agu_output_addr;

    agu #(
        .ADDR_WIDTH (16),
        .MAX_DIM    (10)
    ) u_agu (
        .clk            (clk_core),
        .rst_n          (core_rst_n),
        .agu_start      (agu_start),
        .agu_advance    (agu_advance),
        .agu_done       (agu_done),
        .agu_busy       (agu_busy),
        .N              (10'd1),
        .C              (10'd3),
        .H              (10'd32),
        .W              (10'd32),
        .K              (10'd64),
        .R              (10'd3),
        .S              (10'd3),
        .pad_h          (10'd1),
        .pad_w          (10'd1),
        .stride_h       (10'd1),
        .stride_w       (10'd1),
        .dilate_h       (10'd1),
        .dilate_w       (10'd1),
        .input_base     (16'd0),
        .weight_base    (16'd4096),
        .output_base    (16'd8192),
        .input_addr     (agu_input_addr),
        .weight_addr    (agu_weight_addr),
        .output_addr    (agu_output_addr),
        .cur_n          (),
        .cur_c          (),
        .cur_h          (),
        .cur_w          (),
        .cur_k          (),
        .cur_r          (),
        .cur_s          ()
    );

    //=========================================================================
    // MAC Array — Systolic compute engine (16×16)
    //=========================================================================
    wire [DATA_WIDTH-1:0]  mac_act_in [0:15];
    wire [DATA_WIDTH-1:0]  mac_wgt_in [0:15];
    wire [ACCUM_WIDTH-1:0] mac_partial_in [0:15];
    wire [ACCUM_WIDTH-1:0] mac_result_out [0:15];

    // Connect scratchpad data to MAC array inputs (simplified wiring)
    generate
        genvar gi;
        for (gi = 0; gi < 16; gi = gi + 1) begin : gen_mac_inputs
            assign mac_act_in[gi]     = sp_rdata[7:0];     // Lower 8 bits
            assign mac_wgt_in[gi]     = sp_rdata[15:8];    // Next 8 bits
            assign mac_partial_in[gi] = '0;                 // Zero initial partial sum
        end
    endgenerate

    mac_array #(
        .ARRAY_SIZE  (16),
        .DATA_WIDTH  (DATA_WIDTH),
        .ACCUM_WIDTH (ACCUM_WIDTH)
    ) u_mac_array (
        .clk            (gated_core_clk),
        .rst_n          (core_rst_n),
        .act_in         (mac_act_in),
        .act_valid      (1'b1),
        .wgt_in         (mac_wgt_in),
        .wgt_valid      (1'b1),
        .wgt_load       (mac_wgt_load),
        .partial_in     (mac_partial_in),
        .compute_start  (mac_compute_start),
        .acc_clear      (mac_acc_clear),
        .result_out     (mac_result_out),
        .result_valid   (mac_result_valid),
        .busy           (mac_busy),
        .done           (mac_done)
    );

    //=========================================================================
    // Activation Unit — ReLU/LeakyReLU/Sigmoid/Tanh
    //=========================================================================
    wire [15:0] act_data_in [0:15];   // 16-bit post-MAC data
    wire [15:0] act_data_out [0:15];

    // Truncate accumulator to 16-bit for activation (simplified)
    generate
        for (gi = 0; gi < 16; gi = gi + 1) begin : gen_act_inputs
            assign act_data_in[gi] = mac_result_out[gi][15:0];
        end
    endgenerate

    activation #(
        .DATA_WIDTH (16),
        .VEC_SIZE   (16),
        .ACT_FUNC   (2'b00)
    ) u_activation (
        .clk            (gated_core_clk),
        .rst_n          (core_rst_n),
        .data_in        (act_data_in),
        .data_valid     (mac_result_valid),
        .data_out       (act_data_out),
        .data_valid_out (act_valid_out),
        .act_func_sel   (act_func_sel),
        .prelu_slope    (16'd0),
        .leaky_slope    (16'd262)  // ~0.01 in Q16
    );

    //=========================================================================
    // Pooling Unit — Max/Average pooling
    //=========================================================================
    wire [15:0] pool_out;
    wire        pool_valid_out_w, pool_done_w;

    // Simplified: feed first activation output to pooling
    pooling #(
        .DATA_WIDTH (16),
        .MAX_KERNEL (3),
        .MAX_LINES  (256)
    ) u_pooling (
        .clk            (gated_core_clk),
        .rst_n          (core_rst_n),
        .data_in        (act_data_out[0]),
        .data_valid     (act_valid_out),
        .line_start     (1'b0),
        .frame_start    (pool_start),
        .kernel_size    (4'd2),
        .stride         (4'd2),
        .pool_mode      (pool_mode),
        .input_width    (10'd32),
        .input_height   (10'd32),
        .data_out       (pool_out),
        .data_valid_out (pool_valid_out_w),
        .pool_done      (pool_done_w)
    );

    assign pool_valid_out = pool_valid_out_w;
    assign pool_done      = pool_done_w;

    //=========================================================================
    // Quantization Unit — INT32→INT8 with scale/zero-point
    //=========================================================================
    wire [31:0] quant_in [0:15];
    wire [7:0]  quant_out [0:15];

    // Pad pooled data back to 32-bit for quantization
    generate
        for (gi = 0; gi < 16; gi = gi + 1) begin : gen_quant_inputs
            assign quant_in[gi] = {{16{pool_out[15]}}, pool_out};
        end
    endgenerate

    quantization #(
        .IN_WIDTH    (32),
        .OUT_WIDTH   (8),
        .SCALE_WIDTH (16),
        .VEC_SIZE    (16)
    ) u_quantization (
        .clk            (gated_core_clk),
        .rst_n          (core_rst_n),
        .data_in        (quant_in),
        .data_valid     (pool_valid_out),
        .scale          (16'd128),
        .zero_point     (8'd0),
        .shift          (4'd7),
        .round_mode     (2'b00),
        .use_shift      (1'b1),
        .data_out       (quant_out),
        .data_valid_out (quant_valid_out),
        .overflow       (quant_overflow),
        .underflow      (quant_underflow)
    );

endmodule
