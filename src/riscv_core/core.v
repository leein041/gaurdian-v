`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/26 22:55:06
// Design Name: 
// Module Name: core
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

module core #(
    parameter MACHINE_CODE   = "",
    parameter MEM_INIT_VALUE = ""
) (
    input clk_i,
    input rst_ni,

    output [31:0] wb_pc_o,

    output [31:0] tohost_o,
    output        tohost_wen_o
);
  localparam START_INDEX = 32'h8000_0000;
  // stage register  
  reg  [               31:0] if_pc_q;
  wire [               31:0] if_inst_d;
  wire [               31:0] if_pc_d;
  wire [               31:0] if_nxt_pc_d;

  reg  [               31:0] id_pc_q;
  reg  [               31:0] id_inst_q;
  wire                       id_is_brc_d;
  wire                       id_is_jal_d;
  wire                       id_is_jalr_d;
  wire                       id_is_load_d;
  wire                       id_is_ecall_d;
  wire                       id_is_ebreak_d;
  wire                       id_is_mret_d;
  wire                       id_is_wfi_d;
  wire                       id_brc_neg_d;
  wire [                2:0] id_brc_cond_d;
  wire [                2:0] id_mem_ld_width_d;
  wire [                2:0] id_mem_st_width_d;
  wire                       id_mem_en_d;
  wire                       id_mem_rw_d;
  wire                       id_reg_we_d;
  wire                       id_csr_we_d;
  wire                       id_mstatus_mie_d;
  wire [                4:0] id_src_a_d;
  wire [                4:0] id_src_b_d;
  wire [                4:0] id_dst_d;
  wire [               11:0] id_dst_csr_d;
  wire [`OPERATER_WIDTH-1:0] id_alu_operater_d;
  wire [               31:0] id_val_a_d;
  wire [               31:0] id_val_b_d;
  wire [               31:0] id_val_m_d;
  wire [               31:0] id_val_imm_d;
  wire                       id_e_sel_d;
  wire                       id_m_sel_d;
  wire [               31:0] id_mie_d;
  wire [               31:0] id_mip_d;
  wire [               31:0] id_pc_d;

  reg                        ex_is_load_q;
  reg                        ex_is_brc_q;
  reg                        ex_is_jal_q;
  reg                        ex_is_jalr_q;
  reg                        ex_brc_neg_q;
  reg  [                2:0] ex_brc_cond_q;
  reg                        ex_e_sel_q;
  reg                        ex_m_sel_q;
  reg                        ex_mem_en_q;
  reg                        ex_mem_rw_q;
  reg                        ex_reg_we_q;
  reg                        ex_csr_we_q;
  reg  [                2:0] ex_mem_ld_width_q;
  reg  [                2:0] ex_mem_st_width_q;
  reg  [                4:0] ex_dst_q;
  reg  [               11:0] ex_dst_csr_q;
  reg  [`OPERATER_WIDTH-1:0] ex_alu_operater_q;
  reg  [               31:0] ex_val_a_q;  // 00-reg / 01-PC / 10-zero
  reg  [               31:0] ex_val_b_q;  //   
  reg  [               31:0] ex_val_imm_q;
  reg  [               31:0] ex_pc_q;
  reg  [               31:0] ex_val_m_q;
  wire [               31:0] ex_val_ex_d;
  wire [               31:0] ex_val_csr_d;
  wire                       ex_brc_taken_d;
  wire [               31:0] ex_brc_pc_d;
  wire [               31:0] ex_jal_pc_d;
  wire [               31:0] ex_jalr_pc_d;
  wire                       ex_is_load_d;
  wire                       ex_m_sel_d;
  wire                       ex_mem_en_d;
  wire                       ex_mem_rw_d;
  wire                       ex_reg_we_d;
  wire                       ex_csr_we_d;
  wire [                2:0] ex_mem_ld_width_d;
  wire [                2:0] ex_mem_st_width_d;
  wire [                4:0] ex_dst_d;
  wire [               11:0] ex_dst_csr_d;
  wire [               31:0] ex_val_m_d;
  wire [               31:0] ex_pc_d;

  reg                        m_is_load_q;
  reg                        m_mem_en_q;
  reg                        m_mem_rw_q;
  reg                        m_reg_we_q;
  reg                        m_csr_we_q;
  reg                        m_m_sel_q;
  reg  [                2:0] m_mem_ld_width_q;
  reg  [                2:0] m_mem_st_width_q;
  reg  [                4:0] m_dst_q;
  reg  [               11:0] m_dst_csr_q;
  reg  [               31:0] m_val_m_q;
  reg  [               31:0] m_val_csr_q;
  reg  [               31:0] m_val_ex_q;
  reg  [               31:0] m_pc_q;
  wire                       m_reg_we_d;
  wire                       m_csr_we_d;
  wire [                4:0] m_dst_d;
  wire [               11:0] m_dst_csr_d;
  wire [               31:0] m_val_d;
  wire [               31:0] m_val_csr_d;
  wire                       m_mem_ready_d;
  wire [               31:0] m_pc_d;
  wire [               31:0] m_tohost_d;
  wire                       m_tohost_wen_d;

  reg                        wb_reg_we_q;
  reg                        wb_csr_we_q;
  reg  [                4:0] wb_dst_q;
  reg  [               31:0] wb_val_q;
  reg  [               11:0] wb_dst_csr_q;
  reg  [               31:0] wb_val_csr_q;
  reg  [               31:0] wb_pc_q;
  wire                       wb_reg_we_d;
  wire                       wb_csr_we_d;
  wire [                4:0] wb_dst_d;
  wire [               31:0] wb_val_d;
  wire [               11:0] wb_dst_csr_d;
  wire [               31:0] wb_val_csr_d;
  wire [               31:0] wb_pc_d;

  wire                       if_stall;
  wire                       id_stall;
  wire                       ex_stall;
  wire                       m_stall;
  wire                       wb_stall;

  wire                       id_bubble;
  wire                       ex_bubble;
  wire                       me_bubble;
  wire                       wb_bubble;

  wire                       ex_reg_en_fw = ex_reg_we_d;
  wire [                4:0] ex_dst_fw = ex_dst_d;
  wire [               31:0] ex_val_fw = ex_val_ex_d;
  wire                       me_reg_en_fw = m_reg_we_d;
  wire [                4:0] me_dst_fw = m_dst_d;
  wire [               31:0] me_val_fw = m_val_d;
  wire                       wb_reg_en_fw = wb_reg_we_d;
  wire [                4:0] wb_dst_fw = wb_dst_d;
  wire [               31:0] wb_val_fw = wb_val_d;

  wire [               11:0] ex_csr_dst_fw = ex_dst_csr_d;
  wire [               31:0] ex_csr_val_fw = ex_val_csr_d;
  wire [               11:0] me_csr_dst_fw = m_dst_csr_d;
  wire [               31:0] me_csr_val_fw = m_val_csr_d;
  wire [               11:0] wb_csr_dst_fw = wb_dst_csr_d;
  wire [               31:0] wb_csr_val_fw = wb_val_csr_d;

  //      _____    _       _     
  //     |  ___|__| |_ ___| |__  
  //     | |_ / _ \ __/ __| '_ \ 
  //     |  _|  __/ || (__| | | |
  //     |_|  \___|\__\___|_| |_|
  // 

  fetch_stage #(
      .MACHINE_CODE(MACHINE_CODE),
      .START_INDEX (START_INDEX)
  ) fs (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      .is_ecall_i(id_is_ecall_d),
      .is_mret_i (id_is_mret_d),
      .val_csr_i (id_val_b_d),      // b select is csr val
      .is_brc_i  (ex_is_brc_q),
      .is_jal_i  (ex_is_jal_q),
      .is_jalr_i (ex_is_jalr_q),
      .brc_taken (ex_brc_taken_d),
      .brc_pc_i  (ex_brc_pc_d),
      .jal_pc_i  (ex_jal_pc_d),
      .jalr_pc_i (ex_jalr_pc_d),
      .pc_i      (if_pc_q),
      .inst_o    (if_inst_d),
      .pc_o      (if_pc_d),
      .nxt_pc_o  (if_nxt_pc_d)
  );

  always @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      if_pc_q <= START_INDEX;
    end else begin
      if (if_stall) begin
        if_pc_q <= if_pc_q;
      end else begin
        if_pc_q <= if_nxt_pc_d;
      end
    end
  end

  //      ____                         _      
  //     |  _ \  ___  ___ ___ ___   __| | ___ 
  //     | | | |/ _ \/ __/ __/ _ \ / _` |/ _ \ 
  //     | |_| |  __/ (_| (_| (_) | (_| |  __/
  //     |____/ \___|\___\___\___/ \__,_|\___|
  //                
  decode_stage ds (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      .reg_we_i       (wb_reg_we_d),
      .csr_we_i       (wb_csr_we_d),
      .pc_i           (id_pc_q),
      .inst_i         (id_inst_q),
      .dst_i          (wb_dst_d),
      .val_wb_i       (wb_val_d),
      .dst_csr_i      (wb_dst_csr_d),
      .val_csr_i      (wb_val_csr_d),
      .ex_dst_fw_i    (ex_dst_fw),
      .ex_val_fw_i    (ex_val_fw),
      .me_dst_fw_i    (me_dst_fw),
      .me_val_fw_i    (me_val_fw),
      .wb_dst_fw_i    (wb_dst_fw),
      .wb_val_fw_i    (wb_val_fw),
      .ex_reg_we_fw_i (ex_reg_en_fw),
      .ex_dst_csr_fw_i(ex_csr_dst_fw),
      .ex_val_csr_fw_i(ex_csr_val_fw),
      .me_reg_we_fw_i (me_reg_en_fw),
      .me_dst_csr_fw_i(me_csr_dst_fw),
      .me_val_csr_fw_i(me_csr_val_fw),
      .wb_reg_we_fw_i (wb_reg_en_fw),
      .wb_dst_csr_fw_i(wb_csr_dst_fw),
      .wb_val_csr_fw_i(wb_csr_val_fw),
      .is_brc_o       (id_is_brc_d),
      .is_jal_o       (id_is_jal_d),
      .is_jalr_o      (id_is_jalr_d),
      .is_load_o      (id_is_load_d),
      .is_ecall_o     (id_is_ecall_d),
      .is_ebreak_o    (id_is_ebreak_d),
      .is_mret_o      (id_is_mret_d),
      .is_wfi_o       (id_is_wfi_d),
      .brc_neg_o      (id_brc_neg_d),
      .brc_cond_o     (id_brc_cond_d),
      .mem_ld_width_o (id_mem_ld_width_d),
      .mem_st_width_o (id_mem_st_width_d),
      .mem_en_o       (id_mem_en_d),
      .mem_rw_o       (id_mem_rw_d),
      .reg_we_o       (id_reg_we_d),
      .csr_we_o       (id_csr_we_d),
      .mstatus_mie_o  (id_mstatus_mie_d),
      .src_a_o        (id_src_a_d),
      .src_b_o        (id_src_b_d),
      .dst_o          (id_dst_d),
      .dst_csr_o      (id_dst_csr_d),
      .alu_operater_o (id_alu_operater_d),
      .val_a_o        (id_val_a_d),
      .val_b_o        (id_val_b_d),
      .val_m_o        (id_val_m_d),
      .val_imm_o      (id_val_imm_d),
      .e_sel_o        (id_e_sel_d),
      .m_sel_o        (id_m_sel_d),
      .pc_o           (id_pc_d)
  );

  always @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      id_pc_q   <= 32'b0;
      id_inst_q <= 32'b0;
    end else begin
      if (id_stall) begin
        id_pc_q   <= id_pc_q;
        id_inst_q <= id_inst_q;
      end else if (id_bubble) begin
        id_pc_q   <= 32'b0;
        id_inst_q <= 32'b0;
      end else begin
        id_pc_q   <= if_pc_d;
        id_inst_q <= if_inst_d;
      end
    end
  end

  //      _____                _       
  //     | ____|_  _____ _   _| |_ ___ 
  //     |  _| \ \/ / __| | | | __/ _ \ 
  //     | |___ >  < (__| |_| | ||  __/ 
  //     |_____/_/\_\___|\__,_|\__\___|  
  // 

  ex_stage ex (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      .is_load_i     (ex_is_load_q),
      .is_brc_i      (ex_is_brc_q),
      .is_jal_i      (ex_is_jal_q),
      .is_jalr_i     (ex_is_jalr_q),
      .brc_neg_i     (ex_brc_neg_q),
      .brc_cond_i    (ex_brc_cond_q),
      .e_sel_i       (ex_e_sel_q),
      .m_sel_i       (ex_m_sel_q),
      .mem_en_i      (ex_mem_en_q),
      .mem_rw_i      (ex_mem_rw_q),
      .reg_we_i      (ex_reg_we_q),
      .csr_we_i      (ex_csr_we_q),
      .mem_ld_width_i(ex_mem_ld_width_q),
      .mem_st_width_i(ex_mem_st_width_q),
      .dst_i         (ex_dst_q),
      .dst_csr_i     (ex_dst_csr_q),
      .alu_operater_i(ex_alu_operater_q),
      .val_a_i       (ex_val_a_q),
      .val_b_i       (ex_val_b_q),
      .val_imm_i     (ex_val_imm_q),
      .pc_i          (ex_pc_q),
      .val_m_i       (ex_val_m_q),
      .val_ex_o      (ex_val_ex_d),
      .val_csr_o     (ex_val_csr_d),
      .brc_taken_o   (ex_brc_taken_d),
      .brc_pc_o      (ex_brc_pc_d),
      .jal_pc_o      (ex_jal_pc_d),
      .jalr_pc_o     (ex_jalr_pc_d),
      .is_load_o     (ex_is_load_d),
      .m_sel_o       (ex_m_sel_d),
      .mem_en_o      (ex_mem_en_d),
      .mem_rw_o      (ex_mem_rw_d),
      .reg_we_o      (ex_reg_we_d),
      .csr_we_o      (ex_csr_we_d),
      .mem_ld_width_o(ex_mem_ld_width_d),
      .mem_st_width_o(ex_mem_st_width_d),
      .dst_o         (ex_dst_d),
      .dst_csr_o     (ex_dst_csr_d),
      .val_m_o       (ex_val_m_d),
      .pc_o          (ex_pc_d)
  );
  always @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      ex_is_load_q      <= 1'b0;
      ex_is_brc_q       <= 1'b0;
      ex_is_jal_q       <= 1'b0;
      ex_is_jalr_q      <= 1'b0;
      ex_brc_neg_q      <= 1'b0;
      ex_brc_cond_q     <= 3'b0;
      ex_e_sel_q        <= 1'b0;
      ex_m_sel_q        <= 1'b0;
      ex_mem_en_q       <= 1'b0;
      ex_mem_rw_q       <= 1'b0;
      ex_reg_we_q       <= 1'b0;
      ex_csr_we_q       <= 1'b0;
      ex_mem_ld_width_q <= 3'b0;
      ex_mem_st_width_q <= 3'b0;
      ex_dst_q          <= 5'b0;
      ex_dst_csr_q      <= 12'b0;
      ex_alu_operater_q <= `OPERATER_WIDTH'b0;
      ex_val_a_q        <= 32'b0;
      ex_val_b_q        <= 32'b0;
      ex_val_imm_q      <= 32'b0;
      ex_pc_q           <= 32'b0;
      ex_val_m_q        <= 32'b0;
    end else begin
      if (ex_stall) begin
        ex_is_load_q      <= ex_is_load_q;
        ex_is_brc_q       <= ex_is_brc_q;
        ex_is_jal_q       <= ex_is_jal_q;
        ex_is_jalr_q      <= ex_is_jalr_q;
        ex_brc_neg_q      <= ex_brc_neg_q;
        ex_brc_cond_q     <= ex_brc_cond_q;
        ex_e_sel_q        <= ex_e_sel_q;
        ex_m_sel_q        <= ex_m_sel_q;
        ex_mem_en_q       <= ex_mem_en_q;
        ex_mem_rw_q       <= ex_mem_rw_q;
        ex_reg_we_q       <= ex_reg_we_q;
        ex_csr_we_q       <= ex_csr_we_q;
        ex_mem_ld_width_q <= ex_mem_ld_width_q;
        ex_mem_st_width_q <= ex_mem_st_width_q;
        ex_dst_q          <= ex_dst_q;
        ex_dst_csr_q      <= ex_dst_csr_q;
        ex_alu_operater_q <= ex_alu_operater_q;
        ex_val_a_q        <= ex_val_a_q;
        ex_val_b_q        <= ex_val_b_q;
        ex_val_imm_q      <= ex_val_imm_q;
        ex_pc_q           <= ex_pc_q;
        ex_val_m_q        <= ex_val_m_q;
      end else if (ex_bubble) begin
        ex_is_load_q      <= 1'b0;
        ex_is_brc_q       <= 1'b0;
        ex_is_jal_q       <= 1'b0;
        ex_is_jalr_q      <= 1'b0;
        ex_brc_neg_q      <= 1'b0;
        ex_brc_cond_q     <= 3'b0;
        ex_e_sel_q        <= 1'b0;
        ex_m_sel_q        <= 1'b0;
        ex_mem_en_q       <= 1'b0;
        ex_mem_rw_q       <= 1'b0;
        ex_reg_we_q       <= 1'b0;
        ex_csr_we_q       <= 1'b0;
        ex_mem_ld_width_q <= 3'b0;
        ex_mem_st_width_q <= 3'b0;
        ex_dst_q          <= 5'b0;
        ex_dst_csr_q      <= 12'b0;
        ex_alu_operater_q <= `OPERATER_WIDTH'b0;
        ex_val_a_q        <= 32'b0;
        ex_val_b_q        <= 32'b0;
        ex_val_imm_q      <= 32'b0;
        ex_pc_q           <= 32'b0;
        ex_val_m_q        <= 32'b0;
      end else begin
        ex_is_load_q      <= id_is_load_d;
        ex_is_brc_q       <= id_is_brc_d;
        ex_is_jal_q       <= id_is_jal_d;
        ex_is_jalr_q      <= id_is_jalr_d;
        ex_brc_neg_q      <= id_brc_neg_d;
        ex_brc_cond_q     <= id_brc_cond_d;
        ex_e_sel_q        <= id_e_sel_d;
        ex_m_sel_q        <= id_m_sel_d;
        ex_mem_en_q       <= id_mem_en_d;
        ex_mem_rw_q       <= id_mem_rw_d;
        ex_reg_we_q       <= id_reg_we_d;
        ex_csr_we_q       <= id_csr_we_d;
        ex_mem_ld_width_q <= id_mem_ld_width_d;
        ex_mem_st_width_q <= id_mem_st_width_d;
        ex_dst_q          <= id_dst_d;
        ex_dst_csr_q      <= id_dst_csr_d;
        ex_alu_operater_q <= id_alu_operater_d;
        ex_val_a_q        <= id_val_a_d;
        ex_val_b_q        <= id_val_b_d;
        ex_val_imm_q      <= id_val_imm_d;
        ex_pc_q           <= id_pc_d;
        ex_val_m_q        <= id_val_m_d;
      end
    end
  end
  //      __  __                                 
  //     |  \/  | ___ _ __ ___   ___  _ __ _   _ 
  //     | |\/| |/ _ \ '_ ` _ \ / _ \| '__| | | |
  //     | |  | |  __/ | | | | | (_) | |  | |_| |
  //     |_|  |_|\___|_| |_| |_|\___/|_|   \__, |
  //                                       |___/ 
  memory_stage #(
      .MEM_INIT_VALUE(MEM_INIT_VALUE),
      .START_INDEX   (START_INDEX)
  ) ms (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      .is_load_i     (m_is_load_q),
      .mem_en_i      (m_mem_en_q),
      .mem_rw_i      (m_mem_rw_q),
      .reg_we_i      (m_reg_we_q),
      .csr_we_i      (m_csr_we_q),
      .m_sel_i       (m_m_sel_q),
      .mem_ld_width_i(m_mem_ld_width_q),
      .mem_st_width_i(m_mem_st_width_q),
      .dst_i         (m_dst_q),
      .dst_csr_i     (m_dst_csr_q),
      .val_m_i       (m_val_m_q),
      .val_csr_i     (m_val_csr_q),
      .val_ex_i      (m_val_ex_q),
      .pc_i          (m_pc_q),
      .reg_we_o      (m_reg_we_d),
      .csr_we_o      (m_csr_we_d),
      .dst_o         (m_dst_d),
      .dst_csr_o     (m_dst_csr_d),
      .val_o         (m_val_d),
      .val_csr_o     (m_val_csr_d),
      .mem_ready_o   (m_mem_ready_d),
      .pc_o          (m_pc_d),
      .tohost_o      (m_tohost_d),
      .tohost_wen_o  (m_tohost_wen_d)
  );
  always @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      m_is_load_q      <= 1'b0;
      m_mem_en_q       <= 1'b0;
      m_mem_rw_q       <= 1'b0;
      m_reg_we_q       <= 1'b0;
      m_csr_we_q       <= 1'b0;
      m_m_sel_q        <= 1'b0;
      m_mem_ld_width_q <= 3'b0;
      m_mem_st_width_q <= 3'b0;
      m_dst_q          <= 5'b0;
      m_dst_csr_q      <= 12'b0;
      m_val_m_q        <= 32'b0;
      m_val_csr_q      <= 32'b0;
      m_val_ex_q       <= 32'b0;
      m_pc_q           <= 32'b0;
    end else begin
      if (m_stall) begin
        m_is_load_q      <= m_is_load_q;
        m_mem_en_q       <= m_mem_en_q;
        m_mem_rw_q       <= m_mem_rw_q;
        m_reg_we_q       <= m_reg_we_q;
        m_csr_we_q       <= m_csr_we_q;
        m_m_sel_q        <= m_m_sel_q;
        m_mem_ld_width_q <= m_mem_ld_width_q;
        m_mem_st_width_q <= m_mem_st_width_q;
        m_dst_q          <= m_dst_q;
        m_dst_csr_q      <= m_dst_csr_q;
        m_val_m_q        <= m_val_m_q;
        m_val_csr_q      <= m_val_csr_q;
        m_val_ex_q       <= m_val_ex_q;
        m_pc_q           <= m_pc_q;
      end else if (me_bubble) begin
        m_is_load_q      <= 1'b0;
        m_mem_en_q       <= 1'b0;
        m_mem_rw_q       <= 1'b0;
        m_reg_we_q       <= 1'b0;
        m_csr_we_q       <= 1'b0;
        m_m_sel_q        <= 1'b0;
        m_mem_ld_width_q <= 3'b0;
        m_mem_st_width_q <= 3'b0;
        m_dst_q          <= 5'b0;
        m_dst_csr_q      <= 12'b0;
        m_val_m_q        <= 32'b0;
        m_val_csr_q      <= 32'b0;
        m_val_ex_q       <= 32'b0;
        m_pc_q           <= 32'b0;
      end else begin
        m_is_load_q      <= ex_is_load_d;
        m_mem_en_q       <= ex_mem_en_d;
        m_mem_rw_q       <= ex_mem_rw_d;
        m_reg_we_q       <= ex_reg_we_d;
        m_csr_we_q       <= ex_csr_we_d;
        m_m_sel_q        <= ex_m_sel_d;
        m_mem_ld_width_q <= ex_mem_ld_width_d;
        m_mem_st_width_q <= ex_mem_st_width_d;
        m_dst_q          <= ex_dst_d;
        m_dst_csr_q      <= ex_dst_csr_d;
        m_val_m_q        <= ex_val_m_d;
        m_val_csr_q      <= ex_val_csr_d;
        m_val_ex_q       <= ex_val_ex_d;
        m_pc_q           <= ex_pc_d;
      end
    end
  end

  //     __        __    _ _         ____             _    
  //     \ \      / / __(_) |_ ___  | __ )  __ _  ___| | __
  //      \ \ /\ / / '__| | __/ _ \ |  _ \ / _` |/ __| |/ / 
  //       \ V  V /| |  | | ||  __/ | |_) | (_| | (__|   <  
  //        \_/\_/ |_|  |_|\__\___| |____/ \__,_|\___|_|\_\ 
  //                                          
  wb_stage ws (
      .reg_we_i (wb_reg_we_q),
      .csr_we_i (wb_csr_we_q),
      .dst_i    (wb_dst_q),
      .val_i    (wb_val_q),
      .dst_csr_i(wb_dst_csr_q),
      .val_csr_i(wb_val_csr_q),
      .pc_i     (wb_pc_q),
      .reg_we_o (wb_reg_we_d),
      .csr_we_o (wb_csr_we_d),
      .dst_o    (wb_dst_d),
      .val_o    (wb_val_d),
      .dst_csr_o(wb_dst_csr_d),
      .val_csr_o(wb_val_csr_d),
      .pc_o     (wb_pc_d)
  );

  always @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      wb_reg_we_q  <= 1'b0;
      wb_csr_we_q  <= 1'b0;
      wb_dst_q     <= 12'b0;
      wb_val_q     <= 32'b0;
      wb_dst_csr_q <= 12'b0;
      wb_val_csr_q <= 32'b0;
      wb_pc_q      <= 32'b0;
    end else begin
      if (wb_stall) begin
        wb_reg_we_q  <= wb_reg_we_q;
        wb_csr_we_q  <= wb_csr_we_q;
        wb_dst_q     <= wb_dst_q;
        wb_val_q     <= wb_val_q;
        wb_dst_csr_q <= wb_dst_csr_q;
        wb_val_csr_q <= wb_val_csr_q;
        wb_pc_q      <= wb_pc_q;
      end else if (wb_bubble) begin
        wb_reg_we_q  <= 1'b0;
        wb_csr_we_q  <= 1'b0;
        wb_dst_q     <= 12'b0;
        wb_val_q     <= 32'b0;
        wb_dst_csr_q <= 12'b0;
        wb_val_csr_q <= 32'b0;
        wb_pc_q      <= 32'b0;
      end else begin
        wb_reg_we_q  <= m_reg_we_d;
        wb_csr_we_q  <= m_csr_we_d;
        wb_dst_q     <= m_dst_d;
        wb_val_q     <= m_val_d;
        wb_dst_csr_q <= m_dst_csr_d;
        wb_val_csr_q <= m_val_csr_d;
        wb_pc_q      <= m_pc_d;
      end
    end
  end

  //      _   _                        _ 
  //     | | | | __ _ ______ _ _ __ __| |
  //     | |_| |/ _` |_  / _` | '__/ _` |
  //     |  _  | (_| |/ / (_| | | | (_| |
  //     |_| |_|\__,_/___\__,_|_|  \__,_|
  //                                     

  // Load-Use_Hazard by load
  wire load_hazard = (ex_is_load_q)  // 1. load 인가? 
  && (ex_dst_q != 5'b0)  // 레지스터 0번인가?
  && ((id_src_a_d == ex_dst_q) || (id_src_b_d == ex_dst_q));  // load dst 레지스터를 id 단계에서 쓸 것인가?

  // Control Hazard by jal / brc
  wire control_hazard = ex_is_jal_q | ex_is_jalr_q | (ex_is_brc_q & ex_brc_taken_d);

  // System Hazard
  wire system_hazard = id_is_mret_d | id_is_ecall_d;
  wire interrupt_fire = id_mstatus_mie_d & (id_mie_d & id_mip_d);  // 인터럽트 발생 조건
  wire system_halt = id_is_wfi_d & ~interrupt_fire;  // 인터럽트가 없을 때만 멈춤 

  // Memory Busy Freeze
  wire mem_busy = m_mem_en_q && ~m_mem_ready_d;

  assign id_bubble    = system_hazard | control_hazard;
  assign ex_bubble    = load_hazard | control_hazard;
  assign me_bubble    = 1'b0;
  assign wb_bubble    = 1'b0;

  assign if_stall     = system_halt | mem_busy | load_hazard;
  assign id_stall     = system_halt | mem_busy | load_hazard;
  assign ex_stall     = system_halt | mem_busy;
  assign m_stall      = system_halt | mem_busy;
  assign wb_stall     = system_halt | mem_busy;




  // Core out ( Debug )
  assign tohost_o     = m_tohost_d;
  assign tohost_wen_o = m_tohost_wen_d;
  assign wb_pc_o      = wb_pc_d;
endmodule
