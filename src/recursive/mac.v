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
 
//이름은 MAC이지만 일단 곱셈만함 누적안함
module mac #(
    parameter WEIGHT_BITS = 16,
    parameter INPUT_BITS  = 16,
    parameter OUTPUT_BITS = 32
) (
    input                             i_clk,
    input                             i_rstn,
    input                             i_mac_en,
    // wgt
    input  signed [WEIGHT_BITS - 1:0] i_wgt_din,
    // ipt 
    input                             i_ipt_vld,
    input  signed [ INPUT_BITS - 1:0] i_ipt_din,
    // opt 
    output                            o_opt_vld,
    output signed [OUTPUT_BITS - 1:0] o_opt_dout
);
  // ----------------------- parmeter ---------------------- 
  localparam DSP_DLY = 1;
  // ------------------------- wire ------------------------ 
  // ------------------------- reg -------------------------   
  // opt
  reg r_opt_vld; 
  // ---------------------- hand shake --------------------- 
  // ------------------------ assign -----------------------   
  assign o_opt_vld = r_opt_vld;
  // ------------------------ always ----------------------- 
  // output
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_opt_vld <= 'd0;
    end else begin
      r_opt_vld <= i_ipt_vld;  // 1 clock latency by DSP
    end
  end
  // ------------------------- module ----------------------  
  dsp_mul_macro dsp (
      .CLK(i_clk),
      .CE (i_mac_en),
      .A  (i_ipt_din),
      .B  (i_wgt_din),
      .P  (o_opt_dout)
  );

endmodule
