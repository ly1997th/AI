module sirv_conv_slv#(
    parameter AW=32,
    parameter DW=32
)(
  input                          cmd_valid,
  output                         cmd_ready,
  input  [AW-1:0]                cmd_addr, 
  input                          cmd_read, 
  input  [DW-1:0]                cmd_wdata,
  input  [DW/8-1:0]              cmd_wmask,
  //
  output reg                     rsp_valid,
  input                          rsp_ready,
  output                         rsp_err,
  output reg  [DW-1:0]           rsp_rdata,

  input                          clk,
  input                          rst_n
);

assign cmd_ready=cmd_valid;
assign rsp_err=1'b0;

//address unit
wire [AW-1:0]   addr_true;
assign addr_true=(cmd_addr - 32'hD0000000);

//****************control signals*********************
//this icb data read finished
reg read_finish;
//this icb data write finished
reg weight_write_finish;
reg image_write_finish;
//finish image loading
reg image_finish;
//finish weight loading
reg weight_finish;
//finish this cycle of calculating concolution
reg cycle_finish;
//buffers for calculating and data matrix constructing
reg signed [7:0]    imageBuf[0:2][0:33];
reg signed [7:0]    weightBuf[0:15][0:8];
reg signed [19:0]   resBuf[0:15][0:31];
reg [1:0]   row_construct;
reg [3:0]   row_count;
reg [3:0]   weight_construct_i;
reg [3:0]   weight_construct_j;
reg [7:0]   cal_count;
reg [3:0]   read_i;
reg [7:0]   read_j;




//temporary variables for calculating convolution
    wire signed [7:0]  conv_in[0:15][1:9];  
    wire signed [19:0] conv_mul[0:15][1:9];
    wire signed [19:0] conv_result[0:15];

    //calcullate 3*3 image data matrix of 16 weight kernels
    genvar weight_count;
    generate
        for(weight_count=0;weight_count<16;weight_count=weight_count+1)
        begin:conv_cal
            assign conv_in[weight_count][1] = imageBuf[0][cal_count-1];
            assign conv_in[weight_count][2] = imageBuf[0][cal_count];
            assign conv_in[weight_count][3] = imageBuf[0][cal_count+1];
            assign conv_in[weight_count][4] = imageBuf[1][cal_count-1];
            assign conv_in[weight_count][5] = imageBuf[1][cal_count];
            assign conv_in[weight_count][6] = imageBuf[1][cal_count+1];
            assign conv_in[weight_count][7] = imageBuf[2][cal_count-1];
            assign conv_in[weight_count][8] = imageBuf[2][cal_count];
            assign conv_in[weight_count][9] = imageBuf[2][cal_count+1];

            assign conv_mul[weight_count][1] =weightBuf[weight_count][0]*conv_in[weight_count][1];
            assign conv_mul[weight_count][2] =weightBuf[weight_count][1]*conv_in[weight_count][2];
            assign conv_mul[weight_count][3] =weightBuf[weight_count][2]*conv_in[weight_count][3];
            assign conv_mul[weight_count][4] =weightBuf[weight_count][3]*conv_in[weight_count][4];
            assign conv_mul[weight_count][5] =weightBuf[weight_count][4]*conv_in[weight_count][5];
            assign conv_mul[weight_count][6] =weightBuf[weight_count][5]*conv_in[weight_count][6];
            assign conv_mul[weight_count][7] =weightBuf[weight_count][6]*conv_in[weight_count][7];
            assign conv_mul[weight_count][8] =weightBuf[weight_count][7]*conv_in[weight_count][8];
            assign conv_mul[weight_count][9] =weightBuf[weight_count][8]*conv_in[weight_count][9];

            assign conv_result[weight_count] = conv_mul[weight_count][1] + conv_mul[weight_count][2] + conv_mul[weight_count][3] + 
                                                conv_mul[weight_count][4] + conv_mul[weight_count][5] + conv_mul[weight_count][6] + 
                                                conv_mul[weight_count][7] + conv_mul[weight_count][8] + conv_mul[weight_count][9];
        end
    endgenerate






always @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
    read_finish             <=1'b0;
    image_write_finish      <=1'b0;
    weight_write_finish     <=1'b0;
    rsp_valid               <=1'b0;
    row_construct           <=0;
    row_count               <=0;
    weight_construct_i      <=0;
    weight_construct_j      <=0;
    cycle_finish            <=0;
    image_finish            <=0;
    weight_finish           <=0;
    cal_count               <=1;
    read_i                  <=0;
    read_j                  <=0;
    imageBuf[0][0]<=0;imageBuf[0][33]<=0;
    imageBuf[1][0]<=0;imageBuf[1][33]<=0;
    imageBuf[2][0]<=0;imageBuf[2][33]<=0;
    end

    else if(image_write_finish==1)
    begin
        image_write_finish<=0;
        rsp_valid<=0;
    end
    else if(cmd_valid  && !cmd_read && addr_true<32'h000000FF && cycle_finish==0 && image_finish==0)
    begin 
        if(row_construct==3)
        //update the imageBuf
        begin
            if(row_count==8)
            begin
                imageBuf[0][1]<=imageBuf[1][1];
                imageBuf[1][1]<=imageBuf[2][1];
                imageBuf[0][2]<=imageBuf[1][2];
                imageBuf[1][2]<=imageBuf[2][2];
                imageBuf[0][3]<=imageBuf[1][3];
                imageBuf[1][3]<=imageBuf[2][3];
                imageBuf[0][4]<=imageBuf[1][4];
                imageBuf[1][4]<=imageBuf[2][4];
                imageBuf[0][5]<=imageBuf[1][5];
                imageBuf[1][5]<=imageBuf[2][5];
                imageBuf[0][6]<=imageBuf[1][6];
                imageBuf[1][6]<=imageBuf[2][6];
                imageBuf[0][7]<=imageBuf[1][7];
                imageBuf[1][7]<=imageBuf[2][7];
                imageBuf[0][8]<=imageBuf[1][8];
                imageBuf[1][8]<=imageBuf[2][8];
                imageBuf[0][9]<=imageBuf[1][9];
                imageBuf[1][9]<=imageBuf[2][9];
                imageBuf[0][10]<=imageBuf[1][10];
                imageBuf[1][10]<=imageBuf[2][10];
                imageBuf[0][11]<=imageBuf[1][11];
                imageBuf[1][11]<=imageBuf[2][11];
                imageBuf[0][12]<=imageBuf[1][12];
                imageBuf[1][12]<=imageBuf[2][12];
                imageBuf[0][13]<=imageBuf[1][13];
                imageBuf[1][13]<=imageBuf[2][13];
                imageBuf[0][14]<=imageBuf[1][14];
                imageBuf[1][14]<=imageBuf[2][14];
                imageBuf[0][15]<=imageBuf[1][15];
                imageBuf[1][15]<=imageBuf[2][15];
                imageBuf[0][16]<=imageBuf[1][16];
                imageBuf[1][16]<=imageBuf[2][16];
                imageBuf[0][17]<=imageBuf[1][17];
                imageBuf[1][17]<=imageBuf[2][17];
                imageBuf[0][18]<=imageBuf[1][18];
                imageBuf[1][18]<=imageBuf[2][18];
                imageBuf[0][19]<=imageBuf[1][19];
                imageBuf[1][19]<=imageBuf[2][19];
                imageBuf[0][20]<=imageBuf[1][20];
                imageBuf[1][20]<=imageBuf[2][20];
                imageBuf[0][21]<=imageBuf[1][21];
                imageBuf[1][21]<=imageBuf[2][21];
                imageBuf[0][22]<=imageBuf[1][22];
                imageBuf[1][22]<=imageBuf[2][22];
                imageBuf[0][23]<=imageBuf[1][23];
                imageBuf[1][23]<=imageBuf[2][23];
                imageBuf[0][24]<=imageBuf[1][24];
                imageBuf[1][24]<=imageBuf[2][24];
                imageBuf[0][25]<=imageBuf[1][25];
                imageBuf[1][25]<=imageBuf[2][25];
                imageBuf[0][26]<=imageBuf[1][26];
                imageBuf[1][26]<=imageBuf[2][26];
                imageBuf[0][27]<=imageBuf[1][27];
                imageBuf[1][27]<=imageBuf[2][27];
                imageBuf[0][28]<=imageBuf[1][28];
                imageBuf[1][28]<=imageBuf[2][28];
                imageBuf[0][29]<=imageBuf[1][29];
                imageBuf[1][29]<=imageBuf[2][29];
                imageBuf[0][30]<=imageBuf[1][30];
                imageBuf[1][30]<=imageBuf[2][30];
                imageBuf[0][31]<=imageBuf[1][31];
                imageBuf[1][31]<=imageBuf[2][31];
                imageBuf[0][32]<=imageBuf[1][32];
                imageBuf[1][32]<=imageBuf[2][32];
                //imageBuf[0][0]<=imageBuf[1][0];imageBuf[0][1]<=imageBuf[1][1];imageBuf[0][2]<=imageBuf[1][2];imageBuf[0][3]<=imageBuf[1][3];
                if(cmd_wmask[0]) imageBuf[2][1]  <= cmd_wdata[7:0];
                if(cmd_wmask[1]) imageBuf[2][2]  <= cmd_wdata[15:8];
                if(cmd_wmask[2]) imageBuf[2][3]  <= cmd_wdata[23:16];
                if(cmd_wmask[3]) imageBuf[2][4]  <= cmd_wdata[31:24];
                row_count<=1;
                image_write_finish<=1;
                rsp_valid<=1;
            end
            else
            begin
                row_count<=row_count+1;
                if(cmd_wmask[0]) imageBuf[2][row_count*4+1]   <= cmd_wdata[7:0];
                if(cmd_wmask[1]) imageBuf[2][row_count*4+2]   <= cmd_wdata[15:8];
                if(cmd_wmask[2]) imageBuf[2][row_count*4+3]   <= cmd_wdata[23:16];
                if(cmd_wmask[3]) imageBuf[2][row_count*4+4]   <= cmd_wdata[31:24];
                image_write_finish<=1;
                rsp_valid<=1;
                if(row_count==7) begin image_finish<=1; end;
            end
        end
        else if(row_construct<3)
        //construct the fisrt three row of buffer
        begin
            if(row_count<8)
            begin
                if(image_write_finish==0)
                begin
                    if(cmd_wmask[0]) imageBuf[row_construct][row_count*4+1] <= cmd_wdata[7:0];
                    if(cmd_wmask[1]) imageBuf[row_construct][row_count*4+2] <= cmd_wdata[15:8];
                    if(cmd_wmask[2]) imageBuf[row_construct][row_count*4+3] <= cmd_wdata[23:16];
                    if(cmd_wmask[3]) imageBuf[row_construct][row_count*4+4] <= cmd_wdata[31:24];
                    row_count<=row_count+1;
                    if(row_construct==2 && row_count==7) 
                    begin
                        row_construct<=row_construct+1;
                        image_finish<=1;
                    end
                    image_write_finish<=1;
                    rsp_valid<=1;
                end
            end
            else if(row_construct<2)
            begin
                row_count<=1;
                row_construct<=row_construct+1;
                case(row_construct)
                    2'b00:
                        begin
                            if(cmd_wmask[0]) imageBuf[1][1] <= cmd_wdata[7:0];
                            if(cmd_wmask[1]) imageBuf[1][2] <= cmd_wdata[15:8];
                            if(cmd_wmask[2]) imageBuf[1][3] <= cmd_wdata[23:16];
                            if(cmd_wmask[3]) imageBuf[1][4] <= cmd_wdata[31:24];
                            image_write_finish<=1;
                            rsp_valid<=1;
                        end
                    2'b01:
                        begin
                            if(cmd_wmask[0]) imageBuf[2][1]   <= cmd_wdata[7:0];
                            if(cmd_wmask[1]) imageBuf[2][2]   <= cmd_wdata[15:8];
                            if(cmd_wmask[2]) imageBuf[2][3]   <= cmd_wdata[23:16];
                            if(cmd_wmask[3]) imageBuf[2][4]   <= cmd_wdata[31:24];
                            image_write_finish<=1;
                            rsp_valid<=1;
                        end
                    default:begin row_construct<=0;row_count<=0; end
                endcase
            end
        end
    end


    //load the weight matrix from the icb

    else if(weight_write_finish==1)
    begin
        weight_write_finish<=0;
        rsp_valid<=0;
    end
    else if(cmd_valid  && !cmd_read && addr_true>32'h000000FF && addr_true<32'h00000200)
    begin
        if(weight_construct_j<6)
        begin
            weight_construct_j<=weight_construct_j+3;             
        end
        else if(weight_construct_i<15)
        begin
            weight_construct_j<=0;
            weight_construct_i<=weight_construct_i+1;
        end
        if(cmd_wmask[0]) weightBuf[weight_construct_i][weight_construct_j]   <= cmd_wdata[7:0];
        if(cmd_wmask[1]) weightBuf[weight_construct_i][weight_construct_j+1] <= cmd_wdata[15:8];
        if(cmd_wmask[2]) weightBuf[weight_construct_i][weight_construct_j+2] <= cmd_wdata[23:16];
        weight_write_finish<=1;
        rsp_valid<=1;
        if(weight_construct_i==15 && weight_construct_j==6)  begin weight_finish<=1; end
    end 



    //calculate the convolution

    else if(image_finish && weight_finish && cycle_finish==0 )
    begin
        if(cal_count<32) begin cal_count<=cal_count+1; end
        else begin cal_count<=1;cycle_finish<=1;end

        //load the result
        resBuf[0][cal_count-1]<=conv_result[0];
        resBuf[1][cal_count-1]<=conv_result[1];
        resBuf[2][cal_count-1]<=conv_result[2];
        resBuf[3][cal_count-1]<=conv_result[3];
        resBuf[4][cal_count-1]<=conv_result[4];
        resBuf[5][cal_count-1]<=conv_result[5];
        resBuf[6][cal_count-1]<=conv_result[6];
        resBuf[7][cal_count-1]<=conv_result[7];
        resBuf[8][cal_count-1]<=conv_result[8];
        resBuf[9][cal_count-1]<=conv_result[9];
        resBuf[10][cal_count-1]<=conv_result[10];
        resBuf[11][cal_count-1]<=conv_result[11];
        resBuf[12][cal_count-1]<=conv_result[12];
        resBuf[13][cal_count-1]<=conv_result[13];
        resBuf[14][cal_count-1]<=conv_result[14];
        resBuf[15][cal_count-1]<=conv_result[15]; 
    end

    //transport the result data to icb bus
    else if(read_finish==1)
    begin
        read_finish <=0;
        rsp_valid   <=0;
    end
    else if(cmd_valid && cmd_read && cycle_finish && rsp_ready && addr_true>=32'h00001000)
    begin
        if(read_j<31) begin read_j<=read_j+1; end
        else if(read_i<15) begin read_i<=read_i+1; read_j<=0; end
        if(read_i==15 && read_j==31)
        begin
            read_i<=0;read_j<=0;
            cycle_finish    <=0;
            image_finish    <=0;
        end
        rsp_rdata   <=resBuf[read_i][read_j];
        rsp_valid   <=1;
        read_finish <=1;
    end
end




endmodule