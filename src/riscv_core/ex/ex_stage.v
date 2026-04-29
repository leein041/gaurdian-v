`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/27 19:55:11
// Design Name: 
// Module Name: ex_stage
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


module ex_stage (
    input clk_i,
    input rst_ni,

    input                            is_load_i,
    input                            is_brc_i,
    input                            is_jal_i,
    input                            is_jalr_i,
    input                            brc_neg_i,
    input      [                2:0] brc_cond_i,
    input                            e_sel_i,
    input                            m_sel_i,
    input                            mem_en_i,
    input                            mem_rw_i,
    input                            reg_we_i,
    input                            csr_we_i,
    input      [                2:0] mem_ld_width_i,
    input      [                2:0] mem_st_width_i,
    input      [                4:0] dst_i,
    input      [               11:0] dst_csr_i,
    input      [`OPERATER_WIDTH-1:0] alu_operater_i,
    input      [               31:0] val_a_i,         // 00-reg / 01-PC / 10-zero
    input      [               31:0] val_b_i,         //   
    input      [               31:0] val_imm_i,
    input      [               31:0] pc_i,
    input      [               31:0] val_m_i,
    output reg [               31:0] val_ex_o,
    output     [               31:0] val_csr_o,
    output reg                       brc_taken_o,
    output     [               31:0] brc_pc_o,
    output     [               31:0] jal_pc_o,
    output     [               31:0] jalr_pc_o,
    output                           is_load_o,
    output                           m_sel_o,
    output                           mem_en_o,
    output                           mem_rw_o,
    output                           reg_we_o,
    output                           csr_we_o,
    output     [                2:0] mem_ld_width_o,
    output     [                2:0] mem_st_width_o,
    output     [                4:0] dst_o,
    output     [               11:0] dst_csr_o,
    output     [               31:0] val_m_o,
    output     [               31:0] pc_o
);

  wire        do_jmp;
  //status signal
  wire        alu_c_o;
  wire        alu_v_o;
  wire        alu_n_o;
  wire        alu_z_o;
  wire [31:0] val_ex;

  alu ALU (
      .operater_i (alu_operater_i),
      .operand_a_i(val_a_i),
      .operand_b_i(val_b_i),
      .c_o        (alu_c_o),
      .v_o        (alu_v_o),
      .n_o        (alu_n_o),
      .z_o        (alu_z_o),
      .res_o      (val_ex)
  );

  always @(*) begin
    val_ex_o = 32'b0;
    if (is_jalr_i | is_jal_i) begin
      val_ex_o = pc_i + 4;  // return address compute
    end else if (e_sel_i) begin
      val_ex_o = val_b_i;
    end else begin
      val_ex_o = val_ex;  // alu result
    end
  end

  // branch condition check
  always @(*) begin
    brc_taken_o = 1'b0;
    case (brc_cond_i)
      `F3_BEQ, `F3_BNE:   brc_taken_o = alu_z_o ^ brc_neg_i;
      `F3_BLT, `F3_BGE:   brc_taken_o = (alu_n_o ^ alu_v_o) ^ brc_neg_i;
      `F3_BLTU, `F3_BGEU: brc_taken_o = (~alu_c_o) ^ brc_neg_i;
      default:            ;
    endcase
  end
  wire [31:0] brc_pc_tmp;

  assign brc_pc_tmp     = pc_i + val_imm_i;  // pc + offset
  assign brc_pc_o       = {brc_pc_tmp[31:1], 1'b0};
  assign jalr_pc_o      = {val_ex[31:1], 1'b0};  // pc + offset
  assign jal_pc_o       = {val_ex[31:1], 1'b0};  // pc + offset

  //through pass 
  assign is_load_o      = is_load_i;
  assign mem_en_o       = mem_en_i;
  assign mem_rw_o       = mem_rw_i;
  assign m_sel_o        = m_sel_i;
  assign reg_we_o       = reg_we_i;
  assign csr_we_o       = csr_we_i;
  assign mem_ld_width_o = mem_ld_width_i;
  assign mem_st_width_o = mem_st_width_i;
  assign dst_o          = dst_i;
  assign dst_csr_o      = dst_csr_i;
  assign val_m_o        = val_m_i;
  assign val_csr_o      = val_ex;  // csr에는 계산한 값을 넣는다
  assign pc_o           = pc_i;


endmodule
