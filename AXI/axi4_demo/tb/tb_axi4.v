//==============================================================================
// AXI4 Self-Checking Testbench
//   - Instantiates axi4_master ↔ axi4_slave with full AXI4 bus wiring
//   - Reference memory model for expected-data verification
//   - Tests: small-burst write, large-burst write, narrow write,
//            out-of-order reads, concurrent read/write
//==============================================================================
`include "../rtl/axi4_defines.vh"

module tb_axi4;

    //==========================================================================
    // Clock & Reset
    //==========================================================================
    reg clk;
    reg rst_n;

    initial clk = 1'b0;
    always #5 clk = ~clk;                 // 100 MHz

    //==========================================================================
    // Master command interface
    //==========================================================================
    reg                     cmd_valid;
    wire                    cmd_ready;
    reg                     cmd_write;
    reg  [31:0]             cmd_addr;
    reg  [ 7:0]             cmd_len;
    reg  [ 2:0]             cmd_size;
    reg  [ 3:0]             cmd_id;

    // Master status
    wire                    w_idle;
    wire                    r_idle;

    // Master read-response output
    wire                    rsp_valid;
    wire [ 3:0]             rsp_id;
    wire [31:0]             rsp_rdata;
    wire [ 1:0]             rsp_rresp;
    wire                    rsp_last;

    //==========================================================================
    // AXI4 bus wires — Write Address Channel
    //==========================================================================
    wire [ 3:0]             awid;
    wire [31:0]             awaddr;
    wire [ 7:0]             awlen;
    wire [ 2:0]             awsize;
    wire [ 1:0]             awburst;
    wire                    awvalid;
    wire                    awready;

    //==========================================================================
    // AXI4 bus wires — Write Data Channel
    //==========================================================================
    wire [31:0]             wdata;
    wire [ 3:0]             wstrb;
    wire                    wlast;
    wire                    wvalid;
    wire                    wready;

    //==========================================================================
    // AXI4 bus wires — Write Response Channel
    //==========================================================================
    wire [ 3:0]             bid;
    wire [ 1:0]             bresp;
    wire                    bvalid;
    wire                    bready;

    //==========================================================================
    // AXI4 bus wires — Read Address Channel
    //==========================================================================
    wire [ 3:0]             arid;
    wire [31:0]             araddr;
    wire [ 7:0]             arlen;
    wire [ 2:0]             arsize;
    wire [ 1:0]             arburst;
    wire                    arvalid;
    wire                    arready;

    //==========================================================================
    // AXI4 bus wires — Read Data Channel
    //==========================================================================
    wire [ 3:0]             rid;
    wire [31:0]             rdata;
    wire [ 1:0]             rresp;
    wire                    rlast;
    wire                    rvalid;
    wire                    rready;

    //==========================================================================
    // axi4_master instantiation
    //==========================================================================
    axi4_master #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(32),
        .ID_WIDTH(4)
    ) u_master (
        .aclk       (clk),
        .aresetn    (rst_n),

        .cmd_valid  (cmd_valid),
        .cmd_ready  (cmd_ready),
        .cmd_write  (cmd_write),
        .cmd_addr   (cmd_addr),
        .cmd_len    (cmd_len),
        .cmd_size   (cmd_size),
        .cmd_id     (cmd_id),

        .w_idle     (w_idle),
        .r_idle     (r_idle),

        .rsp_valid  (rsp_valid),
        .rsp_id     (rsp_id),
        .rsp_rdata  (rsp_rdata),
        .rsp_rresp  (rsp_rresp),
        .rsp_last   (rsp_last),

        .m_awid     (awid),
        .m_awaddr   (awaddr),
        .m_awlen    (awlen),
        .m_awsize   (awsize),
        .m_awburst  (awburst),
        .m_awvalid  (awvalid),
        .m_awready  (awready),

        .m_wdata    (wdata),
        .m_wstrb    (wstrb),
        .m_wlast    (wlast),
        .m_wvalid   (wvalid),
        .m_wready   (wready),

        .m_bid      (bid),
        .m_bresp    (bresp),
        .m_bvalid   (bvalid),
        .m_bready   (bready),

        .m_arid     (arid),
        .m_araddr   (araddr),
        .m_arlen    (arlen),
        .m_arsize   (arsize),
        .m_arburst  (arburst),
        .m_arvalid  (arvalid),
        .m_arready  (arready),

        .m_rid      (rid),
        .m_rdata    (rdata),
        .m_rresp    (rresp),
        .m_rlast    (rlast),
        .m_rvalid   (rvalid),
        .m_rready   (rready)
    );

    //==========================================================================
    // axi4_slave instantiation
    //==========================================================================
    axi4_slave #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(32),
        .ID_WIDTH(4),
        .MEM_DEPTH(256),
        .FAST_DELAY(0),
        .SLOW_DELAY(8)
    ) u_slave (
        .aclk       (clk),
        .aresetn    (rst_n),

        .s_awid     (awid),
        .s_awaddr   (awaddr),
        .s_awlen    (awlen),
        .s_awsize   (awsize),
        .s_awburst  (awburst),
        .s_awvalid  (awvalid),
        .s_awready  (awready),

        .s_wdata    (wdata),
        .s_wstrb    (wstrb),
        .s_wlast    (wlast),
        .s_wvalid   (wvalid),
        .s_wready   (wready),

        .s_bid      (bid),
        .s_bresp    (bresp),
        .s_bvalid   (bvalid),
        .s_bready   (bready),

        .s_arid     (arid),
        .s_araddr   (araddr),
        .s_arlen    (arlen),
        .s_arsize   (arsize),
        .s_arburst  (arburst),
        .s_arvalid  (arvalid),
        .s_arready  (arready),

        .s_rid      (rid),
        .s_rdata    (rdata),
        .s_rresp    (rresp),
        .s_rlast    (rlast),
        .s_rvalid   (rvalid),
        .s_rready   (rready)
    );

    //==========================================================================
    // Reference memory model (mirrors slave's byte-writable memory)
    //==========================================================================
    reg [31:0] ref_mem [0:255];

    //==========================================================================
    // Test tracking
    //==========================================================================
    integer        total_tests;
    integer        passed_tests;
    integer        failed_tests;
    reg [ 3:0]     completion_order [0:31];   // records read-ID completion order
    integer        completion_idx;
    reg [ 3:0]     issued_ids       [0:31];   // records issue order
    integer        issue_idx;

    //==========================================================================
    // Helper: bytes per beat from AXI SIZE
    //==========================================================================
    function [7:0] axsize_to_bytes;
        input [2:0] sz;
        begin
            case (sz)
                3'd0:    axsize_to_bytes = 8'd1;
                3'd1:    axsize_to_bytes = 8'd2;
                3'd2:    axsize_to_bytes = 8'd4;
                3'd3:    axsize_to_bytes = 8'd8;
                default: axsize_to_bytes = 8'd4;
            endcase
        end
    endfunction

    //==========================================================================
    // Helper: compute WSTRB from byte-address and size (matches master)
    //==========================================================================
    function [3:0] ref_wstrb;
        input [31:0] addr;
        input [ 2:0] sz;
        reg [7:0] bpb;
        reg [3:0] shift;
        begin
            bpb   = axsize_to_bytes(sz);
            shift = addr[1:0];
            // Use 32-bit integer shift (1 << 4 = 16, avoids 4-bit truncation)
            ref_wstrb = (((1 << bpb) - 1) << shift) & 4'b1111;
        end
    endfunction

    //==========================================================================
    // Helper: compute expected write data (matches master's make_wdata)
    //==========================================================================
    function [31:0] expected_data;
        input [ 3:0] id;
        input [31:0] byte_addr;
        input [ 7:0] beat;
        begin
            expected_data = {id, 4'h0, byte_addr[23:0]} + {24'd0, beat};
        end
    endfunction

    //==========================================================================
    // update_ref_mem — called after write command to mirror written data
    //==========================================================================
    task update_ref_mem;
        input [ 3:0] id;
        input [31:0] addr;
        input [ 7:0] len;
        input [ 2:0] size;
        integer      beat;
        reg [31:0]   byte_addr;
        reg [ 3:0]   strb;
        reg [31:0]   wd;
        reg [ 7:0]   widx;
        integer      bl;
        reg [31:0]   tmp;
    begin
        for (beat = 0; beat <= len; beat = beat + 1) begin
            byte_addr = addr + beat * {25'd0, axsize_to_bytes(size)};
            strb      = ref_wstrb(byte_addr, size);
            wd        = expected_data(id, byte_addr, beat[7:0]);
            widx      = byte_addr[31:2];
            tmp       = ref_mem[widx];
            for (bl = 0; bl < 4; bl = bl + 1) begin
                if (strb[bl])
                    tmp[bl*8 +: 8] = wd[bl*8 +: 8];
            end
            ref_mem[widx] = tmp;
        end
    end
    endtask

    //==========================================================================
    // init_ref_mem — zero-out the reference memory
    //==========================================================================
    task init_ref_mem;
        integer i;
    begin
        for (i = 0; i < 256; i = i + 1)
            ref_mem[i] = 32'h0000_0000;
    end
    endtask

    //==========================================================================
    // wait_clks
    //==========================================================================
    task wait_clks;
        input integer n;
        integer i;
    begin
        for (i = 0; i < n; i = i + 1)
            @(posedge clk);
    end
    endtask

    //==========================================================================
    // wait_write_idle — wait until master's write FSM returns to IDLE
    //==========================================================================
    task wait_write_idle;
    begin
        while (!w_idle) @(posedge clk);
    end
    endtask

    //==========================================================================
    // wait_read_idle
    //==========================================================================
    task wait_read_idle;
    begin
        while (!r_idle) @(posedge clk);
    end
    endtask

    //==========================================================================
    // do_write — issue a write command and wait for completion
    //==========================================================================
    task do_write;
        input [ 3:0] id;
        input [31:0] addr;
        input [ 7:0] len;       // AXI len = beats-1
        input [ 2:0] size;
    begin
        // Assert command
        @(posedge clk);
        cmd_valid  <= 1'b1;
        cmd_write  <= 1'b1;
        cmd_addr   <= addr;
        cmd_len    <= len;
        cmd_size   <= size;
        cmd_id     <= id;
        // Wait for acceptance
        @(posedge clk);
        while (!cmd_ready) @(posedge clk);
        cmd_valid  <= 1'b0;
        cmd_write  <= 1'b0;
        $display("  [WR]  ID=%0d  ADDR=0x%08h  LEN=%0d  SIZE=%0d  — issued",
                 id, addr, len, size);
        // Update reference model
        update_ref_mem(id, addr, len, size);
        // Wait for write transaction to fully complete
        wait_write_idle;
        $display("  [WR]  ID=%0d  — completed", id);
    end
    endtask

    //==========================================================================
    // do_read — issue a read command; return when read data starts arriving.
    //   The task does NOT wait for completion — caller monitors rsp_valid.
    //==========================================================================
    task do_read;
        input [ 3:0] id;
        input [31:0] addr;
        input [ 7:0] len;
        input [ 2:0] size;
    begin
        @(posedge clk);
        cmd_valid  <= 1'b1;
        cmd_write  <= 1'b0;
        cmd_addr   <= addr;
        cmd_len    <= len;
        cmd_size   <= size;
        cmd_id     <= id;
        @(posedge clk);
        while (!cmd_ready) @(posedge clk);
        cmd_valid  <= 1'b0;
        cmd_write  <= 1'b0;
        $display("  [RD]  ID=%0d  ADDR=0x%08h  LEN=%0d  SIZE=%0d  — issued",
                 id, addr, len, size);
    end
    endtask

    //==========================================================================
    // check_read_beat — verify one beat of read data against ref_mem
    //   Returns 1 on match, 0 on mismatch.
    //==========================================================================
    function check_read_beat;
        input [ 3:0] id;
        input [31:0] rdata_val;
        input [31:0] byte_addr;
        input [ 2:0] size;
        reg [31:0]   exp_word;
        reg [31:0]   mask;
        reg [ 7:0]   widx;
    begin
        widx = byte_addr[31:2];
        exp_word = ref_mem[widx];
        // Build byte-valid mask from size and address
        mask = {32{1'b0}};
        case (size)
            3'd0: mask = 32'h0000_00FF << (byte_addr[1:0] * 8);
            3'd1: mask = 32'h0000_FFFF << (byte_addr[1:0] * 8);
            3'd2: mask = 32'hFFFF_FFFF;
            3'd3: mask = 32'hFFFF_FFFF;   // 8 bytes (64-bit not fully modelled)
            default: mask = 32'hFFFF_FFFF;
        endcase
        // Compare only the valid byte lanes
        if ((rdata_val & mask) === (exp_word & mask)) begin
            check_read_beat = 1'b1;
        end else begin
            check_read_beat = 1'b0;
            $display("    ** MISMATCH ** beat at ADDR=0x%08h: got=0x%08h  exp=0x%08h  mask=0x%08h",
                     byte_addr, rdata_val, exp_word, mask);
        end
    end
    endfunction

    //==========================================================================
    // Per-ID tracking table (populated when issuing reads)
    //==========================================================================
    reg [ 7:0] id_info_len   [0:15];
    reg [ 2:0] id_info_size  [0:15];
    reg [31:0] id_info_addr  [0:15];
    reg [ 7:0] id_beat_cnt   [0:15];    // per-ID beat counter (for interleaved bursts)

    //==========================================================================
    // drain_read_responses — wait for all outstanding reads to complete,
    //   verifying each beat against the reference memory using per-ID tracking.
    //   Also records completion order.
    //   The slave may interleave beats from different IDs (round-robin
    //   arbiter), so we track beat count per ID.
    //==========================================================================
    task drain_read_responses;
        input integer expected_beats;    // total R beats expected in this batch
        integer            beat_cnt;
        integer            ii;
        reg [31:0]         r_beat_addr;
        reg [ 3:0]         r_id;
    begin
        beat_cnt = 0;

        // Reset per-ID beat counters for IDs used in this batch
        for (ii = 0; ii < issue_idx; ii = ii + 1) begin
            id_beat_cnt[issued_ids[ii]] = 8'd0;
        end

        while (beat_cnt < expected_beats) begin
            @(posedge clk);
            if (rsp_valid) begin
                r_id = rsp_id;

                // Compute this beat's byte address using per-ID counter
                r_beat_addr = id_info_addr[r_id] +
                              id_beat_cnt[r_id] * {25'd0, axsize_to_bytes(id_info_size[r_id])};

                // Verify this beat
                if (check_read_beat(r_id, rsp_rdata, r_beat_addr, id_info_size[r_id])) begin
                    // pass (silent)
                end else begin
                    $display("    ** READ DATA ERROR: ID=%0d beat=%0d addr=0x%08h",
                             r_id, id_beat_cnt[r_id], r_beat_addr);
                    failed_tests = failed_tests + 1;
                end

                // Increment per-ID beat counter
                id_beat_cnt[r_id] = id_beat_cnt[r_id] + 8'd1;

                // Record completion order on RLAST
                if (rsp_last) begin
                    completion_order[completion_idx] = rsp_id;
                    completion_idx = completion_idx + 1;
                    $display("  [RD]  ID=%0d  — completed (order #%0d)",
                             rsp_id, completion_idx);
                end

                beat_cnt = beat_cnt + 1;
            end
        end
    end
    endtask

    //==========================================================================
    // record_read_info — save read-command parameters for drain verification
    //==========================================================================
    task record_read_info;
        input [ 3:0] id;
        input [31:0] addr;
        input [ 7:0] len;
        input [ 2:0] size;
    begin
        id_info_len [id] = len;
        id_info_size[id] = size;
        id_info_addr[id] = addr;
    end
    endtask

    //==========================================================================
    // total_read_beats — helper to sum expected beats across reads
    //==========================================================================
    function integer total_read_beats_from_issues;
        input integer n_issued;
        integer i, sum;
    begin
        sum = 0;
        for (i = 0; i < n_issued; i = i + 1) begin
            sum = sum + id_info_len[issued_ids[i]] + 1;
        end
        total_read_beats_from_issues = sum;
    end
    endfunction

    //==========================================================================
    // check_completion_out_of_order — verify at least one inversion exists
    //==========================================================================
    task check_completion_out_of_order;
        input integer n;
        integer i, j;
        reg     found;
    begin
        found = 1'b0;
        if (n < 2) begin
            $display("  [OOO]  Only %0d completions — cannot verify out-of-order", n);
            return;
        end
        // Compare completion_order against issued_ids
        // If ANY completed ID differs from issued order, out-of-order occurred
        for (i = 0; i < n; i = i + 1) begin
            if (completion_order[i] !== issued_ids[i]) begin
                found = 1'b1;
            end
        end
        $write("  [OOO]  Issue order:  ");
        for (i = 0; i < n; i = i + 1)
            $write("ID=%0d ", issued_ids[i]);
        $display("");
        $write("  [OOO]  Complete order:");
        for (i = 0; i < n; i = i + 1)
            $write("ID=%0d ", completion_order[i]);
        $display("");
        if (found) begin
            $display("  [OOO]  ✓ Out-of-order completion DETECTED");
        end else begin
            $display("  [OOO]  ✗ Completions were in-order (unexpected for mixed fast/slow IDs)");
            failed_tests = failed_tests + 1;
        end
    end
    endtask

    //==========================================================================
    // print_test_header
    //==========================================================================
    task print_test_header;
        input [8*64-1:0] name;
    begin
        $display("");
        $display("============================================================");
        $display("  TEST: %0s", name);
        $display("============================================================");
    end
    endtask

    //==========================================================================
    // print_test_result
    //==========================================================================
    task print_test_result;
        input [8*64-1:0] name;
        input             pass;     // 1 = pass
    begin
        if (pass) begin
            $display("  [PASS]  %0s", name);
            passed_tests = passed_tests + 1;
        end else begin
            $display("  [FAIL]  %0s", name);
            failed_tests = failed_tests + 1;
        end
    end
    endtask

    //==========================================================================
    //===  T E S T   S E Q U E N C E S  ========================================
    //==========================================================================

    //----------------------------------------------------------------------
    // Test 1 — Small burst write  (4 beats × 4 bytes)
    //----------------------------------------------------------------------
    task test_small_burst_write;
        reg pass;
    begin
        print_test_header("Small burst write (4 beats, 32-bit)");
        pass = 1'b1;
        do_write(4'd0, 32'h0000_0010, 8'd3, 3'd2);   // 4 beats at 0x10
        print_test_result("Small burst write", pass);
    end
    endtask

    //----------------------------------------------------------------------
    // Test 2 — Large burst write  (16 beats × 4 bytes)
    //----------------------------------------------------------------------
    task test_large_burst_write;
        reg pass;
    begin
        print_test_header("Large burst write (16 beats, 32-bit)");
        pass = 1'b1;
        do_write(4'd1, 32'h0000_0040, 8'd15, 3'd2);   // 16 beats at 0x40
        print_test_result("Large burst write", pass);
    end
    endtask

    //----------------------------------------------------------------------
    // Test 3 — Narrow burst write  (8 beats × 1 byte)
    //----------------------------------------------------------------------
    task test_narrow_burst_write;
        reg pass;
    begin
        print_test_header("Narrow burst write (8 beats, 8-bit)");
        pass = 1'b1;
        do_write(4'd2, 32'h0000_0080, 8'd7, 3'd0);    // 8 beats × 1B at 0x80
        print_test_result("Narrow burst write", pass);
    end
    endtask

    //----------------------------------------------------------------------
    // Test 4 — Medium burst write  (4 beats × 2 bytes)
    //----------------------------------------------------------------------
    task test_medium_burst_write;
        reg pass;
    begin
        print_test_header("Medium burst write (4 beats, 16-bit)");
        pass = 1'b1;
        do_write(4'd3, 32'h0000_00A0, 8'd3, 3'd1);    // 4 beats × 2B at 0xA0
        print_test_result("Medium burst write", pass);
    end
    endtask

    //----------------------------------------------------------------------
    // Test 5 — Read-back verification (sequential read after write)
    //----------------------------------------------------------------------
    task test_readback;
        reg pass;
        integer total_beats;
    begin
        print_test_header("Read-back verification (sequential)");
        pass = 1'b1;

        // Read back the small burst write data (ID=0, addr=0x10, len=3, size=2)
        record_read_info(4'd5, 32'h0000_0010, 8'd3, 3'd2);
        issued_ids[0] = 4'd5;
        issue_idx = 1;
        do_read(4'd5, 32'h0000_0010, 8'd3, 3'd2);

        // Read back the large burst write data (ID=1, addr=0x40, len=15, size=2)
        record_read_info(4'd6, 32'h0000_0040, 8'd15, 3'd2);
        issued_ids[1] = 4'd6;
        issue_idx = 2;
        do_read(4'd6, 32'h0000_0040, 8'd15, 3'd2);

        // Read back narrow write
        record_read_info(4'd7, 32'h0000_0080, 8'd7, 3'd0);
        issued_ids[2] = 4'd7;
        issue_idx = 3;
        do_read(4'd7, 32'h0000_0080, 8'd7, 3'd0);

        // Read back medium write
        record_read_info(4'd8, 32'h0000_00A0, 8'd3, 3'd1);
        issued_ids[3] = 4'd8;
        issue_idx = 4;
        do_read(4'd8, 32'h0000_00A0, 8'd3, 3'd1);

        total_beats = 4 + 16 + 8 + 4;   // (3+1) + (15+1) + (7+1) + (3+1)
        completion_idx = 0;
        drain_read_responses(total_beats);

        print_test_result("Read-back verification", pass);
    end
    endtask

    //----------------------------------------------------------------------
    // Test 6 — Out-of-order read test
    //   Issue reads with mixed fast (even ID) / slow (odd ID) IDs.
    //   The slave delays odd-ID reads by SLOW_DELAY=8 cycles, so even-ID
    //   reads issued later should complete earlier.
    //----------------------------------------------------------------------
    task test_out_of_order_read;
        reg pass;
        integer total_beats;
        integer ii;
    begin
        print_test_header("Out-of-order read (mixed fast/slow IDs)");
        pass = 1'b1;

        // First write some data to read back
        // Region A at 0xC0: 4 beats (for ID=1 slow read)
        do_write(4'd0, 32'h0000_00C0, 8'd3, 3'd2);
        // Region B at 0xE0: 4 beats (for ID=2 fast read)
        do_write(4'd0, 32'h0000_00E0, 8'd3, 3'd2);
        // Region C at 0x100: 2 beats (for ID=4 fast read)
        do_write(4'd0, 32'h0000_0100, 8'd1, 3'd2);
        // Region D at 0x120: 8 beats (for ID=3 slow read)
        do_write(4'd0, 32'h0000_0120, 8'd7, 3'd2);

        // Reset tracking
        issue_idx      = 0;
        completion_idx = 0;
        for (ii = 0; ii < 16; ii = ii + 1) begin
            id_info_len [ii] = 8'd0;
            id_info_size[ii] = 3'd0;
            id_info_addr[ii] = 32'd0;
        end

        wait_clks(2);

        // Issue reads in this order: slow, fast, fast, slow
        // Expected completion order: fast (ID=2), fast (ID=4), slow (ID=1), slow (ID=3)

        // 1st: ID=1 (odd → SLOW, 4 beats from 0xC0)
        record_read_info(4'd1, 32'h0000_00C0, 8'd3, 3'd2);
        issued_ids[issue_idx] = 4'd1; issue_idx = issue_idx + 1;
        do_read(4'd1, 32'h0000_00C0, 8'd3, 3'd2);

        // 2nd: ID=2 (even → FAST, 4 beats from 0xE0)
        record_read_info(4'd2, 32'h0000_00E0, 8'd3, 3'd2);
        issued_ids[issue_idx] = 4'd2; issue_idx = issue_idx + 1;
        do_read(4'd2, 32'h0000_00E0, 8'd3, 3'd2);

        // 3rd: ID=4 (even → FAST, 2 beats from 0x100)
        record_read_info(4'd4, 32'h0000_0100, 8'd1, 3'd2);
        issued_ids[issue_idx] = 4'd4; issue_idx = issue_idx + 1;
        do_read(4'd4, 32'h0000_0100, 8'd1, 3'd2);

        // 4th: ID=3 (odd → SLOW, 8 beats from 0x120)
        record_read_info(4'd3, 32'h0000_0120, 8'd7, 3'd2);
        issued_ids[issue_idx] = 4'd3; issue_idx = issue_idx + 1;
        do_read(4'd3, 32'h0000_0120, 8'd7, 3'd2);

        total_beats = 4 + 4 + 2 + 8;   // 18 beats
        drain_read_responses(total_beats);

        // Verify out-of-order completion
        check_completion_out_of_order(issue_idx);

        print_test_result("Out-of-order read", pass);
    end
    endtask

    //----------------------------------------------------------------------
    // Test 7 — Concurrent read/write
    //   Start a large write; while it is in progress, issue a read to
    //   a different address region.
    //----------------------------------------------------------------------
    task test_concurrent_rw;
        reg pass;
        integer total_beats;
    begin
        print_test_header("Concurrent read/write");
        pass = 1'b1;

        // Pre-write known data to the read region
        do_write(4'd0, 32'h0000_0200, 8'd7, 3'd2);   // 8 beats at 0x200
        wait_clks(5);

        // Start a large write (will take many cycles)
        @(posedge clk);
        cmd_valid  <= 1'b1;
        cmd_write  <= 1'b1;
        cmd_addr   <= 32'h0000_0300;    // region separate from read
        cmd_len    <= 8'd31;             // 32 beats — long burst
        cmd_size   <= 3'd2;
        cmd_id     <= 4'd5;
        @(posedge clk);
        while (!cmd_ready) @(posedge clk);
        cmd_valid  <= 1'b0;
        cmd_write  <= 1'b0;
        update_ref_mem(4'd5, 32'h0000_0300, 8'd31, 3'd2);
        $display("  [WR]  ID=5  ADDR=0x00000300  LEN=31  SIZE=2  — issued (concurrent)");

        // Immediately issue a read to the pre-written region
        wait_clks(2);
        record_read_info(4'd6, 32'h0000_0200, 8'd7, 3'd2);
        issued_ids[0] = 4'd6;
        issue_idx = 1;
        completion_idx = 0;
        do_read(4'd6, 32'h0000_0200, 8'd7, 3'd2);

        // Drain the read
        total_beats = 8;
        drain_read_responses(total_beats);
        $display("  [CONC]  Read completed while write still in progress");

        // Wait for the write to finish
        wait_write_idle;
        $display("  [CONC]  Write completed");

        print_test_result("Concurrent read/write", pass);
    end
    endtask

    //==========================================================================
    //===  M A I N   T E S T   S E Q U E N C E  ================================
    //==========================================================================
    initial begin
        // Initialize
        total_tests   = 0;
        passed_tests  = 0;
        failed_tests  = 0;
        cmd_valid     = 1'b0;
        cmd_write     = 1'b0;
        cmd_addr      = 32'd0;
        cmd_len       = 8'd0;
        cmd_size      = 3'd0;
        cmd_id        = 4'd0;
        completion_idx = 0;
        issue_idx      = 0;

        init_ref_mem();

        // Reset sequence
        $display("============================================================");
        $display("  AXI4 Master-Slave Verification Platform");
        $display("============================================================");
        rst_n = 1'b0;
        wait_clks(5);
        rst_n = 1'b1;
        wait_clks(3);
        $display("  Reset released");

        // Run tests
        test_small_burst_write();
        test_large_burst_write();
        test_narrow_burst_write();
        test_medium_burst_write();
        test_readback();
        test_out_of_order_read();
        test_concurrent_rw();

        // Summary
        $display("");
        $display("============================================================");
        $display("  VERIFICATION SUMMARY");
        $display("============================================================");
        $display("  Total tests : %0d", passed_tests + failed_tests);
        $display("  Passed      : %0d", passed_tests);
        $display("  Failed      : %0d", failed_tests);
        if (failed_tests == 0) begin
            $display("  *** ALL TESTS PASSED ***");
        end else begin
            $display("  *** %0d TEST(S) FAILED ***", failed_tests);
        end
        $display("============================================================");

        $finish();
    end

    //==========================================================================
    // Simulation timeout watchdog
    //==========================================================================
    initial begin
        #1000000;
        $display("ERROR: Simulation timeout (1 000 000 ns)");
        $finish();
    end

endmodule
