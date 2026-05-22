`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/04/23 16:06:57
// Design Name: 
// Module Name: PU
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


// PE에 하나의 MAC이 포함되어있으며, MAC은 사실상 누적은 안하고 곱하기만 함
module pe_8_8 #(
    parameter INPUT_BITS   = 16,
    parameter WEIGHT_BITS  = 16,
    parameter OUTPUT_BITS  = 32,
    parameter PATCH_WIDTH  = 3,
    parameter PATCH_HEIGHT = 3,

    localparam PATCH_AREA = PATCH_WIDTH * PATCH_HEIGHT,
    localparam PATCH_SIZE = INPUT_BITS * PATCH_AREA

) (
    input                             i_clk,
    input                             i_rstn,
    input                             i_pe_en,
    // wgt 
    input  signed [WEIGHT_BITS - 1:0] i_wgt_din,
    // ipt  
    input  signed [INPUT_BITS  - 1:0] i_ipt_din,
    // opt  
    output signed [OUTPUT_BITS - 1:0] o_opt_dout
);
  // ----------------------- parmeter ----------------------  
  integer                      i;
  // ------------------------- reg -------------------------  
  reg signed [WEIGHT_BITS-1:0] r_wgt_dat;

  // ------------------------ always -----------------------    
  // ------------------------- module ---------------------- 

  mac #(
      .INPUT_BITS (INPUT_BITS),
      .WEIGHT_BITS(WEIGHT_BITS),
      .OUTPUT_BITS(OUTPUT_BITS)
  ) inst_mac (

      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      .i_mac_en  (i_pe_en),
      // wgt
      .i_wgt_din (i_wgt_din),
      // ipt  
      .i_ipt_din (i_ipt_din),
      // opt  
      .o_opt_dout(o_opt_dout)
  );

endmodule
