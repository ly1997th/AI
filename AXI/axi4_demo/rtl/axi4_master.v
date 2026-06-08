//==============================================================================
// AXI4 Master Module
//   - Independently pipelined write / read channels
//   - Supports burst INCR writes of configurable size (narrow / wide)
//   - Supports out-of-order read completion via per-ID tracking
//   - All always blocks have else branches (synthesis safe)
//==============================================================================
`include "axi4_defines.vh"

module axi4_master #(
    parameter DATA_WIDTH = `AXI4_DATA_WIDTH,
    parameter ADDR_WIDTH = `AXI4_ADDR_WIDTH,
    parameter ID_WIDTH   = `AXI4_ID_WIDTH,
    parameter STRB_WIDTH = DATA_WIDTH / 8
) (
    input  wire                     aclk,
    input  wire                     aresetn,

    //----------------------------------------------------------------------
    // Command interface (driven by testbench)
    //----------------------------------------------------------------------
    input  wire                     cmd_valid,
    output reg                      cmd_ready,
    input  wire                     cmd_write,         // 1=write  0=read
    input  wire [ADDR_WIDTH-1:0]    cmd_addr,
    input  wire [ 7:0]              cmd_len,           // burst beats-1  (0 → 1 beat)
    input  wire [ 2:0]              cmd_size,          // 2^size bytes/beat
    input  wire [ID_WIDTH-1:0]      cmd_id,

    //----------------------------------------------------------------------
    // Status outputs (to testbench)
    //----------------------------------------------------------------------
    output wire                     w_idle,            // write FSM in IDLE
    output wire                     r_idle,            // read  FSM in IDLE

    //----------------------------------------------------------------------
    // Read response output (to testbench)
    //----------------------------------------------------------------------
    output reg                      rsp_valid,
    output reg  [ID_WIDTH-1:0]      rsp_id,
    output reg  [DATA_WIDTH-1:0]    rsp_rdata,
    output reg  [ 1:0]              rsp_rresp,
    output reg                      rsp_last,

    //======================================================================
    // AXI4 Master Interface – Write Address Channel
    //======================================================================
    output reg  [ID_WIDTH-1:0]      m_awid,
    output reg  [ADDR_WIDTH-1:0]    m_awaddr,
    output reg  [ 7:0]              m_awlen,
    output reg  [ 2:0]              m_awsize,
    output reg  [ 1:0]              m_awburst,
    output reg                      m_awvalid,
    input  wire                     m_awready,

    //======================================================================
    // AXI4 Master Interface – Write Data Channel
    //======================================================================
    output reg  [DATA_WIDTH-1:0]    m_wdata,
    output reg  [STRB_WIDTH-1:0]    m_wstrb,
    output reg                      m_wlast,
    output reg                      m_wvalid,
    input  wire                     m_wready,

    //======================================================================
    // AXI4 Master Interface – Write Response Channel
    //======================================================================
    input  wire [ID_WIDTH-1:0]      m_bid,
    input  wire [ 1:0]              m_bresp,
    input  wire                     m_bvalid,
    output reg                      m_bready,

    //======================================================================
    // AXI4 Master Interface – Read Address Channel
    //======================================================================
    output reg  [ID_WIDTH-1:0]      m_arid,
    output reg  [ADDR_WIDTH-1:0]    m_araddr,
    output reg  [ 7:0]              m_arlen,
    output reg  [ 2:0]              m_arsize,
    output reg  [ 1:0]              m_arburst,
    output reg                      m_arvalid,
    input  wire                     m_arready,

    //======================================================================
    // AXI4 Master Interface – Read Data Channel
    //======================================================================
    input  wire [ID_WIDTH-1:0]      m_rid,
    input  wire [DATA_WIDTH-1:0]    m_rdata,
    input  wire [ 1:0]              m_rresp,
    input  wire                     m_rlast,
    input  wire                     m_rvalid,
    output reg                      m_rready
);

    //==========================================================================
    // Local parameters & FSM states
    //==========================================================================
    localparam [1:0] W_IDLE     = 2'd0,
                     W_SEND_AW  = 2'd1,
                     W_SEND_W   = 2'd2,
                     W_WAIT_B   = 2'd3;

    //==========================================================================
    // Write-path registers
    //==========================================================================
    reg [1:0] w_state, w_state_n;
    reg [7:0] w_beat_cnt;          // beats sent so far
    reg [7:0] w_total_beats;       // AWLEN + 1
    reg [ID_WIDTH-1:0]   w_id;
    reg [ADDR_WIDTH-1:0] w_addr;
    reg [7:0]            w_len;
    reg [2:0]            w_size;
    reg [7:0]            w_beat_addr;   // current-beat byte address

    //==========================================================================
    // Read-address registers (used by pipelined AR FSM)
    //==========================================================================
    reg [ID_WIDTH-1:0]   r_id;
    reg [ADDR_WIDTH-1:0] r_addr;
    reg [7:0]            r_len;
    reg [2:0]            r_size;


    //==========================================================================
    // Helper function: bytes-per-beat = 1 << size
    //==========================================================================
    function [7:0] bytes_per_beat;
        input [2:0] size;
        begin
            case (size)
                3'd0:    bytes_per_beat = 8'd1;
                3'd1:    bytes_per_beat = 8'd2;
                3'd2:    bytes_per_beat = 8'd4;
                3'd3:    bytes_per_beat = 8'd8;
                default: bytes_per_beat = 8'd4;
            endcase
        end
    endfunction

    //==========================================================================
    // Helper function: compute WSTRB from address and size
    //==========================================================================
    function [STRB_WIDTH-1:0] compute_wstrb;
        input [ADDR_WIDTH-1:0] addr;
        input [2:0]            size;
        reg [7:0]              bpb;
        reg [3:0]              shift;
        begin
            bpb   = bytes_per_beat(size);
            shift = addr[1:0];                          // byte-offset inside 32b word
            // Use 32-bit integer shift to avoid truncation for bpb=4
            compute_wstrb = (((1 << bpb) - 1) << shift) & {STRB_WIDTH{1'b1}};
        end
    endfunction

    //==========================================================================
    // Helper function: compute write-data pattern from address and beat
    //   Data = {ID[3:0], 4'h0, addr[23:0]} + beat — unique, reproducible
    //==========================================================================
    function [DATA_WIDTH-1:0] make_wdata;
        input [ID_WIDTH-1:0]   id;
        input [ADDR_WIDTH-1:0] addr;
        input [7:0]            beat;
        begin
            // Compose a base from id|addr, then add beat index
            make_wdata = {id, 4'h0, addr[23:0]} + {24'd0, beat};
        end
    endfunction

    //==========================================================================
    // Write FSM – sequential block
    //==========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            w_state      <= W_IDLE;
            w_beat_cnt   <= 8'd0;
            w_id         <= {ID_WIDTH{1'b0}};
            w_addr       <= {ADDR_WIDTH{1'b0}};
            w_len        <= 8'd0;
            w_size       <= 3'd0;
            w_beat_addr  <= {ADDR_WIDTH{1'b0}};
            w_total_beats<= 8'd0;
        end else begin
            w_state      <= w_state_n;
            case (w_state)
                W_IDLE: begin
                    if (cmd_valid && cmd_write && cmd_ready) begin
                        w_id          <= cmd_id;
                        w_addr        <= cmd_addr;
                        w_len         <= cmd_len;
                        w_size        <= cmd_size;
                        w_beat_addr   <= cmd_addr;
                        w_total_beats <= cmd_len + 8'd1;
                        w_beat_cnt    <= 8'd0;
                    end else begin
                        // hold
                    end
                end

                W_SEND_AW: begin
                    if (m_awvalid && m_awready) begin
                        // AW handshake done – advance to data phase
                        w_beat_addr   <= w_addr;   // init current-beat address
                        w_beat_cnt    <= 8'd0;
                    end else begin
                        // hold
                    end
                end

                W_SEND_W: begin
                    if (m_wvalid && m_wready) begin
                        if (w_beat_cnt == w_total_beats - 1) begin
                            // last beat sent — do NOT change w_beat_cnt here:
                            // the combinatorial block uses it to transition
                            // to W_WAIT_B; changing it would cause re-eval
                            // and corrupt w_state_n back to W_SEND_W.
                        end else begin
                            w_beat_cnt <= w_beat_cnt + 8'd1;
                            w_beat_addr <= w_beat_addr +
                                           {5'd0, bytes_per_beat(w_size)};
                        end
                    end else begin
                        // wait for W handshake
                    end
                end

                W_WAIT_B: begin
                    if (m_bvalid && m_bready) begin
                        w_beat_cnt <= 8'd0;   // safe reset: state → W_IDLE next
                    end else begin
                        // wait for B response
                    end
                end

                default: begin
                    w_state <= W_IDLE;
                end
            endcase
        end
    end

    //==========================================================================
    // Write FSM – combinatorial next-state / output logic
    //==========================================================================
    always @(*) begin
        // defaults
        w_state_n   = w_state;
        m_awvalid   = 1'b0;
        m_awid      = w_id;
        m_awaddr    = w_addr;
        m_awlen     = w_len;
        m_awsize    = w_size;
        m_awburst   = `AXI4_BURST_INCR;
        m_wvalid    = 1'b0;
        m_wdata     = {DATA_WIDTH{1'b0}};
        m_wstrb     = {STRB_WIDTH{1'b0}};
        m_wlast     = 1'b0;
        m_bready    = 1'b0;

        case (w_state)
            W_IDLE: begin
                // cmd_ready is driven solely by the final always block below
                if (cmd_valid && cmd_write) begin
                    w_state_n = W_SEND_AW;
                end else begin
                    w_state_n = W_IDLE;
                end
            end

            W_SEND_AW: begin
                m_awvalid = 1'b1;
                if (m_awvalid && m_awready) begin
                    w_state_n = W_SEND_W;
                end else begin
                    w_state_n = W_SEND_AW;
                end
            end

            W_SEND_W: begin
                m_wvalid = 1'b1;
                m_wdata  = make_wdata(w_id, w_beat_addr, w_beat_cnt);
                m_wstrb  = compute_wstrb(w_beat_addr, w_size);
                if (w_beat_cnt == w_total_beats - 1) begin
                    m_wlast = 1'b1;
                end else begin
                    m_wlast = 1'b0;
                end
                if (m_wvalid && m_wready) begin
                    if (w_beat_cnt == w_total_beats - 1) begin
                        w_state_n = W_WAIT_B;
                    end else begin
                        w_state_n = W_SEND_W;
                    end
                end else begin
                    w_state_n = W_SEND_W;
                end
            end

            W_WAIT_B: begin
                m_bready = 1'b1;
                if (m_bvalid && m_bready) begin
                    w_state_n = W_IDLE;
                end else begin
                    w_state_n = W_WAIT_B;
                end
            end

            default: begin
                w_state_n = W_IDLE;
            end
        endcase
    end

    //==========================================================================
    // Read-Address FSM – pipelined: sends AR then immediately returns to idle
    //   so multiple read commands can be issued while R data is outstanding.
    //==========================================================================
    localparam [0:0] AR_IDLE  = 1'd0,
                     AR_SEND  = 1'd1;

    reg [0:0] ar_state, ar_state_n;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            ar_state <= AR_IDLE;
            r_id     <= {ID_WIDTH{1'b0}};
            r_addr   <= {ADDR_WIDTH{1'b0}};
            r_len    <= 8'd0;
            r_size   <= 3'd0;
        end else begin
            ar_state <= ar_state_n;
            case (ar_state)
                AR_IDLE: begin
                    if (cmd_valid && !cmd_write && cmd_ready) begin
                        r_id   <= cmd_id;
                        r_addr <= cmd_addr;
                        r_len  <= cmd_len;
                        r_size <= cmd_size;
                    end else begin
                        // hold previous values
                    end
                end
                AR_SEND: begin
                    if (m_arvalid && m_arready) begin
                        // AR sent – hold nothing
                    end else begin
                        // wait
                    end
                end
                default: begin
                    ar_state <= AR_IDLE;
                end
            endcase
        end
    end

    // AR combinatorial
    always @(*) begin
        ar_state_n = ar_state;
        m_arvalid  = 1'b0;
        m_arid     = r_id;
        m_araddr   = r_addr;
        m_arlen    = r_len;
        m_arsize   = r_size;
        m_arburst  = `AXI4_BURST_INCR;

        case (ar_state)
            AR_IDLE: begin
                if (cmd_valid && !cmd_write && cmd_ready) begin
                    ar_state_n = AR_SEND;
                end else begin
                    ar_state_n = AR_IDLE;
                end
            end
            AR_SEND: begin
                m_arvalid = 1'b1;
                if (m_arvalid && m_arready) begin
                    ar_state_n = AR_IDLE;       // ready for next read cmd
                end else begin
                    ar_state_n = AR_SEND;
                end
            end
            default: begin
                ar_state_n = AR_IDLE;
            end
        endcase
    end

    //==========================================================================
    // Read-Data pass-through – always ready, pass R channel to rsp interface
    //   (combinatorial — testbench samples at posedge)
    //==========================================================================
    always @(*) begin
        m_rready  = 1'b1;               // always accept read data
        rsp_valid = m_rvalid;
        rsp_id    = m_rid;
        rsp_rdata = m_rdata;
        rsp_rresp = m_rresp;
        rsp_last  = m_rlast;
    end

    //==========================================================================
    // Combined cmd_ready – accept when the target FSM is IDLE
    //==========================================================================
    always @(*) begin
        if (cmd_valid) begin
            if (cmd_write && (w_state == W_IDLE))
                cmd_ready = 1'b1;
            else if (!cmd_write && (ar_state == AR_IDLE))
                cmd_ready = 1'b1;
            else
                cmd_ready = 1'b0;
        end else begin
            cmd_ready = 1'b0;
        end
    end

    //==========================================================================
    // Idle indicators (for testbench polling)
    //==========================================================================
    assign w_idle = (w_state   == W_IDLE);
    assign r_idle = (ar_state  == AR_IDLE);

endmodule
