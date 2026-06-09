module sirv_convSRAM_slv
#(
  parameter DP=5000,
  parameter FORCE_X2ZERO = 1,
  parameter DW = 32,
  parameter MW = 4,
  parameter AW = 32 
)
(
  input             clk, 
  input             rst_n,
  input  [DW-1  :0] din, 
  input  [AW-1  :0] addr,
  //disable cs,trun on cs awalys
  //input             cs,
  input             re,
  input  [MW-1:0]   wem,
  output [DW-1:0]   dout,

  input             cmd_valid,
  output            cmd_ready,
  output      reg   rsp_valid,
  input             rsp_ready,
  output            rsp_err
);
  wire we;
  wire cs;
  wire ren;
  assign we=~re;
  assign rsp_err=1'b0;
  assign cmd_ready=cmd_valid;

  reg signed [DW-1:0] mem_r [0:DP-1];
  reg   [AW-1:0]  addr_true_read;
  wire  [AW-1:0]  addr_true;
  wire  [MW-1:0]  wen;
  wire signed [DW-1  :0] din;
  wire signed [DW-1  :0] dout;



  assign addr_true=(addr - 32'hC0000000)>>2;
  assign cs  =1'b1;
  assign ren = cs & (~we);
  assign wen = ({MW{cs & we}} & wem);
  
  
  reg read_finish;
  reg write_finish;

  always @(negedge rst_n) 
  begin
    read_finish<=1'b0;
    write_finish<=1'b0;
    rsp_valid<=1'b0;
  end

  //write the data 
  always @(posedge clk)
  begin
    if(we && cmd_valid)
    begin 
      if(wen[0]) mem_r[addr_true][7:0]   <= din[7:0];
      if(wen[1]) mem_r[addr_true][15:8]  <= din[15:8];
      if(wen[2]) mem_r[addr_true][23:16] <= din[23:16];
      if(wen[3]) mem_r[addr_true][31:24] <= din[31:24];
      // mem_r[addr_true][7:0]   <= din[7:0];
      // mem_r[addr_true][15:8]  <= din[15:8];
      // mem_r[addr_true][23:16] <= din[23:16];
      // mem_r[addr_true][31:24] <= din[31:24];
      write_finish <=1;
      rsp_valid<=1;
    end
    else if(write_finish==1)
        begin
          write_finish<=0;
          rsp_valid<=0;
        end
  end

  //read the data
  always @(posedge clk)
  begin
    if (ren && cmd_valid) 
    begin
        addr_true_read<=addr_true;
        read_finish<=1'b1;
        rsp_valid<=1;
        
    end
    else if(read_finish==1)
    begin 
      rsp_valid<=1'b0; 
      read_finish<=1'b0;
    end
  end

  assign dout=mem_r[addr_true_read];
  //assign dout=(mem_r[addr_true_read][0]==1'bX)? 0:mem_r[addr_true_read];

 
endmodule