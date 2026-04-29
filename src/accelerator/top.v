`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/04/23 15:34:14
// Design Name: 
// Module Name: TOP_prac1
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


module top #(
    parameter INPUT_BITS   = 16,
    parameter INPUT_WIDTH   = 5,
    parameter INPUT_HEIGHT  = 5,
    parameter WEIGHT_BITS  = 16,
    parameter WEIGHT_WIDTH  = 3,
    parameter WEIGHT_HEIGHT = 3,
    parameter OUTPUT_BITS  = 32,
    parameter LINE_BITS    = 16,
    parameter LINE_WIDTH    = 5,
    parameter LINE_HEIGHT   = 3,
    parameter PATCH_WIDTH   = 3,
    parameter PATCH_HEIGHT  = 3,
    parameter CHANNEL_NUM  = 3
) (
    input                               i_clk,
    input                               i_rstn,
    input [                        1:0] i_ch,
    input                               i_line_done,     // what
    input                               i_input_valid,
    input [ INPUT_BITS*CHANNEL_NUM-1:0] i_input_data,
    input                               i_weight_valid,
    input [WEIGHT_BITS*CHANNEL_NUM-1:0] i_weight_data,

    output                               o_ch_done,
    output                               o_output_valid,
    output [OUTPUT_BITS*CHANNEL_NUM-1:0] o_output,
    output                               o_line_rd_done
);
  // pu
  pu #(
      .INPUT_BITS   (INPUT_BITS),
      .INPUT_WIDTH  (INPUT_WIDTH),
      .INPUT_HEIGHT (INPUT_HEIGHT),
      .WEIGHT_BITS  (WEIGHT_BITS),
      .WEIGHT_WIDTH (WEIGHT_WIDTH),
      .WEIGHT_HEIGHT(WEIGHT_HEIGHT),
      .OUTPUT_BITS  (OUTPUT_BITS),
      .LINE_BITS    (LINE_BITS),
      .LINE_WIDTH   (LINE_WIDTH),
      .LINE_HEIGHT  (LINE_HEIGHT),
      .PATCH_WIDTH  (PATCH_WIDTH),
      .PATCH_HEIGHT (PATCH_HEIGHT)
  ) inst_pu (
      .i_clk         (i_clk),
      .i_rstn        (i_rstn),
      .i_pu_en       (1'b1),
      .i_weight_valid(i_weight_valid),
      .i_weight_data (i_weight_data),
      .i_input_valid (i_input_valid),
      .i_input_data  (i_input_data),
      .o_line_rd_done(o_line_rd_done),
      .o_pu_data     (o_output),
      .o_pu_valid    (o_output_valid)
  );

endmodule
