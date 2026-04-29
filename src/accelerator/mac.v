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


module mac #(
    parameter INPUT_BITS  = 16,
    parameter WEIGHT_BITS = 16,
    parameter OUTPUT_BITS = 48
) (
    input                                  i_clk,
    input                                  i_rstn,
    input                                  i_en,
    input  signed     [ INPUT_BITS - 1:0] i_input,
    input  signed     [WEIGHT_BITS - 1:0] i_weight,
    output reg                             o_valid,
    output reg signed [OUTPUT_BITS - 1:0] o_data
);

  // wrie
  wire signed [OUTPUT_BITS - 1:0] r_dsp_output;

  // reg
  reg delay0;

  // delay for mac calculate (add : 1  clock)
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      delay0 <= 'd0;
    end else begin
      delay0 <= i_en;
    end
  end

  // output 
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      o_valid <= 'd0;
      o_data  <= 'd0;
    end else begin
      o_valid <= 'd0;
      if (delay0) begin
        o_valid <= 'd1;
        o_data  <= r_dsp_output;
      end
    end
  end

  dsp_add_macro dsp (
      .CLK(i_clk),
      .CE (1'b1),         // 저전력 설계시 off 고려
      .A  (i_input),
      .B  (i_weight),
      .P  (r_dsp_output)
  );

endmodule
