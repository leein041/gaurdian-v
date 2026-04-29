`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: leein
// 
// Create Date: 2026/03/26 12:55:05
// Design Name: 
// Module Name: alu
// Project Name: 32bit-ui riscv core
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

`include "pkg.vh"

module alu (
    input signed [`OPERATER_WIDTH-1:0] operater_i,
    input signed [               31:0] operand_a_i,
    input signed [               31:0] operand_b_i,

    output wire              c_o,
    output wire              v_o,
    output wire              n_o,
    output wire              z_o,
    output reg signed [31:0] res_o
);

  //        _      _    _         
  //       /_\  __| |__| |___ _ _ 
  //      / _ \/ _` / _` / -_) '_|
  //     /_/ \_\__,_\__,_\___|_|  
  //                              

  wire [ 1:0] adder_op_b;
  wire [31:0] adder_in_a;
  wire [31:0] adder_in_b;
  // prepare operand
  assign adder_in_a = operand_a_i;
  assign adder_op_b = operater_i[2:1];
  assign adder_in_b = (adder_op_b == 2'b00) ? {32{1'b0}} :
                      (adder_op_b == 2'b01) ? operand_b_i :
                      (adder_op_b == 2'b10) ? ~operand_b_i : {32{1'b1}};


  //      ____  _        _             
  //     / ___|| |_ __ _| |_ _   _ ___ 
  //     \___ \| __/ _` | __| | | / __|
  //      ___) | || (_| | |_| |_| \__ \ 
  //     |____/ \__\__,_|\__|\__,_|___/
  //                                   

  wire adder_carry_in = operater_i[0];
  wire [31:0] adder_result;

  assign {c_o, adder_result} = adder_in_a[31:0] + adder_in_b[31:0] + adder_carry_in;

  wire is_sub = (operater_i == `ALU_SUB || operater_i == `ALU_SLT || operater_i == `ALU_SLTU);
  assign v_o = is_sub ? 
             ((operand_a_i[31] != operand_b_i[31]) && (operand_a_i[31] != adder_result[31])) :
             ((operand_a_i[31] == operand_b_i[31]) && (operand_a_i[31] != adder_result[31]));
  assign n_o = adder_result[31];
  assign z_o = (|adder_result) ? 0 : 1;


  //      ___             _ _     __  __          
  //     | _ \___ ____  _| | |_  |  \/  |_  ___ __
  //     |   / -_|_-< || | |  _| | |\/| | || \ \ /
  //     |_|_\___/__/\_,_|_|\__| |_|  |_|\_,_/_\_\ 
  //                                              

  always @(*) begin
    case (operater_i)
      `ALU_MOVA, `ALU_INC, `ALU_ADD, `ALU_SUB, `ALU_DEC: res_o = adder_result;

      // logic circuit
      `ALU_AND: res_o = operand_a_i & operand_b_i;
      `ALU_OR:  res_o = operand_a_i | operand_b_i;
      `ALU_XOR: res_o = operand_a_i ^ operand_b_i;
      `ALU_NOT: res_o = ~operand_a_i;

      `ALU_MOVB: res_o = operand_b_i;

      // shift
      `ALU_SRL:  res_o = operand_a_i >> operand_b_i[4:0];
      `ALU_SRA:  res_o = $signed(operand_a_i) >>> operand_b_i[4:0];
      `ALU_SLL:  res_o = operand_a_i << operand_b_i[4:0];
      `ALU_SLT:  res_o = (n_o ^ v_o) ? 32'h1 : 32'h0;
      `ALU_SLTU: res_o = (~c_o) ? 32'h1 : 32'h0;

      // custom
      `ALU_AND_NOT: res_o = operand_b_i & (~operand_a_i);
      default: res_o = {32{1'b0}};
    endcase

  end

endmodule

