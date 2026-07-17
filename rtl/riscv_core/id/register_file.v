`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/26 10:01:02
// Design Name: 
// Module Name: register_file
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

module reg_file #(
    parameter ADDR_WIDTH = 5,
    parameter DATA_WIDTH = 32
) (
    input clk_i,
    input rst_ni,

    // Port A
    input  [ADDR_WIDTH-1:0] src_a_i,
    output [DATA_WIDTH-1:0] val_a_o,

    // Port B
    input  [ADDR_WIDTH-1:0] src_b_i,
    output [DATA_WIDTH-1:0] val_b_o,

    // Port D
    input                  reg_we_i,
    input [ADDR_WIDTH-1:0] dst_i,
    input [DATA_WIDTH-1:0] val_d_i
);
  // number of integer registers
  localparam NUM_WORDS = 2 ** (ADDR_WIDTH);

  reg [DATA_WIDTH-1:0] mem[0:NUM_WORDS-1];

  integer i;
  always @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      for (i = 0; i < NUM_WORDS; i = i + 1) begin
        mem[i] <= 32'b0;
      end
    end else begin
      if (reg_we_i && dst_i != 5'b0) begin
        mem[dst_i] <= val_d_i;
      end
    end
  end

  assign val_a_o = mem[src_a_i];
  assign val_b_o = mem[src_b_i];
endmodule

