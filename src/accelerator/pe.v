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



module pe #(
    parameter INPUT_BITS   = 16,
    parameter INPUT_WIDTH   = 5,
    parameter INPUT_HEIGHT  = 5,
    parameter WEIGHT_BITS  = 16,
    parameter WEIGHT_WIDTH  = 3,
    parameter WEIGHT_HEIGHT = 3,
    parameter OUTPUT_BITS  = 48,
    parameter LINE_BITS    = 16,
    parameter LINE_WIDTH    = 5,
    parameter LINE_HEIGHT   = 3,
    parameter PATCH_WIDTH   = 3,
    parameter PATCH_HEIGHT  = 3,
    localparam PATCH_AREA = PATCH_HEIGHT * PATCH_WIDTH,
    parameter CHANNEL_NUM  = 3
) (
    input                                                  i_clk,
    input                                                  i_rstn,
    input                                                  i_pe_en,
    input                                                  i_weight_valid,
    input  [                           WEIGHT_BITS - 1:0] i_weight_data,
    input                                                  i_input_valid,
    input  [LINE_BITS * PATCH_HEIGHT * PATCH_WIDTH - 1:0] i_input_data,
    output                                                 o_pe_valid,
    output [                           OUTPUT_BITS - 1:0] o_pe_data
);

  // weight stationary
  reg  [              WEIGHT_BITS-1:0] r_weight    [0:8];
  reg  [            OUTPUT_BITS - 1:0] r_acc;

  wire [OUTPUT_BITS *PATCH_AREA - 1:0] w_mac_data;
  wire [              PATCH_AREA - 1:0] w_mac_valid;



  // weight 
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_weight[0] <= 'd0;
      r_weight[1] <= 'd0;
      r_weight[2] <= 'd0;
      r_weight[3] <= 'd0;
      r_weight[4] <= 'd0;
      r_weight[5] <= 'd0;
      r_weight[6] <= 'd0;
      r_weight[7] <= 'd0;
      r_weight[8] <= 'd0;
    end else begin
      if (i_weight_valid) begin
        r_weight[0] <= i_weight_data;
        r_weight[1] <= r_weight[0];
        r_weight[2] <= r_weight[1];
        r_weight[3] <= r_weight[2];
        r_weight[4] <= r_weight[3];
        r_weight[5] <= r_weight[4];
        r_weight[6] <= r_weight[5];
        r_weight[7] <= r_weight[6];
        r_weight[8] <= r_weight[7];
      end
    end
  end



  genvar g;
  generate
    for (g = 0; g < 9; g = g + 1) begin : MAC_ARRAY
      mac #(
          .INPUT_BITS (INPUT_BITS),
          .WEIGHT_BITS(WEIGHT_BITS),
          .OUTPUT_BITS(OUTPUT_BITS)
      ) inst_mac (
          .i_clk   (i_clk),
          .i_rstn  (i_rstn),
          .i_en    (i_input_valid),
          .i_input (i_input_data[LINE_BITS*g+:LINE_BITS]),
          .i_weight(r_weight[g]),
          .o_valid (w_mac_valid[g]),
          .o_data  (w_mac_data[OUTPUT_BITS*g+:OUTPUT_BITS])
      );
    end
  endgenerate

  adder_tree #(
      .OUTPUT_BITS(OUTPUT_BITS),
      .INPUT_SIZE  (PATCH_AREA)
  ) inst_adder_tree (
      .i_clk  (i_clk),
      .i_rstn (i_rstn),
      .i_valid(w_mac_valid[0]),  // 동시 작업이므로 대표로 0번 PE만 
      .i_data (w_mac_data),
      .o_data (o_pe_data),
      .o_valid(o_pe_valid)
  );
endmodule
