`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/29 01:05:30
// Design Name: 
// Module Name: wb_stage
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


module wb_stage (
    input         reg_we_i,
    input         csr_we_i,
    input  [ 4:0] dst_i,
    input  [31:0] val_i,
    input  [11:0] dst_csr_i,
    input  [31:0] val_csr_i,
    input  [31:0] pc_i,
    output        reg_we_o,
    output        csr_we_o,
    output [ 4:0] dst_o,
    output [31:0] val_o,
    output [11:0] dst_csr_o,
    output [31:0] val_csr_o,
    output [31:0] pc_o
);

  assign csr_we_o  = csr_we_i;
  assign dst_csr_o = dst_csr_i;
  assign val_csr_o = val_csr_i;

  assign reg_we_o  = reg_we_i;
  assign dst_o     = dst_i;
  assign val_o     = val_i;

  assign pc_o      = pc_i;
endmodule
