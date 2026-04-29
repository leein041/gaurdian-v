`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/25 20:00:27
// Design Name: 
// Module Name: instruction_memory
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

module instruction_memory #(
    parameter MACHINE_CODE = "",
    parameter START_INDEX  = 32'h8000_0000
) (
    input  [31:0] pc_i,
    output [31:0] inst_o
);
  // 32비트 단위 메모리 선언 (32 KB)
  reg [31:0] inst_mem[0:16383];

  initial begin
    if (MACHINE_CODE != "") $readmemh(MACHINE_CODE, inst_mem);
  end
  assign inst_o = inst_mem[pc_i[15:2]]; // 16 비트 까지 슬라이싱
  
endmodule
