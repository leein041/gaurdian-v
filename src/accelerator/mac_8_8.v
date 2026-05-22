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

module mac_8_8 #(
    parameter WEIGHT_BITS = 16,
    parameter INPUT_BITS  = 16,
    parameter OUTPUT_BITS = 32 + 3
) (
    input                             i_clk,
    input                             i_rstn,
    input                             i_mac_en,
    // wgt
    input  signed [WEIGHT_BITS - 1:0] i_wgt_din,
    // ipt  
    input  signed [ INPUT_BITS - 1:0] i_ipt_din,
    // opt  
    output signed [OUTPUT_BITS - 1:0] o_opt_vld,
    output signed [OUTPUT_BITS - 1:0] o_opt_dout
);
  // ----------------------- parmeter ---------------------- 
  localparam DSP_DLY = 4;
  integer               i;
  // ------------------------- wire ------------------------ 
  wire    [       47:0] w_mac_dat;
  // ------------------------- reg -------------------------   
  reg     [DSP_DLY-1:0] r_opt_vld;
  reg     [       47:0] r_sum_dat;
  // ---------------------- hand shake --------------------- 
  // ------------------------ assign -----------------------    
  // ------------------------ always ----------------------- 
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_opt_vld <= 'd0;
    end else begin
      r_opt_vld <= {r_opt_vld[DSP_DLY-2:0], i_mac_en};
    end
  end
    always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_sum_dat <= 'd0;
    end else (r_opt_vld[1]) begin
      r_sum_dat <= 
    end
  end
  // ------------------------- module ----------------------   
  dsp_mac_macro your_instance_name (
      .CLK(i_clk),
      .CE (i_mac_en),
      .A  (i_ipt_din),
      .B  (i_wgt_din),
      .C  (r_sum_dat),
      .P  (w_mac_dat)
  );

  assign o_opt_dout = w_mac_dat[OUTPUT_BITS-1 : 0];  // 32 + 3 (add 로 인한 3비트 확장) 
endmodule
