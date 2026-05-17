`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/04/29 13:08:08
// Design Name: 
// Module Name: mac
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


module adder #(
    parameter BITS = 16,
    localparam OUTPUT_BITS = BITS + 1
) (
    input                           i_clk,
    input                           i_rstn,
    input                           i_add_en,
    // ipt 1
    input                           i_ipt1_vld,
    input  signed [     BITS - 1:0] i_ipt1_din,
    // ipt 2
    input                           i_ipt2_vld,
    input  signed [     BITS - 1:0] i_ipt2_din,
    // opt 
    output                          o_opt_vld,
    output signed [OUTPUT_BITS-1:0] o_opt_dout   // 16 + 16 = 17 bit
);
  // ----------------------- parmeter ---------------------- 
  localparam DSP_DLY = 1;
  // ------------------------- wire ------------------------


  // ------------------------- reg -------------------------   
  // opt
  reg                     r_opt_vld;
  reg signed [BITS - 1:0] r_opt_dat;
  // ---------------------- hand shake ---------------------  
  // ------------------------ assign -----------------------   
  assign o_opt_vld  = r_opt_vld;
  assign o_opt_dout = r_opt_dat;
  // ------------------------ always ----------------------- 
  // output
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_opt_vld <= 'b0;
      r_opt_dat <= 'd0;
    end else begin
      // input 1과 input2 가 valid함
      r_opt_vld <= (i_ipt1_vld && i_ipt2_vld);
      // adder 가 enable할 때
      if (i_add_en) r_opt_dat <= i_ipt1_din + i_ipt2_din;
    end
  end
  // ------------------------- module ----------------------  


endmodule
