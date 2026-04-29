`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/25 19:59:57
// Design Name: 
// Module Name: pc_increment
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


module pc_increment (
    input         pc_en_i,
    input  [31:0] pc_i,
    output [31:0] nxt_pc_o
);

  // 4 byte increase (1 instruction fetch per cylce)
  assign nxt_pc_o = (pc_en_i) ? pc_i + 4 : pc_i;
endmodule
