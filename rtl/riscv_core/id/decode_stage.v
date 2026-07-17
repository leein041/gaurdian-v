`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/25 23:31:14
// Design Name: 
// Module Name: decode_stage
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
`include "pkg.vh"

module decode_stage (
    input clk_i,
    input rst_ni,

    input                            reg_we_i,
    input                            csr_we_i,
    input      [               31:0] pc_i,
    input      [               31:0] inst_i,
    input      [                4:0] dst_i,
    input      [               31:0] val_wb_i,
    input      [               11:0] dst_csr_i,
    input      [               31:0] val_csr_i,
    input                            ex_reg_we_fw_i,
    input      [                4:0] ex_dst_fw_i,
    input      [               31:0] ex_val_fw_i,
    input                            me_reg_we_fw_i,
    input      [                4:0] me_dst_fw_i,
    input      [               31:0] me_val_fw_i,
    input                            wb_reg_we_fw_i,
    input      [                4:0] wb_dst_fw_i,
    input      [               31:0] wb_val_fw_i,
    input      [               11:0] ex_dst_csr_fw_i,
    input      [               31:0] ex_val_csr_fw_i,
    input      [               11:0] me_dst_csr_fw_i,
    input      [               31:0] me_val_csr_fw_i,
    input      [               11:0] wb_dst_csr_fw_i,
    input      [               31:0] wb_val_csr_fw_i,
    output                           is_brc_o,
    output                           is_jal_o,
    output                           is_jalr_o,
    output                           is_load_o,
    output                           is_ecall_o,
    output                           is_ebreak_o,
    output                           is_mret_o,
    output                           is_wfi_o,
    output                           brc_neg_o,
    output     [                2:0] brc_cond_o,
    output     [                2:0] mem_ld_width_o,
    output     [                2:0] mem_st_width_o,
    output                           mem_en_o,
    output                           mem_rw_o,
    output                           reg_we_o,
    output                           csr_we_o,
    output                           mstatus_mie_o,
    output     [                4:0] src_a_o,
    output     [                4:0] src_b_o,
    output     [                4:0] dst_o,
    output     [               11:0] dst_csr_o,
    output     [`OPERATER_WIDTH-1:0] alu_operater_o,
    output reg [               31:0] val_a_o,
    output reg [               31:0] val_b_o,
    output     [               31:0] val_m_o,
    output     [               31:0] val_imm_o,
    output                           e_sel_o,
    output                           m_sel_o,
    output     [               31:0] mie_o,
    output     [               31:0] mip_o,
    output     [               31:0] pc_o

);

  localparam ADDR_WIDTH = 5;
  localparam DATA_WIDTH = 32;

  wire [           1:0] a_sel;
  wire [           1:0] b_sel;
  wire [ADDR_WIDTH-1:0] src_a;
  wire [ADDR_WIDTH-1:0] src_b;
  wire [          11:0] src_csr;
  wire [          31:0] val_a;
  wire [          31:0] val_b;
  wire [          31:0] val_csr;
  wire [          31:0] imm;
  // forward loop
  wire [          31:0] fwd_val_a;
  wire [          31:0] fwd_val_b;
  wire [          31:0] fwd_val_csr;

  // csr  
  wire                  is_ecall;
  wire                  is_ebreak;
  wire                  is_mret;
  wire                  is_wfi;

  // inst_iruction Decoder
  instruction_decoder id (
      .inst_i        (inst_i),
      .brc_neg_o     (brc_neg_o),
      .is_brc_o      (is_brc_o),
      .is_jal_o      (is_jal_o),
      .is_jalr_o     (is_jalr_o),
      .is_load_o     (is_load_o),
      .is_ecall_o    (is_ecall),
      .is_ebreak_o   (is_ebreak),
      .is_mret_o     (is_mret),
      .is_wfi_o      (is_wfi),
      .brc_cond_o    (brc_cond_o),
      .mem_ld_width_o(mem_ld_width_o),
      .mem_st_width_o(mem_st_width_o),
      .mem_en_o      (mem_en_o),
      .mem_rw_o      (mem_rw_o),
      .reg_we_o      (reg_we_o),
      .csr_we_o      (csr_we_o),
      .alu_operater_o(alu_operater_o),
      .a_sel_o       (a_sel),
      .b_sel_o       (b_sel),
      .e_sel_o       (e_sel_o),
      .m_sel_o       (m_sel_o),
      .src_a_o       (src_a),
      .src_b_o       (src_b),
      .dst_o         (dst_o),
      .src_csr_o     (src_csr),
      .dst_csr_o     (dst_csr_o),
      .imm_o         (imm)
  );

  //Register File
  reg_file rf (
      .clk_i   (clk_i),
      .rst_ni  (rst_ni),
      .reg_we_i(reg_we_i),
      .src_a_i (src_a),
      .src_b_i (src_b),
      .dst_i   (dst_i),
      .val_a_o (val_a),
      .val_b_o (val_b),
      .val_d_i (val_wb_i)
  );


  // CSR File
  csr_file csrf (
      .clk_i        (clk_i),
      .rst_ni       (rst_ni),
      .src_i        (src_csr),
      .dst_i        (dst_csr_i),
      .val_d_i      (val_csr_i),
      .pc_i         (pc_i),
      .csr_we_i     (csr_we_i),
      .is_ecall_i   (is_ecall),
      .is_ebreak_i  (is_ebreak),
      .is_mret_i    (is_mret),
      .val_o        (val_csr),
      .mstatus_mie_o(mstatus_mie_o),
      .mie_o        (mie_o),
      .mip_o        (mip_o)
  );

  // Select A  
  always @(*) begin
    case (a_sel)
      2'b00:   val_a_o = fwd_val_a;  // reg a
      2'b01:   val_a_o = pc_i;  // PC
      2'b10:   val_a_o = 32'b0;  // Zero  
      default: val_a_o = 32'b0;
    endcase
  end

  // Select B   
  always @(*) begin
    case (b_sel)
      2'b00:   val_b_o = fwd_val_b;  // reg b
      2'b01:   val_b_o = imm;  // imm
      2'b10:   val_b_o = fwd_val_csr;  // csr
      default: val_b_o = 32'b0;
    endcase
  end

  //forward loop
  assign fwd_val_a = (src_a == ex_dst_fw_i && ex_reg_we_fw_i  && src_a != 5'b0) ? ex_val_fw_i :
                     (src_a == me_dst_fw_i && me_reg_we_fw_i  && src_a != 5'b0) ? me_val_fw_i : 
                     (src_a == wb_dst_fw_i && &wb_reg_we_fw_i && src_a != 5'b0) ? wb_val_fw_i : 
                                                               val_a;
  assign fwd_val_b = (src_b == ex_dst_fw_i && ex_reg_we_fw_i  && src_b != 5'b0) ? ex_val_fw_i :
                     (src_b == me_dst_fw_i && me_reg_we_fw_i  && src_b != 5'b0) ? me_val_fw_i : 
                     (src_b == wb_dst_fw_i && &wb_reg_we_fw_i && src_b != 5'b0) ? wb_val_fw_i : 
                                                               val_b;
  assign fwd_val_csr = (src_csr == ex_dst_csr_fw_i) ? ex_val_csr_fw_i :
                       (src_csr == me_dst_csr_fw_i) ? me_val_csr_fw_i : 
                       (src_csr == wb_dst_csr_fw_i) ? wb_val_csr_fw_i : 
                                                    val_csr;


  assign val_m_o = fwd_val_b;
  assign val_imm_o = imm;
  assign pc_o = pc_i;
  assign src_a_o = src_a;
  assign src_b_o = src_b;

  assign is_ecall_o = is_ecall;
  assign is_ebreak_o = is_ebreak;
  assign is_mret_o = is_mret;
  assign is_wfi_o = is_wfi;
endmodule
