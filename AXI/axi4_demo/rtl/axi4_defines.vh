//==============================================================================
// AXI4 Protocol Parameter Definitions
//==============================================================================
`ifndef AXI4_DEFINES_VH
`define AXI4_DEFINES_VH

    // Bus Width Parameters
    `define AXI4_DATA_WIDTH   32
    `define AXI4_ADDR_WIDTH   32
    `define AXI4_ID_WIDTH      4
    `define AXI4_STRB_WIDTH   (`AXI4_DATA_WIDTH / 8)   // = 4

    // AXI4 Burst Type Encoding
    `define AXI4_BURST_FIXED  2'b00
    `define AXI4_BURST_INCR   2'b01
    `define AXI4_BURST_WRAP   2'b10

    // AXI4 Response Encoding
    `define AXI4_RESP_OKAY    2'b00
    `define AXI4_RESP_EXOKAY  2'b01
    `define AXI4_RESP_SLVERR  2'b10
    `define AXI4_RESP_DECERR  2'b11

    // AXI4 Transfer Size Encoding (2^SIZE bytes per beat)
    `define AXI4_SIZE_1B      3'b000
    `define AXI4_SIZE_2B      3'b001
    `define AXI4_SIZE_4B      3'b010
    `define AXI4_SIZE_8B      3'b011

`endif
