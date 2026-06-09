 /*                                                                      
 Copyright 2018 Nuclei System Technology, Inc.                
                                                                         
 Licensed under the Apache License, Version 2.0 (the "License");         
 you may not use this file except in compliance with the License.        
 You may obtain a copy of the License at                                 
                                                                         
     http://www.apache.org/licenses/LICENSE-2.0                          
                                                                         
  Unless required by applicable law or agreed to in writing, software    
 distributed under the License is distributed on an "AS IS" BASIS,       
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and     
 limitations under the License.                                          
 */                                                                      
                                                                         
                                                                         
                                                                         
//=====================================================================
//
// Designer   : Bob Hu
//
// Description:
//  The top module of the example APB slave
//
// ====================================================================
module sirv_expl_apb_slv #(
    parameter AW = 32,
    parameter DW = 32 
)(
  input  [AW-1:0] apb_paddr,
  input           apb_pwrite,
  input           apb_pselx,
  input           apb_penable,
  input  [DW-1:0] apb_pwdata,
  output [DW-1:0] apb_prdata,

  input  clk,  
  input  rst_n
);
//   localparam [AW-1:0] START_ADDR = 32'h10041000;
//   localparam [AW-1:0] FSTREG_ADDR = START_ADDR;
//   localparam [AW-1:0] SCDREG_ADDR = START_ADDR+32'h4;
//   localparam [AW-1:0] THDREG_ADDR = START_ADDR+32'h8;

//   reg [DW-1:0] apb_prdata;
//   reg [DW-1:0] reg_fisrt;
//   reg [DW-1:0] reg_second;

//   assign rdec_fst = (apb_paddr==(FSTREG_ADDR));
//   assign rdec_scd = (apb_paddr==(SCDREG_ADDR));
//   assign rdec_thd = (apb_paddr==(THDREG_ADDR));
//   reg [DW-1:0] CNN_finish_count;
//   reg CNN_finish_signal;

// //////write
// always@(posedge clk or negedge rst_n) begin:WRITE_PROC
//   if(!rst_n) begin reg_fisrt <= 0;reg_second<=0;end
//   else
//      if(apb_pwrite & apb_penable &apb_pselx)
//      begin
//   	if(rdec_fst)
//     		reg_fisrt = apb_pwdata;
//   	if(rdec_scd)
//     		reg_second = apb_pwdata;
//      end
// end

// ////// a simple apb slv
// always@(posedge clk or negedge rst_n) begin:CNN_PROC
//   if(!rst_n) begin CNN_finish_count <= 0;CNN_finish_signal<=0;end
//   else
//      if(reg_second[0]==1 & CNN_finish_signal==0)
//      begin
//   	CNN_finish_count <= CNN_finish_count+1;
//   	if(CNN_finish_count==32'hf)
// 		begin
//     			CNN_finish_count <= 0;
// 			CNN_finish_signal <= 1;
// 		end
// 	//else CNN_finish_signal <= 0;
//      end
//      //else begin CNN_finish_count <= 0;CNN_finish_signal<=0;end
// end

// //////read
// always@(*) begin:READ_BACK_MUX_PROC
//   if(rst_n & !apb_pwrite & apb_penable &apb_pselx)
//      begin
//   	apb_prdata = {DW{1'b0}};
//   	if(rdec_fst)
//     		apb_prdata = reg_fisrt;
//   	if(rdec_scd)
//     		apb_prdata = reg_second;
//   	if(rdec_thd)
//     		apb_prdata = CNN_finish_signal;
//      end
// end 


  //assign apb_prdata = apb_pwrite ? mem1[apb_paddr]:{DW{1'b1}};

endmodule
