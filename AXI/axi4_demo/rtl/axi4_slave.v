//==============================================================================
// AXI4 Slave Module (memory-backed, registered outputs)
//   - Internal 256 × 32-bit memory with per-byte write strobes
//   - Two independent read slots; centralised slot assignment avoids races
//   - Read-slot delay set by ARID[0]: even=fast (0 clk), odd=slow (8 clk)
//   - All always blocks are single-process (registered outputs) – synth safe
//==============================================================================
`include "axi4_defines.vh"

module axi4_slave #(
    parameter DATA_WIDTH = `AXI4_DATA_WIDTH,
    parameter ADDR_WIDTH = `AXI4_ADDR_WIDTH,
    parameter ID_WIDTH   = `AXI4_ID_WIDTH,
    parameter STRB_WIDTH = DATA_WIDTH / 8,
    parameter MEM_DEPTH  = 256,
    parameter FAST_DELAY = 0,
    parameter SLOW_DELAY = 8
) (
    input  wire                     aclk,
    input  wire                     aresetn,

    //----- Write Address Channel -----
    input  wire [ID_WIDTH-1:0]      s_awid,
    input  wire [ADDR_WIDTH-1:0]    s_awaddr,
    input  wire [ 7:0]              s_awlen,
    input  wire [ 2:0]              s_awsize,
    input  wire [ 1:0]              s_awburst,
    input  wire                     s_awvalid,
    output reg                      s_awready,

    //----- Write Data Channel -----
    input  wire [DATA_WIDTH-1:0]    s_wdata,
    input  wire [STRB_WIDTH-1:0]    s_wstrb,
    input  wire                     s_wlast,
    input  wire                     s_wvalid,
    output reg                      s_wready,

    //----- Write Response Channel -----
    output reg  [ID_WIDTH-1:0]      s_bid,
    output reg  [ 1:0]              s_bresp,
    output reg                      s_bvalid,
    input  wire                     s_bready,

    //----- Read Address Channel -----
    input  wire [ID_WIDTH-1:0]      s_arid,
    input  wire [ADDR_WIDTH-1:0]    s_araddr,
    input  wire [ 7:0]              s_arlen,
    input  wire [ 2:0]              s_arsize,
    input  wire [ 1:0]              s_arburst,
    input  wire                     s_arvalid,
    output reg                      s_arready,

    //----- Read Data Channel -----
    output reg  [ID_WIDTH-1:0]      s_rid,
    output reg  [DATA_WIDTH-1:0]    s_rdata,
    output reg  [ 1:0]              s_rresp,
    output reg                      s_rlast,
    output reg                      s_rvalid,
    input  wire                     s_rready
);

    //==========================================================================
    // Internal memory
    //==========================================================================
    reg [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

    //==========================================================================
    // Write-FSM states
    //==========================================================================
    localparam [1:0] WF_IDLE   = 2'd0,
                     WF_RECV_W = 2'd1,
                     WF_SEND_B = 2'd2;

    reg [1:0]            wf_state;
    reg [ID_WIDTH-1:0]   wf_id;
    reg [ADDR_WIDTH-1:0] wf_byte_addr;
    reg [7:0]            wf_beat_cnt;
    reg [7:0]            wf_total_beats;
    reg [2:0]            wf_size;

    //==========================================================================
    // Read-slot FSM states
    //==========================================================================
    localparam [1:0] RS_IDLE = 2'd0,
                     RS_WAIT = 2'd1,
                     RS_SEND = 2'd2;

    // Slot 0
    reg [1:0]             rs0_state;
    reg                   rs0_active;       // 1 = slot owns a transaction
    reg [ID_WIDTH-1:0]   rs0_id;
    reg [ADDR_WIDTH-1:0] rs0_byte_addr;
    reg [7:0]            rs0_len;           // remaining beats (0 = last)
    reg [2:0]            rs0_size;
    reg [7:0]            rs0_delay_cnt;
    reg [7:0]            rs0_beat_cnt;

    // Slot 1
    reg [1:0]             rs1_state;
    reg                   rs1_active;
    reg [ID_WIDTH-1:0]   rs1_id;
    reg [ADDR_WIDTH-1:0] rs1_byte_addr;
    reg [7:0]            rs1_len;
    reg [2:0]            rs1_size;
    reg [7:0]            rs1_delay_cnt;
    reg [7:0]            rs1_beat_cnt;

    // R-channel arbiter
    reg        r_arb_sel;            // 0 → slot0 drives R bus

    // Slot-assignment wires (centralised, computed before the clock edge)
    wire ar_goes_to_slot0;
    wire ar_goes_to_slot1;

    //==========================================================================
    // Central AR-accept decision + slot-priority encoder (combinational)
    //   s_arready = 1  whenever any slot can take a new request.
    //   Slot 0 has priority.
    //==========================================================================
    assign ar_goes_to_slot0 = s_arvalid && s_arready &&
                              !rs0_active && (rs0_state == RS_IDLE);
    assign ar_goes_to_slot1 = s_arvalid && s_arready &&
                              !ar_goes_to_slot0 &&
                              !rs1_active && (rs1_state == RS_IDLE);

    always @(*) begin
        if ((!rs0_active && rs0_state == RS_IDLE) ||
            (!rs1_active && rs1_state == RS_IDLE))
            s_arready = 1'b1;
        else
            s_arready = 1'b0;
    end

    //==========================================================================
    // helper: bytes_per_beat
    //==========================================================================
    function [7:0] bytes_per_beat;
        input [2:0] sz;
        case (sz)
            3'd0:    bytes_per_beat = 8'd1;
            3'd1:    bytes_per_beat = 8'd2;
            3'd2:    bytes_per_beat = 8'd4;
            3'd3:    bytes_per_beat = 8'd8;
            default: bytes_per_beat = 8'd4;
        endcase
    endfunction

    //==========================================================================
    // Write FSM – single always block (registered outputs)
    //==========================================================================
    integer wb;   // byte-lane loop variable
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            wf_state      <= WF_IDLE;
            s_awready     <= 1'b0;
            s_wready      <= 1'b0;
            s_bvalid      <= 1'b0;
            s_bid         <= {ID_WIDTH{1'b0}};
            s_bresp       <= `AXI4_RESP_OKAY;
            wf_id         <= {ID_WIDTH{1'b0}};
            wf_byte_addr  <= {ADDR_WIDTH{1'b0}};
            wf_beat_cnt   <= 8'd0;
            wf_total_beats<= 8'd0;
            wf_size       <= 3'd0;
        end else begin
            // ----- registered defaults -----
            s_awready  <= 1'b0;
            s_wready   <= 1'b0;
            s_bvalid   <= 1'b0;
            s_bid      <= wf_id;
            s_bresp    <= `AXI4_RESP_OKAY;

            case (wf_state)
                //------------------------------------------------------------------
                WF_IDLE: begin
                    s_awready <= 1'b1;
                    if (s_awvalid && s_awready) begin
                        wf_id          <= s_awid;
                        wf_byte_addr   <= s_awaddr;
                        wf_total_beats <= s_awlen + 8'd1;
                        wf_beat_cnt    <= 8'd0;
                        wf_size        <= s_awsize;
                        wf_state       <= WF_RECV_W;
                    end else begin
                        wf_state <= WF_IDLE;
                    end
                end

                //------------------------------------------------------------------
                WF_RECV_W: begin
                    s_wready <= 1'b1;
                    if (s_wvalid && s_wready) begin
                        // Memory write with byte strobes
                        for (wb = 0; wb < STRB_WIDTH; wb = wb + 1) begin
                            if (s_wstrb[wb]) begin
                                mem[wf_byte_addr[ADDR_WIDTH-1:2]][wb*8 +: 8]
                                    <= s_wdata[wb*8 +: 8];
                            end else begin
                                // byte lane not strobed — retain current value
                            end
                        end
                        if (wf_beat_cnt == wf_total_beats - 1) begin
                            wf_state <= WF_SEND_B;
                        end else begin
                            wf_beat_cnt  <= wf_beat_cnt + 8'd1;
                            wf_byte_addr <= wf_byte_addr +
                                            {5'd0, bytes_per_beat(wf_size)};
                            wf_state     <= WF_RECV_W;
                        end
                    end else begin
                        wf_state <= WF_RECV_W;
                    end
                end

                //------------------------------------------------------------------
                WF_SEND_B: begin
                    s_bvalid <= 1'b1;
                    if (s_bvalid && s_bready) begin
                        wf_state <= WF_IDLE;
                    end else begin
                        wf_state <= WF_SEND_B;
                    end
                end

                //------------------------------------------------------------------
                default: begin
                    wf_state <= WF_IDLE;
                end
            endcase
        end
    end

    //==========================================================================
    // Read Slot 0 – single always block (registered outputs)
    //==========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            rs0_state     <= RS_IDLE;
            rs0_active    <= 1'b0;
            rs0_id        <= {ID_WIDTH{1'b0}};
            rs0_byte_addr <= {ADDR_WIDTH{1'b0}};
            rs0_len       <= 8'd0;
            rs0_size      <= 3'd0;
            rs0_delay_cnt <= 8'd0;
            rs0_beat_cnt  <= 8'd0;
        end else begin
            case (rs0_state)
                //------------------------------------------------------------------
                RS_IDLE: begin
                    if (ar_goes_to_slot0) begin
                        rs0_id        <= s_arid;
                        rs0_byte_addr <= s_araddr;
                        rs0_len       <= s_arlen;        // AXI len = beats-1
                        rs0_size      <= s_arsize;
                        rs0_beat_cnt  <= 8'd0;
                        rs0_active    <= 1'b1;
                        // delay based on ID LSB
                        if (s_arid[0] == 1'b1) begin
                            rs0_delay_cnt <= SLOW_DELAY[7:0];
                        end else begin
                            rs0_delay_cnt <= FAST_DELAY[7:0];
                        end
                        // Next-state decision
                        if ((s_arid[0] == 1'b1) && (SLOW_DELAY > 0))
                            rs0_state <= RS_WAIT;
                        else if ((s_arid[0] == 1'b0) && (FAST_DELAY > 0))
                            rs0_state <= RS_WAIT;
                        else
                            rs0_state <= RS_SEND;
                    end else begin
                        rs0_state  <= RS_IDLE;
                        rs0_active <= rs0_active;  // hold
                    end
                end

                //------------------------------------------------------------------
                RS_WAIT: begin
                    if (rs0_delay_cnt > 0) begin
                        rs0_delay_cnt <= rs0_delay_cnt - 8'd1;
                        rs0_state     <= RS_WAIT;
                    end else begin
                        rs0_state <= RS_SEND;
                    end
                end

                //------------------------------------------------------------------
                RS_SEND: begin
                    // Handshake when this slot is selected by arbiter
                    if (s_rvalid && s_rready && (r_arb_sel == 1'b0)) begin
                        if (rs0_len == 8'd0) begin
                            // Last beat completed
                            rs0_active <= 1'b0;
                            rs0_state  <= RS_IDLE;
                        end else begin
                            rs0_len       <= rs0_len - 8'd1;
                            rs0_beat_cnt  <= rs0_beat_cnt + 8'd1;
                            rs0_byte_addr <= rs0_byte_addr +
                                             {5'd0, bytes_per_beat(rs0_size)};
                            rs0_state     <= RS_SEND;
                        end
                    end else begin
                        rs0_state <= RS_SEND;
                    end
                end

                //------------------------------------------------------------------
                default: begin
                    rs0_state  <= RS_IDLE;
                    rs0_active <= 1'b0;
                end
            endcase
        end
    end

    //==========================================================================
    // Read Slot 1 – single always block (registered outputs)
    //==========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            rs1_state     <= RS_IDLE;
            rs1_active    <= 1'b0;
            rs1_id        <= {ID_WIDTH{1'b0}};
            rs1_byte_addr <= {ADDR_WIDTH{1'b0}};
            rs1_len       <= 8'd0;
            rs1_size      <= 3'd0;
            rs1_delay_cnt <= 8'd0;
            rs1_beat_cnt  <= 8'd0;
        end else begin
            case (rs1_state)
                //------------------------------------------------------------------
                RS_IDLE: begin
                    if (ar_goes_to_slot1) begin
                        rs1_id        <= s_arid;
                        rs1_byte_addr <= s_araddr;
                        rs1_len       <= s_arlen;
                        rs1_size      <= s_arsize;
                        rs1_beat_cnt  <= 8'd0;
                        rs1_active    <= 1'b1;
                        if (s_arid[0] == 1'b1) begin
                            rs1_delay_cnt <= SLOW_DELAY[7:0];
                        end else begin
                            rs1_delay_cnt <= FAST_DELAY[7:0];
                        end
                        if ((s_arid[0] == 1'b1) && (SLOW_DELAY > 0))
                            rs1_state <= RS_WAIT;
                        else if ((s_arid[0] == 1'b0) && (FAST_DELAY > 0))
                            rs1_state <= RS_WAIT;
                        else
                            rs1_state <= RS_SEND;
                    end else begin
                        rs1_state  <= RS_IDLE;
                        rs1_active <= rs1_active;
                    end
                end

                //------------------------------------------------------------------
                RS_WAIT: begin
                    if (rs1_delay_cnt > 0) begin
                        rs1_delay_cnt <= rs1_delay_cnt - 8'd1;
                        rs1_state     <= RS_WAIT;
                    end else begin
                        rs1_state <= RS_SEND;
                    end
                end

                //------------------------------------------------------------------
                RS_SEND: begin
                    if (s_rvalid && s_rready && (r_arb_sel == 1'b1)) begin
                        if (rs1_len == 8'd0) begin
                            rs1_active <= 1'b0;
                            rs1_state  <= RS_IDLE;
                        end else begin
                            rs1_len       <= rs1_len - 8'd1;
                            rs1_beat_cnt  <= rs1_beat_cnt + 8'd1;
                            rs1_byte_addr <= rs1_byte_addr +
                                             {5'd0, bytes_per_beat(rs1_size)};
                            rs1_state     <= RS_SEND;
                        end
                    end else begin
                        rs1_state <= RS_SEND;
                    end
                end

                //------------------------------------------------------------------
                default: begin
                    rs1_state  <= RS_IDLE;
                    rs1_active <= 1'b0;
                end
            endcase
        end
    end

    //==========================================================================
    // R-channel arbiter – registered toggle
    //==========================================================================
    wire rs0_wants;   // slot 0 ready to send data
    wire rs1_wants;

    assign rs0_wants = rs0_active && (rs0_state == RS_SEND);
    assign rs1_wants = rs1_active && (rs1_state == RS_SEND);

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            r_arb_sel <= 1'b0;
        end else begin
            if (s_rvalid && s_rready) begin
                // Current transfer finished → re-arbitrate
                if (rs0_wants && rs1_wants)
                    r_arb_sel <= ~r_arb_sel;      // round-robin toggle
                else if (rs0_wants)
                    r_arb_sel <= 1'b0;
                else if (rs1_wants)
                    r_arb_sel <= 1'b1;
                else
                    r_arb_sel <= r_arb_sel;
            end else if (!s_rvalid) begin
                // Bus idle → pick whoever wants it
                if (rs0_wants && rs1_wants)
                    r_arb_sel <= ~r_arb_sel;
                else if (rs0_wants)
                    r_arb_sel <= 1'b0;
                else if (rs1_wants)
                    r_arb_sel <= 1'b1;
                else
                    r_arb_sel <= r_arb_sel;
            end else begin
                r_arb_sel <= r_arb_sel;           // mid-burst, hold
            end
        end
    end

    //==========================================================================
    // R-channel output – registered multiplexer
    //==========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_rvalid <= 1'b0;
            s_rid    <= {ID_WIDTH{1'b0}};
            s_rdata  <= {DATA_WIDTH{1'b0}};
            s_rresp  <= `AXI4_RESP_OKAY;
            s_rlast  <= 1'b0;
        end else begin
            if (r_arb_sel == 1'b0) begin
                if (rs0_wants) begin
                    s_rvalid <= 1'b1;
                    s_rid    <= rs0_id;
                    s_rdata  <= mem[rs0_byte_addr[ADDR_WIDTH-1:2]];
                    s_rresp  <= `AXI4_RESP_OKAY;
                    s_rlast  <= (rs0_len == 8'd0);
                end else begin
                    s_rvalid <= 1'b0;
                    s_rid    <= {ID_WIDTH{1'b0}};
                    s_rdata  <= {DATA_WIDTH{1'b0}};
                    s_rresp  <= `AXI4_RESP_OKAY;
                    s_rlast  <= 1'b0;
                end
            end else begin
                if (rs1_wants) begin
                    s_rvalid <= 1'b1;
                    s_rid    <= rs1_id;
                    s_rdata  <= mem[rs1_byte_addr[ADDR_WIDTH-1:2]];
                    s_rresp  <= `AXI4_RESP_OKAY;
                    s_rlast  <= (rs1_len == 8'd0);
                end else begin
                    s_rvalid <= 1'b0;
                    s_rid    <= {ID_WIDTH{1'b0}};
                    s_rdata  <= {DATA_WIDTH{1'b0}};
                    s_rresp  <= `AXI4_RESP_OKAY;
                    s_rlast  <= 1'b0;
                end
            end
        end
    end

endmodule
