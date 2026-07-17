`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/25 22:40:06
// Design Name: 
// Module Name: fetch_stage
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


module fetch_stage #(
    parameter MACHINE_CODE = ""
) (
    input clk_i,
    input rst_ni,

    input         is_ecall_i,
    input         is_mret_i,
    input  [31:0] val_csr_i,
    input         is_brc_i,
    input         is_jal_i,
    input         is_jalr_i,
    input         brc_taken,
    input  [31:0] brc_pc_i,
    input  [31:0] jal_pc_i,
    input  [31:0] jalr_pc_i,
    input  [31:0] pc_i,
    output [31:0] inst_o,
    output [31:0] pc_o,
    output [31:0] nxt_pc_o
);
  // Instrucion memory
  instruction_memory #(
      .MACHINE_CODE(MACHINE_CODE)
  ) im (
      .pc_i  (pc_i),
      .inst_o(inst_o)
  );


  assign  nxt_pc_o = is_ecall_i ? val_csr_i :
                    is_mret_i  ? val_csr_i  :
                    (brc_taken & is_brc_i)  ? brc_pc_i :
                    is_jal_i   ? jal_pc_i :
                    is_jalr_i  ? jalr_pc_i : pc_i + 4;
  assign pc_o = pc_i;


endmodule
